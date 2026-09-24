/// I9.2 — Deterministic binary codec for message envelopes.
///
/// Provides canonical encoding and decoding of [MessageEnvelope]
/// instances. The codec is transport-agnostic — it works on raw
/// byte buffers regardless of origin.
///
/// ## Wire Format (big-endian)
///
/// ```text
/// [version: 1B]
/// [messageId: 16B]
/// [sourcePeerId: 32B]
/// [destinationPeerId: 32B]
/// [payloadLength: 4B]
/// [payload: NB]
/// ```
///
/// Total header overhead: 85 bytes.
/// Maximum total size: 85 + 4096 = 4181 bytes.
///
/// ## Determinism
///
/// The same logical envelope always produces identical bytes.
/// This property is required for future cryptographic operations.
library;

import 'dart:typed_data';

import 'package:onebit/features/message/models/message_envelope.dart';
import 'package:onebit/features/message/models/message_id.dart';

/// Size of the fixed portion of the encoded envelope (before payload).
const int envelopeHeaderSize =
    1 + // version
    messageIdByteSize + // messageId
    peerIdByteSize + // sourcePeerId
    peerIdByteSize + // destinationPeerId
    4; // payloadLength

/// Maximum encoded envelope size.
const int maxEncodedEnvelopeSize = envelopeHeaderSize + maxMessagePayloadSize;

/// Reason an envelope decode can fail.
enum EnvelopeDecodeReason {
  /// Byte buffer is shorter than the minimum header size.
  malformedEnvelope,

  /// The version field is not a supported protocol version.
  unsupportedVersion,

  /// The declared payload length does not match available bytes.
  invalidPayloadLength,

  /// The encoded envelope exceeds the maximum allowed size.
  envelopeTooLarge,

  /// The payload exceeds the maximum allowed size.
  payloadTooLarge,

  /// Source PeerId is not exactly 32 bytes.
  invalidSourcePeerId,

  /// Destination PeerId is not exactly 32 bytes.
  invalidDestinationPeerId,

  /// Trailing bytes after the declared envelope.
  trailingData,
}

/// Exception thrown when an envelope cannot be decoded.
class EnvelopeDecodeException implements Exception {
  const EnvelopeDecodeException(this.reason);

  final EnvelopeDecodeReason reason;

  @override
  String toString() => 'EnvelopeDecodeException: $reason';
}

/// Deterministic binary codec for [MessageEnvelope].
///
/// The codec is a pure utility — no state, no side effects.
/// All methods are static.
class MessageEnvelopeCodec {
  MessageEnvelopeCodec._();

  // ── Encoding ──────────────────────────────────────────────

  /// Encode a [MessageEnvelope] to its canonical binary representation.
  ///
  /// Throws [EnvelopeDecodeException] if the envelope exceeds
  /// the maximum encoded size.
  static Uint8List encode(MessageEnvelope envelope) {
    final payload = envelope.payload;
    final totalSize = envelopeHeaderSize + payload.length;

    if (totalSize > maxEncodedEnvelopeSize) {
      throw const EnvelopeDecodeException(EnvelopeDecodeReason.envelopeTooLarge);
    }

    final bytes = Uint8List(totalSize);
    var offset = 0;

    // Version (1 byte).
    bytes[offset++] = envelope.protocolVersion;

    // MessageId (16 bytes raw).
    final idBytes = envelope.messageId.toBytes();
    bytes.setAll(offset, idBytes);
    offset += messageIdByteSize;

    // Source PeerId (32 bytes raw from hex decode).
    final srcBytes = _hexDecode(envelope.sourcePeerId);
    bytes.setAll(offset, srcBytes);
    offset += peerIdByteSize;

    // Destination PeerId (32 bytes raw from hex decode).
    final dstBytes = _hexDecode(envelope.destinationPeerId);
    bytes.setAll(offset, dstBytes);
    offset += peerIdByteSize;

    // Payload length (4 bytes, big-endian uint32).
    bytes[offset++] = (payload.length >> 24) & 0xFF;
    bytes[offset++] = (payload.length >> 16) & 0xFF;
    bytes[offset++] = (payload.length >> 8) & 0xFF;
    bytes[offset++] = payload.length & 0xFF;

    // Payload.
    bytes.setAll(offset, payload);

    return bytes;
  }

  // ── Decoding ──────────────────────────────────────────────

  /// Decode a raw byte buffer into a [MessageEnvelope].
  ///
  /// Follows the parse → validate pattern. Rejects all invalid
  /// input safely — no partial envelopes are exposed.
  static MessageEnvelope decode(Uint8List bytes) {
    var offset = 0;

    // 1. Minimum size check.
    if (bytes.length < envelopeHeaderSize) {
      throw const EnvelopeDecodeException(
        EnvelopeDecodeReason.malformedEnvelope,
      );
    }

    // 2. Version.
    final version = bytes[offset++];
    if (version != messageProtocolVersion) {
      throw const EnvelopeDecodeException(
        EnvelopeDecodeReason.unsupportedVersion,
      );
    }

    // 3. MessageId (16 bytes).
    final idBytes = bytes.sublist(offset, offset + messageIdByteSize);
    offset += messageIdByteSize;

    // 4. Source PeerId (32 bytes).
    final srcBytes = bytes.sublist(offset, offset + peerIdByteSize);
    offset += peerIdByteSize;

    // 5. Destination PeerId (32 bytes).
    final dstBytes = bytes.sublist(offset, offset + peerIdByteSize);
    offset += peerIdByteSize;

    // 6. Payload length (4 bytes, big-endian uint32).
    if (offset + 4 > bytes.length) {
      throw const EnvelopeDecodeException(
        EnvelopeDecodeReason.malformedEnvelope,
      );
    }
    final payloadLength =
        (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    offset += 4;

    // 7. Validate payload length against available bytes.
    if (offset + payloadLength > bytes.length) {
      throw const EnvelopeDecodeException(
        EnvelopeDecodeReason.invalidPayloadLength,
      );
    }

    // 8. Reject trailing bytes.
    if (offset + payloadLength != bytes.length) {
      throw const EnvelopeDecodeException(
        EnvelopeDecodeReason.trailingData,
      );
    }

    // 9. Payload size limit.
    if (payloadLength > maxMessagePayloadSize) {
      throw const EnvelopeDecodeException(
        EnvelopeDecodeReason.payloadTooLarge,
      );
    }

    // 10. Total size check.
    if (bytes.length > maxEncodedEnvelopeSize) {
      throw const EnvelopeDecodeException(
        EnvelopeDecodeReason.envelopeTooLarge,
      );
    }

    // 11. Construct MessageId from raw bytes.
    final messageId = MessageId.fromBytes(Uint8List.fromList(idBytes));

    // 12. Hex-encode PeerIds.
    final sourcePeerId = _hexEncode(srcBytes);
    final destinationPeerId = _hexEncode(dstBytes);

    // 13. Extract payload.
    final payload = payloadLength > 0
        ? Uint8List.fromList(bytes.sublist(offset, offset + payloadLength))
        : Uint8List(0);

    return MessageEnvelope(
      protocolVersion: version,
      messageId: messageId,
      sourcePeerId: sourcePeerId,
      destinationPeerId: destinationPeerId,
      payload: payload,
    );
  }

  // ── Helpers ───────────────────────────────────────────────

  /// Hex-encode a byte array to a lowercase hex string.
  static String _hexEncode(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  /// Hex-decode a string to bytes.
  static Uint8List _hexDecode(String hex) {
    if (hex.length != peerIdHexLength) {
      throw const EnvelopeDecodeException(
        EnvelopeDecodeReason.invalidSourcePeerId,
      );
    }
    final bytes = Uint8List(peerIdByteSize);
    for (var i = 0; i < peerIdByteSize; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }
}
