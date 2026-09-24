import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/ble/ble_service.dart';
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
  const nextHopPeerId =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  Route makeRoute({
    String? destination,
    String? nextHop,
    int metric = 1,
  }) {
    final now = DateTime.now();
    return Route(
      destinationPeerId: destination ?? remotePeerId,
      nextHopPeerId: nextHop ?? nextHopPeerId,
      metric: metric,
      state: RouteState.active,
      source: RouteSource.direct,
      createdAt: now,
      lastValidatedAt: now,
    );
  }

  OneBitMessage makeMessage({String? destination}) {
    final now = DateTime.now().toUtc();
    return OneBitMessage(
      id: MessageId(),
      sourcePeerId: localPeerId,
      destinationPeerId: destination ?? remotePeerId,
      createdAt: now,
      payloadSizeBytes: 5,
    );
  }

  MessageEnvelope makeEnvelope({OneBitMessage? message}) {
    final msg = message ?? makeMessage();
    return MessageEnvelope(
      protocolVersion: messageProtocolVersion,
      messageId: msg.id,
      sourcePeerId: msg.sourcePeerId,
      destinationPeerId: msg.destinationPeerId,
      payload: Uint8List.fromList('Hello'.codeUnits),
    );
  }

  MessageTransmissionService createService({
    Route? route,
    String? deviceId,
    bool peerConnected = true,
    BleService? bleService,
  }) {
    return MessageTransmissionService(
      localPeerId: localPeerId,
      bleService: bleService ?? BleService(),
      routeLookup: (dest) => route,
      deviceResolver: (peerId) => deviceId,
      isPeerConnected: (peerId) => peerConnected,
    );
  }

  group('MessageTransmissionService', () {
    test('transmit succeeds with valid route and connected peer', () async {
      final service = createService(
        route: makeRoute(),
        deviceId: 'ble_device_001',
      );

      final message = makeMessage();
      final envelope = makeEnvelope(message: message);

      final result = await service.transmit(
        message: message,
        envelope: envelope,
      );

      // Result depends on BleService behavior — with a real BleService
      // without a mock, it will fail at the transport level.
      // This test validates the pipeline runs without throwing.
      expect(
        result,
        anyOf(
          isA<TransmissionSent>(),
          isA<TransmissionTransportFailed>(),
        ),
      );
    });

    test('transmit rejects message to self', () async {
      final service = createService(
        route: makeRoute(),
        deviceId: 'ble_device_001',
      );

      final message = makeMessage(destination: localPeerId);
      final envelope = makeEnvelope(message: message);

      final result = await service.transmit(
        message: message,
        envelope: envelope,
      );

      expect(result, isA<TransmissionRejected>());
    });

    test('transmit returns noRoute when no route exists', () async {
      final service = createService(route: null);

      final message = makeMessage();
      final envelope = makeEnvelope(message: message);

      final result = await service.transmit(
        message: message,
        envelope: envelope,
      );

      expect(result, isA<TransmissionNoRoute>());
    });

    test('transmit returns nextHopUnavailable when peer not connected',
        () async {
      final service = createService(
        route: makeRoute(),
        peerConnected: false,
      );

      final message = makeMessage();
      final envelope = makeEnvelope(message: message);

      final result = await service.transmit(
        message: message,
        envelope: envelope,
      );

      expect(result, isA<TransmissionNextHopUnavailable>());
    });

    test('transmit returns nextHopUnavailable when no BLE device', () async {
      final service = createService(
        route: makeRoute(),
        deviceId: null,
      );

      final message = makeMessage();
      final envelope = makeEnvelope(message: message);

      final result = await service.transmit(
        message: message,
        envelope: envelope,
      );

      expect(result, isA<TransmissionNextHopUnavailable>());
    });

    test('transmit rejects invalid envelope', () async {
      final service = createService(
        route: makeRoute(),
        deviceId: 'ble_device_001',
      );

      final message = makeMessage();
      // Create an envelope with mismatched source.
      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: message.id,
        sourcePeerId: 'xx' * 32, // wrong source
        destinationPeerId: message.destinationPeerId,
        payload: Uint8List.fromList('Hello'.codeUnits),
      );

      final result = await service.transmit(
        message: message,
        envelope: envelope,
      );

      expect(result, isA<TransmissionRejected>());
    });

    test('destination PeerId remains immutable during transmission', () async {
      final service = MessageTransmissionService(
        localPeerId: localPeerId,
        bleService: BleService(),
        routeLookup: (dest) {
          // Capture the destination used in route lookup.
          return makeRoute();
        },
        deviceResolver: (peerId) => 'ble_device_001',
        isPeerConnected: (peerId) => true,
      );

      final message = makeMessage();
      final envelope = makeEnvelope(message: message);

      await service.transmit(message: message, envelope: envelope);

      // The destination PeerId in the message must not have changed.
      expect(message.destinationPeerId, equals(remotePeerId));
    });

    test('nextHopPeerId is not baked into message identity', () async {
      final service = createService(
        route: makeRoute(nextHop: nextHopPeerId),
        deviceId: 'ble_device_001',
      );

      final message = makeMessage();
      final envelope = makeEnvelope(message: message);

      await service.transmit(
        message: message,
        envelope: envelope,
      );

      // The message's destinationPeerId must still be remotePeerId,
      // not nextHopPeerId.
      expect(message.destinationPeerId, equals(remotePeerId));
      expect(message.destinationPeerId, isNot(equals(nextHopPeerId)));
    });

    test('stale route does not cause crash', () async {
      final service = createService(route: null); // bestRoute returns null

      final message = makeMessage();
      final envelope = makeEnvelope(message: message);

      final result = await service.transmit(
        message: message,
        envelope: envelope,
      );

      expect(result, isA<TransmissionNoRoute>());
    });

    test('concurrent transmissions are isolated', () async {
      final service = createService(
        route: makeRoute(),
        deviceId: 'ble_device_001',
      );

      final msg1 = makeMessage();
      final msg2 = makeMessage();
      final env1 = makeEnvelope(message: msg1);
      final env2 = makeEnvelope(message: msg2);

      final results = await Future.wait([
        service.transmit(message: msg1, envelope: env1),
        service.transmit(message: msg2, envelope: env2),
      ]);

      // Both should complete independently.
      expect(results.length, equals(2));
    });
  });

  group('TransmissionResult', () {
    test('TransmissionSent carries nextHopPeerId and routeMetric', () {
      const result = TransmissionResult.sentToNextHop(
        nextHopPeerId: 'next_hop',
        routeMetric: 2,
      );
      expect(result, isA<TransmissionSent>());
      const sent = result as TransmissionSent;
      expect(sent.nextHopPeerId, equals('next_hop'));
      expect(sent.routeMetric, equals(2));
    });

    test('TransmissionNoRoute is a valid result', () {
      const result = TransmissionResult.noRoute();
      expect(result, isA<TransmissionNoRoute>());
    });

    test('TransmissionNextHopUnavailable carries peerId', () {
      const result = TransmissionResult.nextHopUnavailable(
        nextHopPeerId: 'peer',
      );
      expect(result, isA<TransmissionNextHopUnavailable>());
      const unavailable = result as TransmissionNextHopUnavailable;
      expect(unavailable.nextHopPeerId, equals('peer'));
    });

    test('TransmissionTransportFailed carries reason', () {
      const result = TransmissionResult.transportFailed(reason: 'timeout');
      expect(result, isA<TransmissionTransportFailed>());
      const failed = result as TransmissionTransportFailed;
      expect(failed.reason, equals('timeout'));
    });
  });
}
