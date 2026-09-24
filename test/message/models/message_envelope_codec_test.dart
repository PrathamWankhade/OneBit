import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/message/models/message_envelope.dart';
import 'package:onebit/features/message/models/message_envelope_codec.dart';
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
    MessageId? id,
    String? src,
    String? dst,
    List<int>? payload,
  }) {
    return MessageEnvelope(
      protocolVersion: messageProtocolVersion,
      messageId: id ?? testMsgId,
      sourcePeerId: src ?? testSource,
      destinationPeerId: dst ?? testDestination,
      payload: Uint8List.fromList(payload ?? [1, 2, 3]),
    );
  }

  group('MessageEnvelopeCodec', () {
    group('encode', () {
      test('produces correct size', () {
        final envelope = makeEnvelope(payload: List.filled(100, 0xAB));
        final bytes = MessageEnvelopeCodec.encode(envelope);

        // header (85) + payload (100) = 185
        expect(bytes.length, equals(185));
      });

      test('first byte is protocol version', () {
        final envelope = makeEnvelope();
        final bytes = MessageEnvelopeCodec.encode(envelope);

        expect(bytes[0], equals(messageProtocolVersion));
      });

      test('messageId occupies bytes 1..16', () {
        final envelope = makeEnvelope();
        final bytes = MessageEnvelopeCodec.encode(envelope);
        final idBytes = envelope.messageId.toBytes();

        expect(bytes.sublist(1, 17), equals(idBytes));
      });

      test('payload length is big-endian uint32 at offset 81', () {
        final envelope = makeEnvelope(payload: List.filled(256, 0xFF));
        final bytes = MessageEnvelopeCodec.encode(envelope);

        // Offset 81-84: payload length (256 = 0x00000100)
        expect(bytes[81], equals(0x00));
        expect(bytes[82], equals(0x00));
        expect(bytes[83], equals(0x01));
        expect(bytes[84], equals(0x00));
      });
    });

    group('decode', () {
      test('decodes valid envelope', () {
        final envelope = makeEnvelope();
        final bytes = MessageEnvelopeCodec.encode(envelope);
        final decoded = MessageEnvelopeCodec.decode(bytes);

        expect(decoded.protocolVersion, equals(envelope.protocolVersion));
        expect(decoded.messageId, equals(envelope.messageId));
        expect(decoded.sourcePeerId, equals(envelope.sourcePeerId));
        expect(decoded.destinationPeerId, equals(envelope.destinationPeerId));
        expect(decoded.payload, equals(envelope.payload));
      });

      test('rejects empty bytes', () {
        expect(
          () => MessageEnvelopeCodec.decode(Uint8List(0)),
          throwsA(isA<EnvelopeDecodeException>()),
        );
      });

      test('rejects truncated header', () {
        expect(
          () => MessageEnvelopeCodec.decode(Uint8List(10)),
          throwsA(isA<EnvelopeDecodeException>()),
        );
      });

      test('rejects unsupported version', () {
        final envelope = makeEnvelope();
        final bytes = MessageEnvelopeCodec.encode(envelope);
        bytes[0] = 99; // invalid version

        expect(
          () => MessageEnvelopeCodec.decode(bytes),
          throwsA(isA<EnvelopeDecodeException>()),
        );
      });

      test('rejects truncated payload', () {
        final envelope = makeEnvelope(payload: List.filled(100, 0));
        final bytes = MessageEnvelopeCodec.encode(envelope);
        // Truncate to header only — payload length says 100 but no bytes.
        final truncated = Uint8List.fromList(bytes.sublist(0, 85));

        expect(
          () => MessageEnvelopeCodec.decode(truncated),
          throwsA(isA<EnvelopeDecodeException>()),
        );
      });

      test('rejects trailing data', () {
        final envelope = makeEnvelope();
        final bytes = MessageEnvelopeCodec.encode(envelope);
        final withTrailing = Uint8List(bytes.length + 5);
        withTrailing.setAll(0, bytes);

        expect(
          () => MessageEnvelopeCodec.decode(withTrailing),
          throwsA(isA<EnvelopeDecodeException>()),
        );
      });

      test('rejects oversized payload', () {
        // Build bytes manually with payload length exceeding max.
        // header (85) + (maxMessagePayloadSize + 1) would exceed maxEncodedEnvelopeSize.
        // The encode method rejects this, so we test via decode with
        // manually crafted bytes that have a valid header but oversized
        // payload length.
        final bytes = Uint8List(envelopeHeaderSize);
        bytes[0] = messageProtocolVersion;
        // Set a valid MessageId (version 4, variant 10xx).
        bytes[1] = 0x55; bytes[2] = 0x0E; bytes[3] = 0x84; bytes[4] = 0x00;
        bytes[5] = 0xE2; bytes[6] = 0x9B; bytes[7] = 0x41; bytes[8] = 0xD4;
        bytes[9] = 0xA7; bytes[10] = 0x16; bytes[11] = 0x44;
        bytes[12] = 0x66; bytes[13] = 0x55; bytes[14] = 0x44; bytes[15] = 0x00;
        bytes[16] = 0x00;
        // Version bits at offset 6: must be 0x4x.
        bytes[6] = 0x41;
        // Variant bits at offset 8: must be 0x8x or 0x9x or 0xAx or 0xBx.
        bytes[8] = 0x80;
        // Source and destination PeerIds: fill with valid hex (32 bytes each).
        for (var i = 17; i < 49; i++) {
          bytes[i] = 0xAA;
        }
        for (var i = 49; i < 81; i++) {
          bytes[i] = 0xBB;
        }
        // Payload length at 81-84: set to maxMessagePayloadSize + 1 = 4097.
        const oversized = maxMessagePayloadSize + 1;
        bytes[81] = (oversized >> 24) & 0xFF;
        bytes[82] = (oversized >> 16) & 0xFF;
        bytes[83] = (oversized >> 8) & 0xFF;
        bytes[84] = oversized & 0xFF;

        expect(
          () => MessageEnvelopeCodec.decode(bytes),
          throwsA(isA<EnvelopeDecodeException>()),
        );
      });
    });

    group('round trip', () {
      test('encode → decode preserves all fields', () {
        final original = makeEnvelope();
        final bytes = MessageEnvelopeCodec.encode(original);
        final restored = MessageEnvelopeCodec.decode(bytes);

        expect(restored.protocolVersion, equals(original.protocolVersion));
        expect(restored.messageId, equals(original.messageId));
        expect(restored.sourcePeerId, equals(original.sourcePeerId));
        expect(restored.destinationPeerId, equals(original.destinationPeerId));
        expect(restored.payload, equals(original.payload));
      });

      test('encode → decode preserves empty payload', () {
        final original = makeEnvelope(payload: []);
        final bytes = MessageEnvelopeCodec.encode(original);
        final restored = MessageEnvelopeCodec.decode(bytes);

        expect(restored.payload.length, equals(0));
      });

      test('encode → decode preserves max payload', () {
        final original = makeEnvelope(
          payload: List.filled(maxMessagePayloadSize, 0xAB),
        );
        final bytes = MessageEnvelopeCodec.encode(original);
        final restored = MessageEnvelopeCodec.decode(bytes);

        expect(restored.payload.length, equals(maxMessagePayloadSize));
      });
    });

    group('determinism', () {
      test('encode produces identical bytes for same envelope', () {
        final envelope = makeEnvelope();
        final bytes1 = MessageEnvelopeCodec.encode(envelope);
        final bytes2 = MessageEnvelopeCodec.encode(envelope);

        expect(bytes1, equals(bytes2));
      });

      test('encode is independent of memory address', () {
        final id = MessageId();
        final e1 = makeEnvelope(id: id);
        final e2 = makeEnvelope(id: id);
        final b1 = MessageEnvelopeCodec.encode(e1);
        final b2 = MessageEnvelopeCodec.encode(e2);

        expect(b1, equals(b2));
      });
    });

    group('malformed input', () {
      test('rejects single byte', () {
        expect(
          () => MessageEnvelopeCodec.decode(Uint8List(1)),
          throwsA(isA<EnvelopeDecodeException>()),
        );
      });

      test('rejects header-only with zero payload length', () {
        // Valid header structure but with a valid MessageId.
        final bytes = Uint8List(envelopeHeaderSize);
        bytes[0] = messageProtocolVersion;
        // Set valid UUID v4 bytes for messageId (offset 1-16).
        bytes[1] = 0x55; bytes[2] = 0x0E; bytes[3] = 0x84; bytes[4] = 0x00;
        bytes[5] = 0xE2; bytes[6] = 0x9B;
        bytes[7] = 0x41; // version nibble will be set below
        bytes[8] = 0xD4; bytes[9] = 0xA7; bytes[10] = 0x16;
        bytes[11] = 0x44; bytes[12] = 0x66; bytes[13] = 0x55;
        bytes[14] = 0x44; bytes[15] = 0x00; bytes[16] = 0x00;
        // Fix version bits: byte 6 must have high nibble = 4.
        bytes[6] = 0x41;
        // Fix variant bits: byte 8 must have high 2 bits = 10.
        bytes[8] = 0x80;
        // Source PeerId (32 bytes of valid hex).
        for (var i = 17; i < 49; i++) {
          bytes[i] = 0xAA;
        }
        // Destination PeerId (32 bytes of valid hex).
        for (var i = 49; i < 81; i++) {
          bytes[i] = 0xBB;
        }
        // Payload length at 81-84: already 0 from initialization.

        final decoded = MessageEnvelopeCodec.decode(bytes);
        expect(decoded.payload.length, equals(0));
      });
    });
  });
}
