import 'package:onebit/features/dtn/delivery/dtn_config.dart';
import 'package:onebit/features/dtn/delivery/dtn_gateway.dart';
import 'package:onebit/features/dtn/delivery/store_forward_engine.dart';
import 'package:onebit/features/dtn/domain/dtn_connectivity.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';
import 'package:onebit/features/dtn/domain/dtn_priority.dart';

/// Minimal gateway used by the DTN unit tests.
final class TestGateway implements DtnGateway {
  TestGateway({this.reachable = true});

  bool reachable;
  final List<DtnGatewayOutcome> outcomes = [];
  DtnGatewayOutcome? fallback = DtnGatewayOutcome.acceptedNoAck;
  final List<DtnPacket> transmitted = [];

  @override
  DtnConnectivitySnapshot connectivity() =>
      DtnConnectivitySnapshot(reachable: reachable);

  @override
  DtnGatewayOutcome transmit(DtnPacket packet) {
    transmitted.add(packet);
    if (outcomes.isNotEmpty) {
      return outcomes.removeAt(0);
    }
    return fallback ?? DtnGatewayOutcome.acceptedNoAck;
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void onLayerEvent(String event) {}
}

/// Deterministic wall clock.
final class TestClock {
  DateTime _now = DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);

  DateTime get now => _now;

  void advance(Duration by) => _now = _now.add(by);
}

/// Shared harness for DTN unit tests: engine + gateway + clock + helpers.
final class DtnHarness {
  DtnHarness({
    DtnEngineConfig config = const DtnEngineConfig(
      batchLimit: 8,
      ackTimeout: Duration(minutes: 5),
      retryPolicy: DtnRetryPolicy(
        baseDelay: Duration(seconds: 10),
        factor: 2,
        maxDelay: Duration(minutes: 1),
        jitterRatio: 0,
        limit: 3,
      ),
    ),
  }) : gateway = TestGateway(),
       clock = TestClock() {
    engine = StoreForwardEngine(
      config: config,
      persistence: MemoryDtnPersistence(),
      now: () => clock.now,
      gateway: gateway,
    );
  }

  final TestGateway gateway;
  final TestClock clock;
  late final StoreForwardEngine engine;

  /// Store a valid outbound envelope via the engine store path.
  DtnPacket store(
    String packetId, {
    String destination = 'node-b',
    DtnPriority priority = DtnPriority.normal,
    int ttlSeconds = 3600,
    List<int> payload = const [1, 2, 3],
  }) {
    return engine.store(
      DtnPacket(
        packetId: packetId,
        source: 'node-a',
        destination: destination,
        payload: payload,
        priority: priority,
        direction: DtnDirection.outbound,
        ttlSeconds: ttlSeconds,
        createdAt: clock.now,
        expiresAt: clock.now.add(Duration(seconds: ttlSeconds)),
      ),
    );
  }

  /// Place an envelope directly into a given lifecycle state via reattach.
  DtnPacket place(
    String packetId, {
    DtnPacketState state = DtnPacketState.queued,
    DtnDirection direction = DtnDirection.outbound,
    String destination = 'node-b',
    DtnPriority priority = DtnPriority.normal,
    DateTime? nextAttemptAt,
    DateTime? ackDeadlineAt,
    DateTime? expiresAt,
    int ttlSeconds = 3600,
  }) {
    final packet = DtnPacket(
      packetId: packetId,
      source: 'node-a',
      destination: destination,
      payload: const [1, 2, 3],
      priority: priority,
      direction: direction,
      ttlSeconds: ttlSeconds,
      createdAt: clock.now,
      expiresAt: expiresAt ?? clock.now.add(Duration(seconds: ttlSeconds)),
      state: state,
      nextAttemptAt: nextAttemptAt,
      ackDeadlineAt: ackDeadlineAt,
      attemptCount: state == DtnPacketState.retrying ? 1 : 0,
    );
    engine.reattach(packet);
    return packet;
  }

  /// Run one scheduler pass at the current clock time.
  void tick() {
    final now = clock.now;
    final due = engine.expiredDue(now);
    if (due.isNotEmpty) {
      engine.expireAll(due, at: now);
    }
    engine.setConnectivity(gateway.connectivity());
    if (!gateway.reachable) {
      engine.parkAll(at: now);
      return;
    }
    engine.rearmRetries(engine.retriesDue(now));
    engine.rearmRelaying();
    for (final packet in engine.outgoingCandidates()) {
      final outcome = gateway.transmit(packet);
      engine.noteAttempt(
        packet.packetId,
        outcome.ok,
        error: outcome.errorMessage,
        permanent: outcome.permanent,
        willAck: outcome.willAck,
        at: now,
      );
    }
    final timeouts = engine.ackTimeouts(now);
    if (timeouts.isNotEmpty) {
      engine.rearmAckTimeouts(timeouts);
    }
  }
}
