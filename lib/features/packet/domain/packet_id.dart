/// Globally distinguishing identity of a logical packet.
///
/// Mirrors the mesh layer's `MeshPacket.packetId` (`source:sequence`) so a
/// packet carries the same identity from the packet layer to the duplicate
/// detector and back.
final class PacketId {
  const PacketId({required this.source, required this.sequence});

  /// Identity-derived node id of the *original* sender. Relayers never
  /// change it.
  final String source;

  /// Source-local monotonic number, incremented by 1 per logical packet.
  final int sequence;

  /// The canonical string form (`source:sequence`).
  String get value => '$source:$sequence';

  @override
  bool operator ==(Object other) =>
      other is PacketId && other.source == source && other.sequence == sequence;

  @override
  int get hashCode => Object.hash(source, sequence);

  @override
  String toString() => 'PacketId($value)';
}
