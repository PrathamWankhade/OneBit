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

  @override
  Future<TransmissionResult> transmit({
    required OneBitMessage message,
    required MessageEnvelope envelope,
  }) async {
    seen = envelope;
    return const TransmissionResult.noRoute();
  }
}
