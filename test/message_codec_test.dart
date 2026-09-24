import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/protocol/message_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessageCodec', () {
    group('encode', () {
      test('produces deterministic output', () {
        final a = MessageCodec.encode(
          externalMessageId: 'm_1',
          content: 'Hello',
          timestampMs: 1700000000000,
        );
        final b = MessageCodec.encode(
          externalMessageId: 'm_1',
          content: 'Hello',
          timestampMs: 1700000000000,
        );
        expect(a, equals(b));
      });

      test('empty content produces valid packet', () {
        final bytes = MessageCodec.encode(
          externalMessageId: 'm_1',
          content: '',
          timestampMs: 0,
        );
        expect(bytes.length, greaterThanOrEqualTo(MessageCodec.minSize));
      });

      test('UTF-8 content is preserved', () {
        const content = 'Hello OneBit';
        final bytes = MessageCodec.encode(
          externalMessageId: 'm_1',
          content: content,
          timestampMs: 1000,
        );
        final decoded = MessageCodec.decode(bytes);
        expect(decoded.content, content);
      });

      test('Unicode content is preserved', () {
        const content = 'नमस्ते OneBit 🌐';
        final bytes = MessageCodec.encode(
          externalMessageId: 'm_42',
          content: content,
          timestampMs: 2000,
        );
        final decoded = MessageCodec.decode(bytes);
        expect(decoded.content, content);
      });

      test('Japanese content is preserved', () {
        const content = 'こんにちは世界';
        final bytes = MessageCodec.encode(
          externalMessageId: 'm_jp',
          content: content,
          timestampMs: 3000,
        );
        final decoded = MessageCodec.decode(bytes);
        expect(decoded.content, content);
      });

      test('Marathi content is preserved', () {
        const content = 'मराठी संदेश';
        final bytes = MessageCodec.encode(
          externalMessageId: 'm_mr',
          content: content,
          timestampMs: 4000,
        );
        final decoded = MessageCodec.decode(bytes);
        expect(decoded.content, content);
      });

      test('rejects content exceeding max length', () {
        final largeContent = 'A' * (MessageCodec.maxContentLength + 1);
        expect(
          () => MessageCodec.encode(
            externalMessageId: 'm_1',
            content: largeContent,
            timestampMs: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('accepts content at max length', () {
        final maxContent = 'B' * MessageCodec.maxContentLength;
        final bytes = MessageCodec.encode(
          externalMessageId: 'm_1',
          content: maxContent,
          timestampMs: 0,
        );
        final decoded = MessageCodec.decode(bytes);
        expect(decoded.content, maxContent);
      });
    });

    group('decode', () {
      test('round-trip basic message', () {
        final original = MessageCodec.encode(
          externalMessageId: 'm_100',
          content: 'Hello OneBit',
          timestampMs: 1700000000000,
        );
        final decoded = MessageCodec.decode(original);

        expect(decoded.externalMessageId, 'm_100');
        expect(decoded.content, 'Hello OneBit');
        expect(decoded.timestampMs, 1700000000000);
      });

      test('round-trip empty content', () {
        final original = MessageCodec.encode(
          externalMessageId: 'm_empty',
          content: '',
          timestampMs: 0,
        );
        final decoded = MessageCodec.decode(original);

        expect(decoded.externalMessageId, 'm_empty');
        expect(decoded.content, '');
        expect(decoded.timestampMs, 0);
      });

      test('round-trip Unicode', () {
        const content = 'नमस्ते OneBit 🌐';
        final original = MessageCodec.encode(
          externalMessageId: 'm_unicode',
          content: content,
          timestampMs: 999,
        );
        final decoded = MessageCodec.decode(original);

        expect(decoded.externalMessageId, 'm_unicode');
        expect(decoded.content, content);
        expect(decoded.timestampMs, 999);
      });

      test('round-trip maximum valid content', () {
        final maxContent = 'X' * MessageCodec.maxContentLength;
        final original = MessageCodec.encode(
          externalMessageId: 'm_max',
          content: maxContent,
          timestampMs: 12345,
        );
        final decoded = MessageCodec.decode(original);

        expect(decoded.content, maxContent);
      });

      test('timestamp converts to DateTime correctly', () {
        final ms = DateTime.utc(2024, 1, 15, 12, 30, 45).millisecondsSinceEpoch;
        final original = MessageCodec.encode(
          externalMessageId: 'm_ts',
          content: 'test',
          timestampMs: ms,
        );
        final decoded = MessageCodec.decode(original);

        expect(decoded.timestamp, DateTime.utc(2024, 1, 15, 12, 30, 45));
      });

      test('rejects buffer too short', () {
        expect(
          () => MessageCodec.decode(Uint8List(5)),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects truncated external ID', () {
        // Length says 10 but buffer is too short.
        final bytes = Uint8List.fromList([
          0x00, 0x0A, // external ID length = 10
          0x01, 0x02, // only 2 bytes of ID
        ]);
        expect(
          () => MessageCodec.decode(bytes),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects truncated content', () {
        final bytes = Uint8List.fromList([
          0x00, 0x02, // external ID length = 2
          0x41, 0x42, // "AB"
          0x00, 0x0A, // content length = 10
          0x01, 0x02, // only 2 bytes of content
        ]);
        expect(
          () => MessageCodec.decode(bytes),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects truncated timestamp', () {
        final bytes = Uint8List.fromList([
          0x00, 0x02, // external ID length = 2
          0x41, 0x42, // "AB"
          0x00, 0x02, // content length = 2
          0x43, 0x44, // "CD"
          0x00, 0x01, 0x02, // only 3 bytes of timestamp (need 8)
        ]);
        expect(
          () => MessageCodec.decode(bytes),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects trailing bytes', () {
        final original = MessageCodec.encode(
          externalMessageId: 'm_1',
          content: 'Hi',
          timestampMs: 0,
        );
        // Append an extra byte.
        final withTrailing = Uint8List(original.length + 1);
        withTrailing.setAll(0, original);
        withTrailing[original.length] = 0xFF;

        expect(
          () => MessageCodec.decode(withTrailing),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('all packetId values round-trip', () {
      test('external message IDs round-trip', () {
        final ids = ['m_0', 'm_1', 'm_42', 'm_255', 'm_999', 'external_id'];
        for (final id in ids) {
          final bytes = MessageCodec.encode(
            externalMessageId: id,
            content: 'test',
            timestampMs: 0,
          );
          final decoded = MessageCodec.decode(bytes);
          expect(decoded.externalMessageId, id, reason: 'Failed for ID: $id');
        }
      });
    });
  });
}
