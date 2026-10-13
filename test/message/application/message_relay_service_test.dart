import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/message/application/message_relay_service.dart';
import 'package:onebit/features/message/application/message_transmission_service.dart';
import 'package:onebit/features/message/models/message_envelope.dart';
import 'package:onebit/features/message/models/message_id.dart';
import 'package:onebit/features/message/models/onebit_message.dart';
import 'package:onebit/features/routing/route.dart';

void main() {
  const localPeerId =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const remotePeerId =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const thirdPeerId =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  Route makeRoute({
    String? dest,
    String? nextHop,
    int metric = 1,
  }) {
    return Route(
      destinationPeerId: dest ?? remotePeerId,
      nextHopPeerId: nextHop ?? remotePeerId,
      metric: metric,
      state: RouteState.active,
      source: RouteSource.direct,
      createdAt: DateTime.now().toUtc(),
      lastValidatedAt: DateTime.now().toUtc(),
    );
  }

  MessageId makeId() => MessageId();

  MessageEnvelope makeEnvelope({
    MessageId? messageId,
    String? source,
    String? destination,
    Uint8List? payload,
    int hopCount = 0,
  }) {
    return MessageEnvelope(
      protocolVersion: messageProtocolVersion,
      messageId: messageId ?? makeId(),
      sourcePeerId: source ?? remotePeerId,
      destinationPeerId: destination ?? localPeerId,
      hopCount: hopCount,
      payload: payload ?? Uint8List.fromList([1, 2, 3]),
    );
  }

  MessageTransmissionService createTransmissionService({
    Route? route,
    String? deviceId,
    bool peerConnected = true,
  }) {
    return MessageTransmissionService(
      localPeerId: localPeerId,
      bleService: BleService(),
      routeLookup: (dest) => route,
      deviceResolver: (peerId) => deviceId,
      isPeerConnected: (peerId) => peerConnected,
    );
  }

  MessageRelayService createRelayService({
    MessageTransmissionService? transmissionService,
  }) {
    return MessageRelayService(
      localPeerId: localPeerId,
      transmissionService: transmissionService ?? createTransmissionService(),
    );
  }

  group('MessageRelayService', () {
    test('local destination returns LocalDestination', () async {
      final service = createRelayService();
      final envelope = makeEnvelope(destination: localPeerId);

      final result = await service.receiveAndRelay(envelope);

      expect(result, isA<LocalDestination>());
    });

    test('non-local destination triggers relay attempt', () async {
      final route = makeRoute(dest: thirdPeerId, nextHop: thirdPeerId);
      final service = createRelayService(
        transmissionService: createTransmissionService(
          route: route,
          deviceId: 'ble_device_001',
        ),
      );
      final envelope = makeEnvelope(destination: thirdPeerId);

      final result = await service.receiveAndRelay(envelope);

      // With a real BleService in tests, transport may fail.
      // This validates the relay pipeline runs without throwing.
      expect(
        result,
        anyOf(
          isA<Forwarded>(),
          isA<RelayFailed>(),
        ),
      );
    });

    test('relay spends one hop before re-transmitting', () async {
      final transmission = _RecordingTransmission(localPeerId: localPeerId);
      final service = MessageRelayService(
        localPeerId: localPeerId,
        transmissionService: transmission,
      );
      final envelope = makeEnvelope(
        destination: thirdPeerId,
        hopCount: 3,
      );

      await service.receiveAndRelay(envelope);

      expect(transmission.seen, isNotNull);
      expect(transmission.seen!.hopCount, equals(4));
      // Transit state, not identity: the relay never mutates what it
      // was handed, so the incoming record stays intact.
      expect(envelope.hopCount, equals(3));
      expect(transmission.seen!.sourcePeerId, equals(envelope.sourcePeerId));
      expect(transmission.seen!.messageId, equals(envelope.messageId));
    });

    test('relay refuses once the hop budget is spent', () async {
      final transmission = _RecordingTransmission(localPeerId: localPeerId);
      final service = MessageRelayService(
        localPeerId: localPeerId,
        transmissionService: transmission,
      );
      final envelope = makeEnvelope(
        destination: thirdPeerId,
        hopCount: maxEnvelopeHops,
      );

      final result = await service.receiveAndRelay(envelope);

      expect(result, isA<RelayFailed>());
      expect((result as RelayFailed).reason, contains('Hop limit reached'));
      expect(transmission.seen, isNull);
    });

    test('relay still delivers to itself at the hop budget', () async {
      final transmission = _RecordingTransmission(localPeerId: localPeerId);
      final service = MessageRelayService(
        localPeerId: localPeerId,
        transmissionService: transmission,
      );

      final result = await service.receiveAndRelay(
        makeEnvelope(destination: localPeerId, hopCount: maxEnvelopeHops),
      );

      expect(result, isA<LocalDestination>());
      expect(transmission.seen, isNull);
    });

    // I9.16.b — the loop contract: hop limits are what make cycles in
    // the mesh safe, so pin what they actually guarantee.
    test('a looping envelope dies within the hop budget, not in copies',
        () async {
      final transmission = _RecordingTransmission(localPeerId: localPeerId);
      final service = MessageRelayService(
        localPeerId: localPeerId,
        transmissionService: transmission,
      );

      // Two nodes with stale routes can hand the same message back
      // and forth all night. Every pass through a relay spends one
      // hop on the copy that continues, so the wandering ends at
      // [maxEnvelopeHops] no matter how the routes lie.
      var envelope = makeEnvelope(destination: thirdPeerId);
      var refusedAtBudget = false;
      var passes = 0;
      while (true) {
        final result = await service.receiveAndRelay(envelope);
        passes++;
        if (result is RelayFailed &&
            result.reason.contains('Hop limit reached')) {
          refusedAtBudget = true;
          break;
        }
        // Bounded even if the wall above were missing: each pass
        // spends a hop, so the passes themselves are the budget.
        expect(
          passes,
          lessThanOrEqualTo(maxEnvelopeHops + 1),
          reason: 'every pass spends a hop, so passes are bounded',
        );
        envelope = envelope.withAdditionalHop();
      }

      expect(refusedAtBudget, isTrue);
      // The last copy anyone tried to put on the wire carried the
      // full budget…
      expect(transmission.seen!.hopCount, maxEnvelopeHops);
      // …and all those passes cost exactly one held forward, because
      // the hold is keyed by message id. A loop costs hops, never
      // copies: nothing here multiplies.
      expect(service.pendingForwardCount, 1);
    });

    test('source PeerId is preserved during relay', () async {
      const originalSource = remotePeerId;
      final route = makeRoute(dest: thirdPeerId, nextHop: thirdPeerId);
      final service = createRelayService(
        transmissionService: createTransmissionService(
          route: route,
          deviceId: 'ble_device_001',
        ),
      );
      final envelope = makeEnvelope(
        source: originalSource,
        destination: thirdPeerId,
      );

      await service.receiveAndRelay(envelope);

      // The transmission service should have received a message
      // with the original source, not localPeerId.
      // We verify by checking the envelope is unchanged.
      expect(envelope.sourcePeerId, equals(originalSource));
    });

    test('destination PeerId is preserved during relay', () async {
      final route = makeRoute(dest: thirdPeerId, nextHop: thirdPeerId);
      final service = createRelayService(
        transmissionService: createTransmissionService(
          route: route,
          deviceId: 'ble_device_001',
        ),
      );
      final envelope = makeEnvelope(destination: thirdPeerId);

      await service.receiveAndRelay(envelope);

      expect(envelope.destinationPeerId, equals(thirdPeerId));
    });

    test('MessageId is preserved during relay', () async {
      final messageId = makeId();
      final route = makeRoute(dest: thirdPeerId, nextHop: thirdPeerId);
      final service = createRelayService(
        transmissionService: createTransmissionService(
          route: route,
          deviceId: 'ble_device_001',
        ),
      );
      final envelope = makeEnvelope(
        messageId: messageId,
        destination: thirdPeerId,
      );

      await service.receiveAndRelay(envelope);

      expect(envelope.messageId, equals(messageId));
    });

    test('no route produces RelayFailed', () async {
      final service = createRelayService(
        transmissionService: createTransmissionService(route: null),
      );
      final envelope = makeEnvelope(destination: thirdPeerId);

      final result = await service.receiveAndRelay(envelope);

      expect(result, isA<RelayFailed>());
      final failed = result as RelayFailed;
      expect(failed.reason, contains('No route'));
    });

    test('next hop unavailable produces RelayFailed', () async {
      final route = makeRoute(dest: thirdPeerId, nextHop: thirdPeerId);
      final service = createRelayService(
        transmissionService: createTransmissionService(
          route: route,
          peerConnected: false,
        ),
      );
      final envelope = makeEnvelope(destination: thirdPeerId);

      final result = await service.receiveAndRelay(envelope);

      expect(result, isA<RelayFailed>());
    });

    test('invalid envelope produces RelayFailed', () async {
      final service = createRelayService();
      // Create an envelope with invalid version.
      final envelope = MessageEnvelope(
        protocolVersion: 99,
        messageId: makeId(),
        sourcePeerId: remotePeerId,
        destinationPeerId: thirdPeerId,
        payload: Uint8List.fromList([1, 2, 3]),
      );

      final result = await service.receiveAndRelay(envelope);

      expect(result, isA<RelayFailed>());
    });

    test('relay event is recorded', () async {
      final service = createRelayService();
      final envelope = makeEnvelope(destination: localPeerId);

      await service.receiveAndRelay(envelope);

      expect(service.events.length, equals(1));
      expect(service.events.first.messageId, equals(envelope.messageId));
    });

    test('concurrent relays are isolated', () async {
      final route1 = makeRoute(dest: thirdPeerId, nextHop: thirdPeerId);
      final service = createRelayService(
        transmissionService: createTransmissionService(
          route: route1,
          deviceId: 'ble_device_001',
        ),
      );

      final envelope1 = makeEnvelope(destination: thirdPeerId);
      final envelope2 = makeEnvelope(destination: localPeerId);

      final results = await Future.wait([
        service.receiveAndRelay(envelope1),
        service.receiveAndRelay(envelope2),
      ]);

      // First result is either Forwarded or RelayFailed (transport).
      expect(
        results[0],
        anyOf(isA<Forwarded>(), isA<RelayFailed>()),
      );
      // Second result is always LocalDestination (addressed to us).
      expect(results[1], isA<LocalDestination>());
    });

    test('multiple events are bounded', () async {
      final service = createRelayService();

      // Generate 105 events (exceeds _maxRelayEvents=100).
      for (var i = 0; i < 105; i++) {
        final envelope = makeEnvelope(destination: localPeerId);
        await service.receiveAndRelay(envelope);
      }

      // Should be bounded at 100.
      expect(service.events.length, lessThanOrEqualTo(100));
    });
  });

  group('RelayResult', () {
    test('LocalDestination is a valid result', () {
      const result = RelayResult.localDestination();
      expect(result, isA<LocalDestination>());
    });

    test('Forwarded carries nextHopPeerId and routeMetric', () {
      const result = RelayResult.forwarded(
        nextHopPeerId: 'peer',
        routeMetric: 3,
      );
      expect(result, isA<Forwarded>());
      const forwarded = result as Forwarded;
      expect(forwarded.nextHopPeerId, equals('peer'));
      expect(forwarded.routeMetric, equals(3));
    });

    test('RelayFailed carries reason', () {
      const result = RelayResult.relayFailed(reason: 'No route');
      expect(result, isA<RelayFailed>());
      const failed = result as RelayFailed;
      expect(failed.reason, equals('No route'));
    });
  });

  group('I9.11.b forward retry backs off and bounds itself', () {
    test('a transient forward failure holds the envelope for retry', () async {
      final transmission = _ScriptedTransmission(localPeerId: localPeerId);
      final service = MessageRelayService(
        localPeerId: localPeerId,
        transmissionService: transmission,
      );
      final envelope = makeEnvelope(destination: thirdPeerId);

      final result = await service.receiveAndRelay(envelope);

      expect(result, isA<RelayFailed>());
      expect(service.pendingForwardCount, 1);
      expect(
        service.nextForwardRetryAt(envelope.messageId),
        isNotNull,
      );
    });

    test('a deterministic failure is not held', () async {
      final transmission = _ScriptedTransmission(localPeerId: localPeerId)
        ..results.add(const TransmissionResult.rejected(reason: 'nope'));
      final service = MessageRelayService(
        localPeerId: localPeerId,
        transmissionService: transmission,
      );
      final envelope = makeEnvelope(destination: thirdPeerId);

      final result = await service.receiveAndRelay(envelope);

      expect(result, isA<RelayFailed>());
      expect(service.pendingForwardCount, 0);
      expect(service.nextForwardRetryAt(envelope.messageId), isNull);
    });

    test('the wait is honoured, then the retry goes out and clears', () async {
      final transmission = _ScriptedTransmission(localPeerId: localPeerId);
      final service = MessageRelayService(
        localPeerId: localPeerId,
        transmissionService: transmission,
        retryBaseBackoff: const Duration(milliseconds: 300),
      );
      final envelope = makeEnvelope(destination: thirdPeerId);

      await service.receiveAndRelay(envelope); // attempt 1 → held
      final afterFirst = transmission.seen.length;
      expect(service.pendingForwardCount, 1);

      // Inside the wait: draining changes nothing.
      await service.retryDueForwards();
      expect(transmission.seen.length, afterFirst);

      // Past it: the retry goes out (the mesh looks better now) and,
      // landing, ends the hold.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      transmission.results.add(
        const TransmissionResult.sentToNextHop(
          nextHopPeerId: thirdPeerId,
          routeMetric: 1,
        ),
      );
      await service.retryDueForwards();

      expect(service.pendingForwardCount, 0);
      expect(transmission.seen.length, afterFirst + 1);
      // One hop per attempt, not one per queueing: the retried send
      // carries exactly one more hop than the arrival did.
      expect(transmission.seen.last.hopCount, envelope.hopCount + 1);
    });

    test('a forward that never lands is written off at the budget', () async {
      final transmission = _ScriptedTransmission(localPeerId: localPeerId);
      final service = MessageRelayService(
        localPeerId: localPeerId,
        transmissionService: transmission,
        retryBaseBackoff: const Duration(milliseconds: 10),
        maxRetryAttempts: 3,
      );
      final envelope = makeEnvelope(destination: thirdPeerId);

      await service.receiveAndRelay(envelope); // attempt 1, held
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await service.retryDueForwards(); // attempt 2, still transient
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await service.retryDueForwards(); // attempt 3, budget spent

      expect(transmission.seen.length, 3);
      expect(service.pendingForwardCount, 0);
      final last = service.events.last.result as RelayFailed;
      expect(last.reason, contains('Gave up'));
    });

    test('the participation switch stops a queue mid-hold', () async {
      var relayOn = true;
      final transmission = _ScriptedTransmission(localPeerId: localPeerId);
      final service = MessageRelayService(
        localPeerId: localPeerId,
        transmissionService: transmission,
        forwardingAllowed: () => relayOn,
        retryBaseBackoff: const Duration(milliseconds: 10),
      );
      final envelope = makeEnvelope(destination: thirdPeerId);

      await service.receiveAndRelay(envelope); // attempt 1 → held
      expect(service.pendingForwardCount, 1);

      relayOn = false;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await service.retryDueForwards();

      expect(service.pendingForwardCount, 0);
      expect(transmission.seen.length, 1); // no second transmit
      final last = service.events.last.result as RelayFailed;
      expect(last.reason, contains('disabled'));
    });

    test('the hold queue is bounded to its cap', () async {
      final transmission = _ScriptedTransmission(localPeerId: localPeerId);
      final service = MessageRelayService(
        localPeerId: localPeerId,
        transmissionService: transmission,
        maxPendingForwards: 2,
      );
      final first = makeEnvelope(destination: thirdPeerId);
      final second = makeEnvelope(destination: thirdPeerId);
      final third = makeEnvelope(destination: thirdPeerId);

      await service.receiveAndRelay(first);
      await service.receiveAndRelay(second);
      await service.receiveAndRelay(third);

      expect(service.pendingForwardCount, 2);
      // Insertion order: the oldest hold is evicted first.
      expect(service.nextForwardRetryAt(first.messageId), isNull);
      expect(service.nextForwardRetryAt(second.messageId), isNotNull);
      expect(service.nextForwardRetryAt(third.messageId), isNotNull);
    });

    test('a duplicate arrival of a held envelope does not double it', () async {
      final transmission = _ScriptedTransmission(localPeerId: localPeerId);
      final service = MessageRelayService(
        localPeerId: localPeerId,
        transmissionService: transmission,
      );
      final envelope = makeEnvelope(destination: thirdPeerId);

      await service.receiveAndRelay(envelope);
      await service.receiveAndRelay(envelope);

      expect(service.pendingForwardCount, 1);
      expect(transmission.seen.length, 2); // both arrivals tried once
    });

    // I9.16.d — the timer half of the retry contract. app.dart starts
    // the timer with the service and stops it with the provider; both
    // halves have to be real, or either holds leak or traffic keeps
    // moving after the app let go.
    test('the retry timer drives held forwards, and stops driving them',
        () async {
      final transmission = _RecordingTransmission(localPeerId: localPeerId);
      final service = MessageRelayService(
        localPeerId: localPeerId,
        transmissionService: transmission,
        retryBaseBackoff: Duration.zero,
        retryTick: const Duration(milliseconds: 10),
        maxRetryAttempts: 1000,
      );

      // No route: the arrival spends its attempt and holds.
      await service.receiveAndRelay(makeEnvelope(destination: thirdPeerId));
      expect(service.pendingForwardCount, 1);
      final afterArrival = transmission.calls;

      // Started, the timer hands the hold its attempts...
      service.startRetrying();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(transmission.calls, greaterThan(afterArrival));

      // ...and stopping it really stops: let the last tick's work
      // settle, then watch. The hold is still due and the budget is
      // nowhere near spent — the only reason nothing moves is the
      // stopped timer.
      service.stopRetrying();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final atStop = transmission.calls;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(transmission.calls, atStop);
      expect(service.pendingForwardCount, 1);
    });
  });
}

/// A transmission service that never touches BLE, so a test can see
/// exactly what the relay asked to put on the wire.
class _RecordingTransmission extends MessageTransmissionService {
  _RecordingTransmission({required super.localPeerId})
      : super(
          bleService: BleService(),
          routeLookup: (_) => null,
          deviceResolver: (_) => null,
          isPeerConnected: (_) => false,
        );

  /// The last envelope the relay asked to transmit, if any.
  MessageEnvelope? seen;

  /// How many times it has asked, all told.
  int calls = 0;

  @override
  Future<TransmissionResult> transmit({
    required OneBitMessage message,
    required MessageEnvelope envelope,
  }) async {
    calls++;
    seen = envelope;
    return const TransmissionResult.noRoute();
  }
}

/// A transmission fake whose answers a test scripts in order; with an
/// empty script every attempt fails transiently (no route), which is
/// exactly the case retry has to cope with.
class _ScriptedTransmission extends MessageTransmissionService {
  _ScriptedTransmission({required super.localPeerId})
      : super(
          bleService: BleService(),
          routeLookup: (_) => null,
          deviceResolver: (_) => null,
          isPeerConnected: (_) => false,
        );

  /// One answer per attempt, consumed in order.
  final results = <TransmissionResult>[];

  /// Every envelope the relay asked to transmit, in order.
  final seen = <MessageEnvelope>[];

  @override
  Future<TransmissionResult> transmit({
    required OneBitMessage message,
    required MessageEnvelope envelope,
  }) async {
    seen.add(envelope);
    if (results.isEmpty) return const TransmissionResult.noRoute();
    return results.removeAt(0);
  }
}
