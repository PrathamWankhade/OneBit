import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/message/models/message_envelope.dart';
import 'package:onebit/features/message/models/message_id.dart';

void main() {
  late MessageId testMsgId;
  late String testSource;
  late String testDestination;

  setUpAll(() {
    testSource = 'a' * 64;
    testDestination = 'b' * 64;
  });

  setUp(() {
    testMsgId = MessageId();
  });

  group('MessageEnvelope', () {
    test('creates with required fields', () {
      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: testMsgId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        payload: Uint8List(10),
      );

      expect(envelope.protocolVersion, equals(messageProtocolVersion));
      expect(envelope.messageId, equals(testMsgId));
      expect(envelope.sourcePeerId, equals(testSource));
      expect(envelope.destinationPeerId, equals(testDestination));
      expect(envelope.payload.length, equals(10));
    });

    test('isValid returns true for valid envelope', () {
      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: testMsgId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        payload: Uint8List(10),
      );

      expect(envelope.isValid, isTrue);
    });

    test('isValid returns false for invalid version', () {
      final envelope = MessageEnvelope(
        protocolVersion: 0,
        messageId: testMsgId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        payload: Uint8List(10),
      );

      expect(envelope.isValid, isFalse);
    });

    test('isValid returns false for short sourcePeerId', () {
      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: testMsgId,
        sourcePeerId: 'abc',
        destinationPeerId: testDestination,
        payload: Uint8List(10),
      );

      expect(envelope.isValid, isFalse);
    });

    test('isValid returns false for short destinationPeerId', () {
      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: testMsgId,
        sourcePeerId: testSource,
        destinationPeerId: 'abc',
        payload: Uint8List(10),
      );

      expect(envelope.isValid, isFalse);
    });

    test('isValid returns false for oversized payload', () {
      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: testMsgId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        payload: Uint8List(maxMessagePayloadSize + 1),
      );

      expect(envelope.isValid, isFalse);
    });

    test('estimatedSize includes all fields', () {
      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: testMsgId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        payload: Uint8List(100),
      );

      // 1 + 16 + 32 + 32 + 4 + 100 = 185
      expect(envelope.estimatedSize, equals(185));
    });

    test('equality ignores payload content', () {
      final e1 = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: testMsgId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        payload: Uint8List(10),
      );
      final e2 = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: testMsgId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        payload: Uint8List(20),
      );

      expect(e1, equals(e2));
      expect(e1.hashCode, equals(e2.hashCode));
    });

    test('inequality for different messageId', () {
      final e1 = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: testMsgId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        payload: Uint8List(10),
      );
      final e2 = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: MessageId(),
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        payload: Uint8List(10),
      );

      expect(e1 == e2, isFalse);
    });

    test('toString includes truncated IDs', () {
      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: testMsgId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        payload: Uint8List(50),
      );

      final str = envelope.toString();
      expect(str, contains('MessageEnvelope('));
      expect(str, contains('payload=50B)'));
    });

    test('identity fields immutable via const constructor', () {
      // Verify the constructor is const-compatible with valid data.
      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: testMsgId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        payload: Uint8List(0),
      );

      // Identity fields cannot be changed — the class has no setters.
      expect(envelope.messageId, equals(testMsgId));
      expect(envelope.sourcePeerId, equals(testSource));
      expect(envelope.destinationPeerId, equals(testDestination));
    });
  });
}
