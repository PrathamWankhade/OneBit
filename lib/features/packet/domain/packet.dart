import 'packet_header.dart';
import 'packet_id.dart';
import 'packet_payload.dart';

/// An immutable logical packet: header + payload + optional signature.
///
/// The packet layer's only message carrier. Serialization, fragmentation
/// and compression happen *around* this value; the object itself is never
/// mutated — copies are created at the factory/fragment boundaries.
final class Packet {
  const Packet({
    required this.header,
    required this.payload,
    this.signature = const [],
  });

  /// The full header (identity, routing hints, fragment position).
  final PacketHeader header;

  /// The payload plus its declared type.
  final PacketPayload payload;

  /// Signature bytes over the canonical pre-signature frame. Empty when
  /// unsigned.
  final List<int> signature;

  /// The global identity.
  PacketId get packetId => header.packetId;

  /// True when this packet is one frame of a larger run.
  bool get isFragmented => header.isFragmented;

  /// A copy with [newSignature].
  Packet withSignature(List<int> newSignature) =>
      Packet(header: header, payload: payload, signature: newSignature);

  /// A copy with a new header (fragment boundary).
  Packet withHeader(PacketHeader newHeader) =>
      Packet(header: newHeader, payload: payload, signature: signature);

  /// A copy with a new payload (compression/decompression boundary).
  Packet withPayload(PacketPayload newPayload) =>
      Packet(header: header, payload: newPayload, signature: signature);

  @override
  String toString() =>
      'Packet(${header.packetId}, '
      '${payload.type}, ${payload.bytes.length} bytes, '
      'sig ${signature.length})';
}
