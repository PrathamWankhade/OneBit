import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/protocol/message_codec.dart';
import 'package:onebit/features/protocol/receipt_tag.dart';

/// A receipt has to do two contradictory things at once: be an ordinary
/// message frame so that our own receiver handles it down the usual
/// road, and be impossible for a peer that predates receipts to read.
/// These pin both halves down.
void main() {
  group('ReceiptTag content', () {
    test('a delivered receipt comes back with its ids', () {
      final content = ReceiptTag.encode(
        kind: ReceiptKind.delivered,
        messageIds: ['m_1'],
      );

      expect(content, '[receipt:delivered:m_1]');
      final parsed = ReceiptTag.parse(content);
      expect(parsed!.kind, ReceiptKind.delivered);
      expect(parsed.messageIds, ['m_1']);
    });

    test('several messages are acknowledged in one go', () {
      final parsed = ReceiptTag.parse(
        ReceiptTag.encode(
          kind: ReceiptKind.read,
          messageIds: ['m_7', 'm_8', 'm_9'],
        ),
      );

      expect(parsed!.kind, ReceiptKind.read);
      expect(parsed.messageIds, ['m_7', 'm_8', 'm_9']);
    });

    test('a message that is not a receipt is not mistaken for one', () {
      expect(ReceiptTag.parse('hello'), isNull);
      expect(ReceiptTag.parse('[reply:Zm9v]hi'), isNull);
      expect(ReceiptTag.parse('[image:photo.png]'), isNull);
      expect(ReceiptTag.parse('[receipt:delivered:m_1'), isNull);
      expect(ReceiptTag.parse('[receipt:someday:m_1]'), isNull);
      expect(ReceiptTag.parse('[receipt:read:]'), isNull);
    });
  });

  group('ReceiptTag frames', () {
    test('a frame goes out and comes back', () {
      final frame = ReceiptTag.encodeFrame(
        kind: ReceiptKind.delivered,
        messageIds: ['m_42'],
        timestampMs: 1700000000000,
      );

      final receipt = ReceiptTag.decodeFrame(frame);
      expect(receipt!.kind, ReceiptKind.delivered);
      expect(receipt.messageIds, ['m_42']);
    });

    test(
        'a peer built before receipts drops the frame instead of '
        'printing it', () {
      final frame = ReceiptTag.encodeFrame(
        kind: ReceiptKind.read,
        messageIds: ['m_1'],
        timestampMs: 1,
      );

      // The whole reason the frame ends in an extra byte: a strict
      // decode finds one byte too many and refuses. Nothing gets as far
      // as persisting it, so it never becomes chat text.
      expect(
        () => MessageCodec.decode(frame),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Trailing bytes'),
        )),
      );
      expect(ReceiptTag.decodeFrame(frame), isNotNull);
    });

    test('an ordinary message is left for the message decoder', () {
      final frame = MessageCodec.encode(
        externalMessageId: 'm_1',
        content: 'hello',
        timestampMs: 1,
      );

      expect(ReceiptTag.decodeFrame(frame), isNull);
      expect(MessageCodec.decode(frame).content, 'hello');
    });

    test('a message whose timestamp ends in the marker stays a message',
        () {
      // One byte of luck away from looking like a receipt: the low byte
      // of the timestamp is 0x1E, so the frame ends in the byte a
      // receipt ends in. Truncating it does not produce a decodable
      // frame, and that is what keeps the two apart.
      final frame = MessageCodec.encode(
        externalMessageId: 'm_1',
        content: 'hello',
        timestampMs: 256 + ReceiptTag.marker,
      );

      expect(frame.last, ReceiptTag.marker);
      expect(ReceiptTag.decodeFrame(frame), isNull);
      expect(MessageCodec.decode(frame).content, 'hello');
    });

    test('an empty frame carries no receipt', () {
      expect(ReceiptTag.decodeFrame(Uint8List(0)), isNull);
    });
  });
}
