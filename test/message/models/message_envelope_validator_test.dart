import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/message/models/message_envelope.dart';
import 'package:onebit/features/message/models/message_envelope_validator.dart';
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

  MessageEnvelope makeEnvelope({
    int? version,
    String? src,
    String? dst,
    List<int>? payload,
  }) {
    return MessageEnvelope(
      protocolVersion: version ?? messageProtocolVersion,
      messageId: testMsgId,
      sourcePeerId: src ?? testSource,
      destinationPeerId: dst ?? testDestination,
      payload: Uint8List.fromList(payload ?? [1, 2, 3]),
    );
  }

  group('MessageEnvelopeValidator', () {
    test('valid envelope passes', () {
      final result = MessageEnvelopeValidator.validate(makeEnvelope());
      expect(result.isValid, isTrue);
      expect(result.reason, isNull);
    });

    test('rejects unsupported version', () {
      final result = MessageEnvelopeValidator.validate(
        makeEnvelope(version: 0),
      );
      expect(result.isValid, isFalse);
      expect(result.reason, equals(EnvelopeValidationReason.unsupportedVersion));
    });

    test('rejects short source PeerId', () {
      final result = MessageEnvelopeValidator.validate(
        makeEnvelope(src: 'abc'),
      );
      expect(result.isValid, isFalse);
      expect(
        result.reason,
        equals(EnvelopeValidationReason.invalidSourcePeerId),
      );
    });

    test('rejects long source PeerId', () {
      final result = MessageEnvelopeValidator.validate(
        makeEnvelope(src: 'a' * 65),
      );
      expect(result.isValid, isFalse);
      expect(
        result.reason,
        equals(EnvelopeValidationReason.invalidSourcePeerId),
      );
    });

    test('rejects short destination PeerId', () {
      final result = MessageEnvelopeValidator.validate(
        makeEnvelope(dst: 'abc'),
      );
      expect(result.isValid, isFalse);
      expect(
        result.reason,
        equals(EnvelopeValidationReason.invalidDestinationPeerId),
      );
    });

    test('rejects non-hex source PeerId', () {
      final result = MessageEnvelopeValidator.validate(
        makeEnvelope(src: 'g' * 64),
      );
      expect(result.isValid, isFalse);
      expect(
        result.reason,
        equals(EnvelopeValidationReason.malformedSourcePeerId),
      );
    });

    test('rejects non-hex destination PeerId', () {
      final result = MessageEnvelopeValidator.validate(
        makeEnvelope(dst: 'g' * 64),
      );
      expect(result.isValid, isFalse);
      expect(
        result.reason,
        equals(EnvelopeValidationReason.malformedDestinationPeerId),
      );
    });

    test('rejects oversized payload', () {
      final result = MessageEnvelopeValidator.validate(
        makeEnvelope(payload: List.filled(maxMessagePayloadSize + 1, 0)),
      );
      expect(result.isValid, isFalse);
      expect(result.reason, equals(EnvelopeValidationReason.payloadTooLarge));
    });

    test('accepts empty payload', () {
      final result = MessageEnvelopeValidator.validate(
        makeEnvelope(payload: []),
      );
      expect(result.isValid, isTrue);
    });

    test('accepts max-size payload', () {
      final result = MessageEnvelopeValidator.validate(
        makeEnvelope(payload: List.filled(maxMessagePayloadSize, 0)),
      );
      expect(result.isValid, isTrue);
    });

    test('toString shows valid', () {
      final result = MessageEnvelopeValidator.validate(makeEnvelope());
      expect(result.toString(), contains('valid'));
    });

    test('toString shows invalid reason', () {
      final result = MessageEnvelopeValidator.validate(
        makeEnvelope(version: 0),
      );
      expect(result.toString(), contains('unsupportedVersion'));
    });
  });
}
