import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/dtn/data/network_recovery_manager.dart';
import 'package:onebit/features/dtn/delivery/delivery_scheduler.dart';
import 'package:onebit/features/dtn/delivery/dtn_config.dart';
import 'package:onebit/features/dtn/delivery/dtn_gateway.dart';
import 'package:onebit/features/dtn/delivery/store_forward_engine.dart';
import 'package:onebit/features/dtn/domain/dtn_connectivity.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';
import 'package:onebit/features/dtn/domain/dtn_failure.dart';
import 'package:onebit/features/dtn/domain/dtn_priority.dart';
import 'package:onebit/features/dtn/domain/dtn_queue_snapshot.dart';

/// A gateway whose transmit outcomes can be scripted per call.
final class ScriptedGateway implements DtnGateway {
  ScriptedGateway({this.reachable = true});

  bool reachable;
  final List<DtnGatewayOutcome> _outcomes = [];
  final List<DtnPacket> transmitted = [];

  void then(DtnGatewayOutcome outcome) => _outcomes.add(outcome);

  @override
  DtnConnectivitySnapshot connectivity() =>
      DtnConnectivitySnapshot(reachable: reachable);

  @override
  DtnGatewayOutcome transmit(DtnPacket packet) {
    transmitted.add(packet);
    return _outcomes.isEmpty
        ? DtnGatewayOutcome.acceptedNoAck
        : _outcomes.removeAt(0);
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void onLayerEvent(String event) {}
}

/// A controllable wall clock for deterministic engine tests.
final class MutableClock {
  DateTime _now = DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);

  DateTime get now => _now;

  void advance(Duration by) => _now = _now.add(by);
}

DtnPacket envelope(
  String id, {
  String destination = 'node-b',
  DtnPriority priority = DtnPriority.normal,
  int ttlSeconds = 3600,
  DateTime? createdAt,
  DateTime? expiresAt,
}) {
  final at =
      createdAt ?? DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);
  return DtnPacket(
    packetId: id,
    source: 'node-a',
    destination: destination,
    payload: 'hello'.codeUnits,
    priority: priority,
    direction: DtnDirection.outbound,
    ttlSeconds: ttlSeconds,
    createdAt: at,
    expiresAt: expiresAt ?? at.add(Duration(seconds: ttlSeconds)),
  );
}

void main() {
  late MutableClock clock;
  late ScriptedGateway gateway;
  late DtnEngineConfig config;
  late StoreForwardEngine engine;
  late MemoryDtnPersistence persistence;

  StoreForwardEngine buildEngine() {
    return StoreForwardEngine(
      config: config,
      persistence: persistence,
      now: () => clock.now,
      gateway: gateway,
    );
  }

  setUp(() {
    clock = MutableClock();
    gateway = ScriptedGateway();
    config = const DtnEngineConfig(
      batchLimit: 8,
      retryPolicy: DtnRetryPolicy(
        baseDelay: Duration(seconds: 10),
        factor: 2,
        maxDelay: Duration(minutes: 1),
        jitterRatio: 0,
        limit: 3,
      ),
    );
    persistence = MemoryDtnPersistence();
    engine = buildEngine();
  });

  group('store', () {
    test('stores an envelope as queued and publishes snapshots', () async {
      final snapshots = <DtnQueueSnapshot>[];
      engine.queueSnapshots.listen(snapshots.add);
      final stored = engine.store(envelope('p1'));
      expect(stored.state, DtnPacketState.queued);
      expect(engine.snapshot().outgoing, 1);
      expect(engine.snapshot().live, 1);
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.last.outgoing, 1);
    });

    test('is idempotent for the same packet id', () {
      engine.store(envelope('p1'));
      final second = engine.store(envelope('p1'));
      expect(second.packetId, 'p1');
      expect(engine.snapshot().live, 1);
    });

    test('rejects a zero ttl and oversized payloads', () {
      expect(
        () => engine.store(envelope('p1', ttlSeconds: 0)),
        throwsA(isA<DtnFailure>()),
      );
      expect(
        () => engine.store(
          DtnPacket(
            packetId: 'p2',
            source: 'a',
            destination: 'b',
            payload: List<int>.filled((1 << 20) + 1, 1),
            priority: DtnPriority.normal,
            direction: DtnDirection.outbound,
            ttlSeconds: 60,
            createdAt: clock.now,
            expiresAt: clock.now.add(const Duration(seconds: 60)),
          ),
        ),
        throwsA(isA<DtnFailure>()),
      );
    });

    test('fails with queueOverflow at the live cap', () {
      const tiny = DtnEngineConfig(maxLiveEnvelopes: 2);
      final capped = StoreForwardEngine(
        config: tiny,
        persistence: persistence,
        now: () => clock.now,
        gateway: gateway,
      );
      capped.store(envelope('a'));
      capped.store(envelope('b'));
      expect(
        () => capped.store(envelope('c')),
        throwsA(
          isA<DtnFailure>().having(
            (f) => f.kind,
            'kind',
            DtnFailureKind.queueOverflow,
          ),
        ),
      );
    });
  });

  group('delivery', () {
    test('reachable gateway delivers fire-and-forget envelopes', () {
      gateway.reachable = true;
      engine.store(envelope('p1'));
      engine.store(envelope('p2'));
      final scheduler = DeliveryScheduler(
        engine: engine,
        gateway: gateway,
        now: () => clock.now,
      );
      scheduler.start();
      expect(gateway.transmitted, hasLength(2));
      expect(engine.snapshot().live, 0);
      expect(engine.statistics.delivered, 2);
      scheduler.stop();
    });

    test('unreachable gateway parks envelopes (critical survives)', () {
      gateway.reachable = false;
      engine.store(envelope('normal'));
      engine.store(envelope('critical', priority: DtnPriority.critical));
      final scheduler = DeliveryScheduler(
        engine: engine,
        gateway: gateway,
        now: () => clock.now,
      );
      scheduler.start();
      expect(gateway.transmitted, isEmpty);
      expect(engine.snapshot().deferred, 1);
      expect(engine.snapshot().outgoing, 1);
      scheduler.stop();
    });

    test('restoring reachability unpark all parked envelopes', () {
      gateway.reachable = false;
      engine.store(envelope('p1'));
      engine.parkAll();
      expect(engine.snapshot().deferred, 1);

      gateway.reachable = true;
      engine.unparkAll();
      expect(engine.snapshot().outgoing, 1);
    });

    test('delivery is ordered by priority then enqueue time', () {
      gateway.reachable = true;
      engine.store(envelope('low-first', priority: DtnPriority.low));
      engine.store(envelope('critical-second', priority: DtnPriority.critical));
      final scheduler = DeliveryScheduler(
        engine: engine,
        gateway: gateway,
        now: () => clock.now,
      );
      scheduler.start();
      expect(gateway.transmitted.map((p) => p.packetId).toList(), [
        'critical-second',
        'low-first',
      ]);
      scheduler.stop();
    });
  });

  group('retry', () {
    test('failed transmit moves the envelope into retrying with backoff', () {
      gateway.then(DtnGatewayOutcome.needRetry);
      gateway.reachable = true;
      engine.store(envelope('p1'));
      final scheduler = DeliveryScheduler(
        engine: engine,
        gateway: gateway,
        now: () => clock.now,
      );
      scheduler.start();
      expect(engine.snapshot().retry, 1);
      expect(engine.statistics.retried, 1);
      final packet = engine.statusOf('p1') ?? fail('missing');
      expect(packet.attemptCount, 1);
      expect(packet.nextAttemptAt, clock.now.add(const Duration(seconds: 10)));
      scheduler.stop();
    });

    test('due retries re-arm on the next tick', () {
      gateway.then(DtnGatewayOutcome.needRetry);
      gateway.reachable = true;
      engine.store(envelope('p1'));
      final scheduler = DeliveryScheduler(
        engine: engine,
        gateway: gateway,
        now: () => clock.now,
      );
      scheduler.start();
      expect(engine.snapshot().retry, 1);

      clock.advance(const Duration(seconds: 11));
      engine.rearmRetries(engine.retriesDue(clock.now));
      expect(engine.snapshot().outgoing, 1);
      scheduler.stop();
    });

    test('reaching the retry limit parks the envelope (no data loss)', () {
      gateway.reachable = true;
      gateway
        ..then(DtnGatewayOutcome.needRetry)
        ..then(DtnGatewayOutcome.needRetry)
        ..then(DtnGatewayOutcome.needRetry);
      engine.store(envelope('p1'));
      final scheduler = DeliveryScheduler(
        engine: engine,
        gateway: gateway,
        now: () => clock.now,
      );
      scheduler.start();
      // attempt 1 fails -> retrying(10s)
      clock.advance(const Duration(seconds: 11));
      scheduler.tick();
      // attempt 2 fails -> retrying(20s)
      clock.advance(const Duration(seconds: 21));
      scheduler.tick();
      // attempt 3 fails -> limit reached -> parked
      expect(engine.snapshot().deferred, 1);
      expect(engine.snapshot().retry, 0);
      expect(engine.statistics.delivered, 0);
      scheduler.stop();
    });

    test('a permanent rejection fails the envelope immediately', () {
      gateway.then(DtnGatewayOutcome.rejected);
      gateway.reachable = true;
      engine.store(envelope('p1'));
      final scheduler = DeliveryScheduler(
        engine: engine,
        gateway: gateway,
        now: () => clock.now,
      );
      scheduler.start();
      expect(engine.snapshot().live, 0);
      expect(engine.snapshot().retry, 0);
      scheduler.stop();
    });
  });

  group('acknowledgements', () {
    test('acknowledged envelopes reach delivered', () {
      gateway.reachable = true;
      gateway.then(DtnGatewayOutcome.accepted); // expects a logical ack
      engine.store(envelope('p1'));
      final scheduler = DeliveryScheduler(
        engine: engine,
        gateway: gateway,
        now: () => clock.now,
      );
      scheduler.start();
      expect(engine.snapshot().awaitingAck, 1);

      engine.acknowledge('p1', by: 'node-b');
      expect(engine.statistics.acknowledged, 1);
      expect(engine.snapshot().live, 0);
      scheduler.stop();
    });

    test('duplicate acks are deduplicated', () {
      gateway.reachable = true;
      engine.store(envelope('p1'));
      final scheduler = DeliveryScheduler(
        engine: engine,
        gateway: gateway,
        now: () => clock.now,
      );
      scheduler.start();
      engine.acknowledge('p1');
      engine.acknowledge('p1');
      expect(engine.statistics.deduplicated, 1);
      scheduler.stop();
    });

    test('an ack timeout re-arms the envelope for delivery', () async {
      gateway.reachable = true;
      gateway.then(DtnGatewayOutcome.accepted); // expects a logical ack
      engine.store(envelope('p1'));
      final scheduler = DeliveryScheduler(
        engine: engine,
        gateway: gateway,
        now: () => clock.now,
      );
      scheduler.start();
      expect(engine.snapshot().awaitingAck, 1);
      await scheduler.stop();

      clock.advance(config.ackTimeout + const Duration(seconds: 1));
      engine.rearmAckTimeouts(engine.ackTimeouts(clock.now));
      expect(engine.snapshot().outgoing, 1);
      expect(engine.snapshot().awaitingAck, 0);
    });
  });

  group('expiration', () {
    test('expired envelopes are swept and removed', () {
      engine.store(
        envelope(
          'p1',
          ttlSeconds: 60,
          createdAt: clock.now.subtract(const Duration(minutes: 2)),
        ),
      );
      engine.store(envelope('p2'));
      engine.expireAll(
        engine.expiredDue(clock.now.add(const Duration(seconds: 1))),
      );
      expect(engine.statistics.expired, 1);
      expect(engine.snapshot().live, 1);
    });

    test('a tick expires overdue envelopes even when offline', () {
      gateway.reachable = false;
      engine.store(
        envelope(
          'p1',
          ttlSeconds: 60,
          createdAt: clock.now.subtract(const Duration(minutes: 2)),
        ),
      );
      final scheduler = DeliveryScheduler(
        engine: engine,
        gateway: gateway,
        now: () => clock.now,
      );
      scheduler.start();
      expect(engine.statistics.expired, 1);
      expect(engine.snapshot().live, 0);
      scheduler.stop();
    });
  });

  group('recovery', () {
    test('restore rehydrates envelopes into the right queues', () {
      engine.store(envelope('queued'));
      engine.store(envelope('retry'));
      engine.noteAttempt('retry', false, error: 'flaky', at: clock.now);
      expect(engine.snapshot().retry, 1);

      final fresh = buildEngine();
      fresh.restore(persistence.rows.values.toList(), at: clock.now);
      expect(fresh.snapshot().outgoing, 1);
      expect(fresh.snapshot().retry, 1);
    });

    test('retry windows that passed while offline are re-armed', () {
      engine.store(envelope('p1', ttlSeconds: 86400));
      engine.noteAttempt('p1', false, error: 'flaky', at: clock.now);
      clock.advance(const Duration(hours: 2));

      final fresh = buildEngine();
      const NetworkRecoveryManager().restore(
        fresh,
        persistence.rows.values.toList(),
      );
      expect(fresh.snapshot().outgoing, 1);
      expect(fresh.snapshot().retry, 0);
    });

    test('envelopes expired before restore are pruned', () {
      engine.store(envelope('p1', ttlSeconds: 60));
      clock.advance(const Duration(minutes: 5));

      final fresh = buildEngine();
      fresh.restore(persistence.rows.values.toList(), at: clock.now);
      expect(fresh.snapshot().live, 0);
      expect(fresh.statistics.expired, 1);
    });
  });

  group('cancel & status', () {
    test('cancel removes a live envelope', () {
      engine.store(envelope('p1'));
      engine.cancel('p1');
      expect(engine.snapshot().live, 0);
      expect(() => engine.cancel('p1'), throwsA(isA<DtnFailure>()));
    });

    test('statusOf reports current state', () {
      engine.store(envelope('p1'));
      expect(engine.statusOf('p1')!.state, DtnPacketState.queued);
      expect(engine.statusOf('unknown'), isNull);
    });
  });

  group('inbound', () {
    test('deliverLocally hands the envelope to upper layers', () async {
      final deliveries = <DtnPacket>[];
      engine.inboundDeliveries.listen(deliveries.add);

      final arrived = DtnPacket(
        packetId: 'from-b',
        source: 'node-b',
        destination: 'node-a',
        payload: 'reply'.codeUnits,
        priority: DtnPriority.normal,
        direction: DtnDirection.inbound,
        ttlSeconds: 3600,
        createdAt: clock.now,
        expiresAt: clock.now.add(const Duration(hours: 1)),
      );
      engine.deliverLocally(arrived);
      await Future<void>.delayed(Duration.zero);
      expect(deliveries, hasLength(1));
      expect(engine.snapshot().incoming, 1);
    });
  });
}
