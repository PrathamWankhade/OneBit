import 'dart:typed_data';

import 'package:onebit/features/protocol/onebit_packet.dart';
import 'package:onebit/features/protocol/packet_error.dart';

/// Encoder / decoder for the OneBit binary packet format.
///
/// The codec is transport-agnostic — it works on raw byte buffers
/// regardless of whether they arrive over BLE, a socket, or a test stub.
class PacketCodec {
  PacketCodec._();

  // ── Encoding ──────────────────────────────────────────────

  /// Encode a [packet] to its binary representation.
  ///
  /// Throws [PacketDecodeException] with [PacketDecodeReason.packetTooLarge]
  /// if the resulting packet would exceed [PacketConstants.maxPacketSize].
  static Uint8List encode(OneBitPacket packet) {
    final totalSize = packet.totalSize;
    if (totalSize > PacketConstants.maxPacketSize) {
      throw const PacketDecodeException(PacketDecodeReason.packetTooLarge);
    }

    final bytes = Uint8List(totalSize);
    var offset = 0;

    // Header — each field is one byte, big-endian.
    bytes[offset++] = packet.version;
    bytes[offset++] = packet.type;
    bytes[offset++] = packet.flags;
    bytes[offset++] = packet.packetId;
    bytes[offset++] = packet.payloadLength;

    // Payload.
    bytes.setAll(offset, packet.payload);

    return bytes;
  }

  // ── Decoding ──────────────────────────────────────────────

  /// Decode a raw byte buffer into a [OneBitPacket].
  ///
  /// Throws [PacketDecodeException] for any structural problem:
  /// - Too short for a header
  /// - Unsupported version
  /// - Unknown packet type
  /// - Reserved flags set
  /// - Declared payload length mismatch
  /// - Trailing bytes after the declared packet
  /// - Total size exceeds maximum
  static OneBitPacket decode(Uint8List bytes) {
    // 1. Minimum size check.
    if (bytes.length < PacketConstants.headerSize) {
      throw const PacketDecodeException(PacketDecodeReason.malformedPacket);
    }

    var offset = 0;

    // 2. Read header fields.
    final version = bytes[offset++];
    final type = bytes[offset++];
    final flags = bytes[offset++];
    final packetId = bytes[offset++];
    final payloadLength = bytes[offset++];

    // 3. Validate version.
    if (version != PacketConstants.version) {
      throw const PacketDecodeException(PacketDecodeReason.unsupportedVersion);
    }

    // 4. Validate type.
    if (!PacketType.isValid(type)) {
      throw const PacketDecodeException(PacketDecodeReason.unsupportedType);
    }

    // 5. Validate flags (only 0 is allowed in v1).
    if (flags != 0) {
      throw const PacketDecodeException(PacketDecodeReason.invalidFlags);
    }

    // 6. Validate declared length against available bytes.
    if (offset + payloadLength > bytes.length) {
      throw const PacketDecodeException(PacketDecodeReason.invalidLength);
    }

    // 7. Reject trailing bytes.
    if (offset + payloadLength != bytes.length) {
      throw const PacketDecodeException(PacketDecodeReason.invalidLength);
    }

    // 8. Total size check.
    if (bytes.length > PacketConstants.maxPacketSize) {
      throw const PacketDecodeException(PacketDecodeReason.packetTooLarge);
    }

    // 9. Extract payload.
    final List<int> payload =
        payloadLength > 0 ? bytes.sublist(offset, offset + payloadLength) : [];

    return OneBitPacket(
      type: type,
      packetId: packetId,
      flags: flags,
      payload: payload,
    );
  }
}
