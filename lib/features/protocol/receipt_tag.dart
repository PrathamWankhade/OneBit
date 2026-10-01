import 'dart:typed_data';

import 'package:onebit/features/protocol/message_codec.dart';

/// What a peer is telling you about a message you sent.
enum ReceiptKind {
  /// It left the sender and reached the peer's own handset.
  delivered,

  /// The peer's owner opened the conversation it landed in.
  read,
}

/// A receipt travels as an ordinary message frame carrying a marker in
/// its content, which is the same road an attachment and a reply take.
///
/// The frame ends with [marker]. That extra byte is the whole point:
/// a peer built before receipts exist runs a strict decode, finds one
/// byte more than the frame accounts for, throws, and drops the packet.
/// Without it, `[…]` would appear in somebody's conversation as chat
/// text — a receipt nobody asked to see, dressed as a message.
class ReceiptTag {
  ReceiptTag._();

  /// Marker that opens a receipt.
  static const String prefix = '[receipt:';

  /// Trailing byte that makes an older peer drop the frame outright.
  ///
  /// 0x1E, the ASCII record separator. An ordinary frame can end in it
  /// by chance — it is the low byte of a timestamp — which is why
  /// [decodeFrame] falls back to `null` rather than trusting the byte:
  /// the truncated frame fails to decode either way.
  static const int marker = 0x1E;

  /// The frame id a receipt carries. It is never stored, so it has no
  /// row to deduplicate against.
  static const String frameId = 'receipt';

  /// Build the content that goes on the wire: everything in [messageIds]
  /// now counts as [kind] on the far side.
  static String encode({
    required ReceiptKind kind,
    required List<String> messageIds,
  }) {
    final ids = messageIds.join(',');
    return '$prefix${kind.name}:$ids]';
  }

  /// The kind and the ids in [content], or `null` when it is not a
  /// receipt — including when it names no message at all.
  static ({ReceiptKind kind, List<String> messageIds})? parse(
    String content,
  ) {
    if (!content.startsWith(prefix) || !content.endsWith(']')) return null;

    final inner = content.substring(prefix.length, content.length - 1);
    final colon = inner.indexOf(':');
    if (colon <= 0) return null;

    final kind = switch (inner.substring(0, colon)) {
      'delivered' => ReceiptKind.delivered,
      'read' => ReceiptKind.read,
      _ => null,
    };
    if (kind == null) return null;

    final messageIds = inner
        .substring(colon + 1)
        .split(',')
        .where((id) => id.isNotEmpty)
        .toList();
    if (messageIds.isEmpty) return null;

    return (kind: kind, messageIds: messageIds);
  }

  /// Decode a receipt frame, or `null` when [bytes] is an ordinary
  /// message and should be handed to [MessageCodec.decode] untouched.
  static ({ReceiptKind kind, List<String> messageIds})? decodeFrame(
    Uint8List bytes,
  ) {
    if (bytes.isEmpty || bytes[bytes.length - 1] != marker) return null;
    try {
      final frame = MessageCodec.decode(bytes.sublist(0, bytes.length - 1));
      return parse(frame.content);
    } catch (_) {
      // A plain message whose timestamp happened to end in the marker.
      return null;
    }
  }

  /// Build a complete receipt frame for [messageIds].
  static Uint8List encodeFrame({
    required ReceiptKind kind,
    required List<String> messageIds,
    required int timestampMs,
  }) {
    final frame = MessageCodec.encode(
      externalMessageId: frameId,
      content: encode(kind: kind, messageIds: messageIds),
      timestampMs: timestampMs,
    );

    final out = Uint8List(frame.length + 1);
    out.setAll(0, frame);
    out[frame.length] = marker;
    return out;
  }
}
