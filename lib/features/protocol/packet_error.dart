/// Reasons a packet decode can fail.
enum PacketDecodeReason {
  /// Byte buffer is shorter than the minimum header size.
  malformedPacket,

  /// The version field is not the supported protocol version.
  unsupportedVersion,

  /// The type field is not a recognized packet type.
  unsupportedType,

  /// The flags field contains reserved or unknown bits.
  invalidFlags,

  /// The declared payload length does not match available bytes.
  invalidLength,

  /// The encoded packet exceeds the maximum allowed size.
  packetTooLarge,
}

/// Exception thrown when a packet cannot be decoded.
class PacketDecodeException implements Exception {
  const PacketDecodeException(this.reason);

  final PacketDecodeReason reason;

  @override
  String toString() => 'PacketDecodeException: $reason';
}
