import 'packet_flag.dart';
import 'packet_id.dart';
import 'packet_priority.dart';
import 'packet_type.dart';
import 'packet_version.dart';

/// The immutable, field-complete packet header.
///
/// Mirrors the fixed 28-byte on-wire prefix plus the variable node ids
/// (see `docs/packet/03-header-layout.md`). All values are validated on
/// creation; a header can always serialize.
final class PacketHeader {
  PacketHeader({
    required this.sequence,
    required this.source,
    required this.destination,
    this.version = PacketVersion.current,
    this.compatibilityFlags = 0,
    this.type = PacketType.message,
    this.priority = PacketPriority.normal,
    this.flags = const {},
    this.reservedFlags = 0,
    this.ttl = 8,
    this.hopCount = 0,
    DateTime? createdAt,
    this.fragmentId = 0,
    this.fragmentIndex = 0,
    this.fragmentCount = 1,
  }) : createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0) {
    if (sequence < 0 || sequence > _maxSequence) {
      throw ArgumentError.value(sequence, 'sequence', 'out of u32 range');
    }
    if (fragmentIndex < 0 ||
        fragmentCount < 1 ||
        fragmentIndex >= fragmentCount) {
      throw ArgumentError.value(
        (fragmentIndex, fragmentCount),
        'fragmentIndex/fragmentCount',
        'index must be within [0, count)',
      );
    }
    if (ttl < 0 || ttl > 255) {
      throw ArgumentError.value(ttl, 'ttl', 'must be 0..255');
    }
    if (hopCount < 0 || hopCount > 255) {
      throw ArgumentError.value(hopCount, 'hopCount', 'must be 0..255');
    }
    if (reservedFlags != 0 && reservedFlags & 0xFF != reservedFlags) {
      throw ArgumentError.value(
        reservedFlags,
        'reservedFlags',
        'must fit a byte',
      );
    }
  }

  static const int _maxSequence = 0xFFFFFFFF;

  /// Protocol version of the frame.
  final PacketVersion version;

  /// Sender-declared compatibility offer (see protocol spec).
  final int compatibilityFlags;

  /// Lifecycle discriminator.
  final PacketType type;

  /// Queue ordering hint (2 wire bits).
  final PacketPriority priority;

  /// The eight wire flags.
  final Set<PacketFlag> flags;

  /// Unknown flag bits observed on the wire, preserved verbatim.
  final int reservedFlags;

  /// Remaining relay hops; 0 means not forwardable.
  final int ttl;

  /// Relays applied so far.
  final int hopCount;

  /// Source-local id; identical across all fragments of one logical packet.
  final int sequence;

  /// Origin node id (never changed by relays).
  final String source;

  /// Target node id, or empty for a broadcast.
  final String destination;

  /// Origin clock time (informational; seconds are what goes on the wire).
  final DateTime createdAt;

  /// Per-run seed that separates independent fragmentation runs of the same
  /// sequence.
  final int fragmentId;

  /// Position of this fragment within its run.
  final int fragmentIndex;

  /// Total fragments of the run; 1 for a non-fragmented packet.
  final int fragmentCount;

  /// True when the fragmented flag is set.
  bool get isFragmented => flags.contains(PacketFlag.fragmented);

  /// True when the destination is empty.
  bool get isBroadcast => destination.isEmpty;

  /// The global packet identity.
  PacketId get packetId => PacketId(source: source, sequence: sequence);

  /// A copy with [changes] applied — the only sanctioned mutation path.
  PacketHeader copyWith({
    PacketVersion? version,
    int? compatibilityFlags,
    PacketType? type,
    PacketPriority? priority,
    Set<PacketFlag>? flags,
    int? reservedFlags,
    int? ttl,
    int? hopCount,
    int? sequence,
    String? source,
    String? destination,
    DateTime? createdAt,
    int? fragmentId,
    int? fragmentIndex,
    int? fragmentCount,
  }) {
    return PacketHeader(
      version: version ?? this.version,
      compatibilityFlags: compatibilityFlags ?? this.compatibilityFlags,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      flags: flags ?? this.flags,
      reservedFlags: reservedFlags ?? this.reservedFlags,
      ttl: ttl ?? this.ttl,
      hopCount: hopCount ?? this.hopCount,
      sequence: sequence ?? this.sequence,
      source: source ?? this.source,
      destination: destination ?? this.destination,
      createdAt: createdAt ?? this.createdAt,
      fragmentId: fragmentId ?? this.fragmentId,
      fragmentIndex: fragmentIndex ?? this.fragmentIndex,
      fragmentCount: fragmentCount ?? this.fragmentCount,
    );
  }

  @override
  String toString() =>
      'PacketHeader($packetId → ${destination.isEmpty ? '*broadcast*' : destination}, '
      '$type/$priority, ttl $ttl, hops $hopCount, '
      'frag ${fragmentIndex + 1}/$fragmentCount)';
}
