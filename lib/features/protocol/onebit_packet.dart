/// OneBit protocol constants.
///
/// Binary format (big-endian / network byte order):
/// ```
/// ┌─────────┬────────┬────────┬───────────┬────────┬─────────┐
/// │ Version │  Type  │ Flags  │ Packet ID │ Length  │ Payload │
/// │ 1 byte  │ 1 byte │ 1 byte │  1 byte   │ 1 byte │ N bytes │
/// └─────────┴────────┴────────┴───────────┴────────┴─────────┘
/// ```
class PacketConstants {
  PacketConstants._();

  /// Protocol version carried in every packet.
  static const int version = 1;

  /// Header size in bytes (5 fields × 1 byte each).
  static const int headerSize = 5;

  /// Maximum allowed total packet size (header + payload).
  ///
  /// 260 bytes = 5-byte header + 255-byte max payload.
  /// The 1-byte length field limits payload to 255 bytes.
  /// This stays well within a single BLE GATT write
  /// (typical MTU ≥ 23, often negotiated to 185+).
  static const int maxPacketSize = 260;

  /// Maximum payload size.
  static const int maxPayloadSize = maxPacketSize - headerSize;
}

/// Known packet types.
///
/// [test] is for I3.4 validation. [message] is the first real
/// application packet type, introduced in I3.5.
class PacketType {
  PacketType._();

  static const int test = 0x01;
  static const int message = 0x02;
  static const int topologyAdvertisement = 0x03;

  /// Check whether [type] is a known packet type for the current version.
  static bool isValid(int type) =>
      type == test || type == message || type == topologyAdvertisement;
}

/// A single OneBit protocol packet.
///
/// Immutable — once created the fields never change.
class OneBitPacket {
  const OneBitPacket({
    required this.type,
    required this.packetId,
    this.flags = 0,
    this.payload = const [],
  });

  /// Protocol version (currently always [PacketConstants.version]).
  int get version => PacketConstants.version;

  /// Packet type (see [PacketType]).
  final int type;

  /// Reserved flags field (currently must be 0).
  final int flags;

  /// Protocol-level packet identifier (distinct from I3.3 transfer ID).
  final int packetId;

  /// Raw payload bytes.
  final List<int> payload;

  /// Number of payload bytes.
  int get payloadLength => payload.length;

  /// Total encoded size (header + payload).
  int get totalSize => PacketConstants.headerSize + payloadLength;

  /// Convenience: interpret payload as a UTF-8 string.
  String get payloadAsUtf8 => String.fromCharCodes(payload);

  @override
  String toString() =>
      'OneBitPacket(v=$version, type=0x${type.toRadixString(16).padLeft(2, '0')}, '
      'flags=$flags, id=$packetId, len=$payloadLength)';
}
