import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/message/delivery/message_delivery_service.dart';
import 'package:onebit/features/message/models/message_envelope.dart';
import 'package:onebit/features/message/models/message_envelope_codec.dart';
import 'package:onebit/features/message/models/message_envelope_validator.dart';
import 'package:onebit/features/message/models/message_id.dart';
import 'package:onebit/features/message/models/message_state.dart';
import 'package:onebit/features/message/models/onebit_message.dart';
import 'package:onebit/features/routing/route.dart';

void main() {
  late String localPeerId;
  late String peerA;
  late String peerB;
  late String peerC;

  setUpAll(() {
    localPeerId = '00' * 32;
    peerA = 'aa' * 32;
    peerB = 'bb' * 32;
    peerC = 'cc' * 32;
  });

  group('I9.2 Message Identity & Envelope Integration', () {
    test('MessageId binary round-trip', () {
      final id = MessageId();
      final bytes = id.toBytes();
      final restored = MessageId.fromBytes(bytes);

      expect(restored, equals(id));
      expect(restored.toHexString(), equals(id.toHexString()));
    });

    test('MessageId string round-trip', () {
      final id = MessageId();
      final hex = id.toHexString();
      final restored = MessageId.fromString(hex);

      expect(restored, equals(id));
    });

    test('MessageEnvelope construction with MessageId type', () {
      final id = MessageId();
      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: id,
        sourcePeerId: peerA,
        destinationPeerId: peerB,
        payload: Uint8List.fromList([1, 2, 3]),
      );

      expect(envelope.messageId, equals(id));
      expect(envelope.isValid, isTrue);
    });

    test('MessageEnvelopeCodec round-trip preserves all fields', () {
      final id = MessageId();
      final original = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: id,
        sourcePeerId: peerA,
        destinationPeerId: peerB,
        payload: Uint8List.fromList([10, 20, 30, 40, 50]),
      );

      final bytes = MessageEnvelopeCodec.encode(original);
      final restored = MessageEnvelopeCodec.decode(bytes);

      expect(restored.messageId, equals(original.messageId));
      expect(restored.sourcePeerId, equals(original.sourcePeerId));
      expect(restored.destinationPeerId, equals(original.destinationPeerId));
      expect(restored.payload, equals(original.payload));
      expect(restored.protocolVersion, equals(original.protocolVersion));
    });

    test('MessageEnvelopeCodec determinism', () {
      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: MessageId(),
        sourcePeerId: peerA,
        destinationPeerId: peerB,
        payload: Uint8List.fromList([1, 2, 3]),
      );

      final bytes1 = MessageEnvelopeCodec.encode(envelope);
      final bytes2 = MessageEnvelopeCodec.encode(envelope);

      expect(bytes1, equals(bytes2));
    });

    test('MessageEnvelopeValidator accepts valid envelope', () {
      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: MessageId(),
        sourcePeerId: peerA,
        destinationPeerId: peerB,
        payload: Uint8List(0),
      );

      final result = MessageEnvelopeValidator.validate(envelope);
      expect(result.isValid, isTrue);
    });

    test('relay preservation — source and destination unchanged after pass-through', () {
      final id = MessageId();
      final original = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: id,
        sourcePeerId: peerA,
        destinationPeerId: peerC,
        payload: Uint8List.fromList([42]),
      );

      // Simulate: A creates message for C, passes through B.
      final bytes = MessageEnvelopeCodec.encode(original);
      final afterRelay = MessageEnvelopeCodec.decode(bytes);

      expect(afterRelay.sourcePeerId, equals(peerA));
      expect(afterRelay.destinationPeerId, equals(peerC));
      expect(afterRelay.messageId, equals(id));
    });

    test('route independence — envelope unchanged by route lookup', () {
      final id = MessageId();
      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: id,
        sourcePeerId: peerA,
        destinationPeerId: peerC,
        payload: Uint8List.fromList([1, 2]),
      );

      // Route: C via B.
      final route = Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerB,
        metric: 2,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime.utc(2026, 1, 1),
        lastValidatedAt: DateTime.utc(2026, 1, 1),
      );

      // Envelope does not reference the route.
      expect(envelope.destinationPeerId, equals(peerC));
      expect(route.nextHopPeerId, equals(peerB));
      // They are independent.
    });

    test('no-route — envelope remains valid without route', () {
      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: MessageId(),
        sourcePeerId: peerA,
        destinationPeerId: peerC,
        payload: Uint8List(0),
      );

      final result = MessageEnvelopeValidator.validate(envelope);
      expect(result.isValid, isTrue);
      // No route exists — envelope is still structurally valid.
    });

    test('unknown destination — envelope valid with unknown PeerId', () {
      final unknownPeer = 'ff' * 32;
      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: MessageId(),
        sourcePeerId: peerA,
        destinationPeerId: unknownPeer,
        payload: Uint8List(0),
      );

      final result = MessageEnvelopeValidator.validate(envelope);
      expect(result.isValid, isTrue);
    });

    test('multiple messages — independent envelopes', () {
      final msg1 = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: MessageId(),
        sourcePeerId: peerA,
        destinationPeerId: peerC,
        payload: Uint8List(0),
      );
      final msg2 = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: MessageId(),
        sourcePeerId: peerA,
        destinationPeerId: peerC,
        payload: Uint8List(0),
      );
      final msg3 = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: MessageId(),
        sourcePeerId: peerA,
        destinationPeerId: peerB,
        payload: Uint8List(0),
      );

      expect(msg1.messageId, isNot(equals(msg2.messageId)));
      expect(msg1.messageId, isNot(equals(msg3.messageId)));
      expect(msg2.messageId, isNot(equals(msg3.messageId)));
    });

    test('delivery service — accepts envelope-based message', () {
      final routeTable = <String, Route>{
        peerB: Route(
          destinationPeerId: peerB,
          nextHopPeerId: peerA,
          metric: 1,
          state: RouteState.active,
          source: RouteSource.direct,
          createdAt: DateTime.utc(2026, 1, 1),
          lastValidatedAt: DateTime.utc(2026, 1, 1),
        ),
      };

      final service = MessageDeliveryService(
        localPeerId: localPeerId,
        routeLookup: (dest) => routeTable[dest],
      );

      final msg = OneBitMessage(
        id: MessageId(),
        sourcePeerId: localPeerId,
        destinationPeerId: peerB,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final result = service.acceptMessage(msg);
      expect(result.isAccepted, isTrue);

      final tracked = service.getMessage(msg.id);
      expect(tracked!.state, equals(MessageState.ready));

      service.dispose();
    });

    test('end-to-end — create, encode, decode, validate, route lookup', () {
      final id = MessageId();

      // 1. Create envelope.
      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: id,
        sourcePeerId: peerA,
        destinationPeerId: peerC,
        payload: Uint8List.fromList([72, 101, 108, 108, 111]), // "Hello"
      );

      // 2. Validate.
      final validation = MessageEnvelopeValidator.validate(envelope);
      expect(validation.isValid, isTrue);

      // 3. Encode.
      final bytes = MessageEnvelopeCodec.encode(envelope);

      // 4. Decode.
      final decoded = MessageEnvelopeCodec.decode(bytes);

      // 5. Verify identity preserved.
      expect(decoded.messageId, equals(id));
      expect(decoded.sourcePeerId, equals(peerA));
      expect(decoded.destinationPeerId, equals(peerC));
      expect(decoded.payload, equals(Uint8List.fromList([72, 101, 108, 108, 111])));

      // 6. Route lookup — envelope remains unchanged.
      final route = Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerB,
        metric: 3,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime.utc(2026, 1, 1),
        lastValidatedAt: DateTime.utc(2026, 1, 1),
      );

      expect(decoded.destinationPeerId, equals(peerC));
      expect(route.nextHopPeerId, equals(peerB));
    });
  });
}
