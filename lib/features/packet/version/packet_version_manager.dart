import 'package:onebit/features/packet/domain/packet_version.dart';

/// Outcome of a version gate: the frame is accepted for delivery, or is
/// dropped as semantically unsupported.
final class PacketVersionVerdict {
  const PacketVersionVerdict({required this.accepted, this.relation});

  /// True when the frame may proceed to delivery.
  final bool accepted;

  /// The relation that was evaluated, when a gate decided.
  final PacketVersionRelation? relation;
}

/// Compatibility gate based on the three version fields plus the sender's
/// declared compatibility flags.
///
/// Implements protocol spec §versioning: transport mismatch always drops;
/// a newer major is deliverable only when the sender declared forward
/// compatibility; older majors and revision deltas in either direction are
/// deliverable.
abstract final class PacketVersionManager {
  PacketVersionManager._();

  /// Bits of the compatibility byte.
  static const int compatibleForward = 0x01;
  static const int compatibleDegrade = 0x02;
  static const int compatibleForwardUnknownFlags = 0x04;

  /// Decides whether a frame written with [candidate] is deliverable by a
  /// node running [local].
  static PacketVersionVerdict verify(
    PacketVersion candidate, {
    PacketVersion local = PacketVersion.current,
    int compatibilityFlags = 0,
  }) {
    final relation = local.relationTo(candidate);
    switch (relation) {
      case PacketVersionRelation.identical:
      case PacketVersionRelation.newerRevision:
      case PacketVersionRelation.olderRevision:
        return PacketVersionVerdict(accepted: true, relation: relation);
      case PacketVersionRelation.newerMajor:
        final forward = (compatibilityFlags & compatibleForward) != 0;
        return PacketVersionVerdict(
          accepted: forward,
          relation: PacketVersionRelation.newerMajor,
        );
      case PacketVersionRelation.olderMajor:
        return PacketVersionVerdict(accepted: true, relation: relation);
      case PacketVersionRelation.transportMismatch:
        return PacketVersionVerdict(accepted: false, relation: relation);
    }
  }
}
