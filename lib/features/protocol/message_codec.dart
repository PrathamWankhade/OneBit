import 'dart:convert';
import 'dart:typed_data';

/// Binary codec for serializing/deserializing OneBit messages.
///
/// Wire format (big-endian):
/// ```
/// [externalIdLen: 2 bytes][externalId: N bytes]
/// [contentLen: 2 bytes][content: N bytes]
/// [timestampMs: 8 bytes]
/// ```
///
/// Total overhead: 12 bytes. Max content: [maxContentLength] bytes (UTF-8).
class MessageCodec {
  MessageCodec._();

  /// Minimum serialized size (two 2-byte lengths + 8-byte timestamp).
  static const int minSize = 12;

  /// Maximum content length in bytes (UTF-8 encoded).
  ///
  /// This used to be 255, one packet's worth of payload, which meant a
  /// message of about 240 characters was refused outright. The frame
  /// carries a two-byte length and the transport splits a frame that
  /// outgrows one packet, so the only thing bounding it now is the
  /// envelope the frame travels inside: 4096 bytes minus this frame's
  /// own overhead (12) and a wire id, with room to spare for one that
  /// has grown to twenty digits.
  static const int maxContentLength = 4000;

  // ── Encoding ──────────────────────────────────────────────

  /// Encode a message to its binary representation.
  ///
  /// [externalMessageId] is the sender's message ID for deduplication.
  /// [content] is the UTF-8 text payload.
  /// [timestampMs] is milliseconds since epoch.
  static Uint8List encode({
    required String externalMessageId,
    required String content,
    required int timestampMs,
  }) {
    final idBytes = utf8.encode(externalMessageId);
    final contentBytes = utf8.encode(content);

    if (contentBytes.length > maxContentLength) {
      throw ArgumentError('Content too large: ${contentBytes.length} bytes');
    }

    final bytes = Uint8List(2 + idBytes.length + 2 + contentBytes.length + 8);
    var offset = 0;

    // External message ID.
    bytes[offset++] = (idBytes.length >> 8) & 0xFF;
    bytes[offset++] = idBytes.length & 0xFF;
    bytes.setAll(offset, idBytes);
    offset += idBytes.length;

    // Content.
    bytes[offset++] = (contentBytes.length >> 8) & 0xFF;
    bytes[offset++] = contentBytes.length & 0xFF;
    bytes.setAll(offset, contentBytes);
    offset += contentBytes.length;

    // Timestamp (milliseconds since epoch, big-endian int64).
    final ts = ByteData(8);
    ts.setInt64(0, timestampMs, Endian.big);
    bytes.setAll(offset, ts.buffer.asUint8List());

    return bytes;
  }

  // ── Decoding ──────────────────────────────────────────────

  /// Decode a binary message buffer.
  ///
  /// Throws [ArgumentError] if the buffer is malformed.
  static DecodedMessage decode(Uint8List bytes) {
    if (bytes.length < minSize) {
      throw ArgumentError('Message too short: ${bytes.length} bytes');
    }

    var offset = 0;

    // External message ID.
    if (offset + 2 > bytes.length) {
      throw ArgumentError('Truncated external ID length');
    }
    final idLen = (bytes[offset] << 8) | bytes[offset + 1];
    offset += 2;

    if (offset + idLen > bytes.length) {
      throw ArgumentError('Truncated external ID');
    }
    final externalId = utf8.decode(bytes.sublist(offset, offset + idLen));
    offset += idLen;

    // Content.
    if (offset + 2 > bytes.length) {
      throw ArgumentError('Truncated content length');
    }
    final contentLen = (bytes[offset] << 8) | bytes[offset + 1];
    offset += 2;

    if (offset + contentLen > bytes.length) {
      throw ArgumentError('Truncated content');
    }
    final content = utf8.decode(bytes.sublist(offset, offset + contentLen));
    offset += contentLen;

    // Timestamp.
    if (offset + 8 > bytes.length) {
      throw ArgumentError('Truncated timestamp');
    }
    final ts = ByteData(8);
    ts.buffer.asUint8List().setAll(0, bytes.sublist(offset, offset + 8));
    final timestampMs = ts.getInt64(0, Endian.big);
    offset += 8;

    // Reject trailing bytes.
    if (offset != bytes.length) {
      throw ArgumentError('Trailing bytes in message');
    }

    return DecodedMessage(
      externalMessageId: externalId,
      content: content,
      timestampMs: timestampMs,
    );
  }
}

/// Result of decoding a serialized message.
class DecodedMessage {
  const DecodedMessage({
    required this.externalMessageId,
    required this.content,
    required this.timestampMs,
  });

  final String externalMessageId;
  final String content;
  final int timestampMs;

  DateTime get timestamp =>
      DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true);
}
