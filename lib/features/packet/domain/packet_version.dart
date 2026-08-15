/// The three-part version identity of every frame.
///
/// - [transport] — wire format; a mismatch makes bytes unreadable and the
///   frame is always dropped.
/// - [major] — protocol semantics; a mismatch means "understandable bytes,
///   unknown meaning".
/// - [revision] — backwards-compatible delta, tolerated in both directions.
final class PacketVersion {
  const PacketVersion({
    required this.transport,
    required this.major,
    required this.revision,
  });

  /// The version every node of this build emits.
  static const PacketVersion current = PacketVersion(
    transport: 1,
    major: 1,
    revision: 0,
  );

  final int transport;
  final int major;
  final int revision;

  /// How [other] relates to this version, for compatibility decisions.
  PacketVersionRelation relationTo(PacketVersion other) {
    if (transport != other.transport) {
      return PacketVersionRelation.transportMismatch;
    }
    if (major != other.major) {
      return other.major > major
          ? PacketVersionRelation.newerMajor
          : PacketVersionRelation.olderMajor;
    }
    if (revision != other.revision) {
      return other.revision > revision
          ? PacketVersionRelation.newerRevision
          : PacketVersionRelation.olderRevision;
    }
    return PacketVersionRelation.identical;
  }

  @override
  bool operator ==(Object other) =>
      other is PacketVersion &&
      other.transport == transport &&
      other.major == major &&
      other.revision == revision;

  @override
  int get hashCode => Object.hash(transport, major, revision);

  @override
  String toString() => 'v$transport.$major.$revision';
}

/// How two [PacketVersion]s relate on the wire.
enum PacketVersionRelation {
  /// Same version: full compatibility.
  identical,

  /// Same transport and major, newer revision: sender is ahead by an
  /// additive feature; frame is deliverable.
  newerRevision,

  /// Same transport and major, older revision: sender is behind; frame is
  /// deliverable.
  olderRevision,

  /// Same transport, different major: semantics unknown; deliver only when
  /// the sender declared forward compatibility.
  newerMajor,
  olderMajor,

  /// Different transport: bytes cannot be interpreted; always dropped.
  transportMismatch,
}
