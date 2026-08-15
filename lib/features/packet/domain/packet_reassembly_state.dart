import 'package:onebit/features/packet/domain/packet.dart';
import 'package:onebit/features/packet/domain/packet_id.dart';

/// Lifecycle states of a reassembly session.
enum ReassemblyState {
  /// Still waiting for fragments; the session is active.
  collecting,

  /// Every fragment is present; the merged packet was emitted.
  complete,

  /// The session timed out or hit a limit; the partial set was dropped.
  expired,
}

/// One in-progress reassembly session keyed by
/// `(packetId, fragmentId)`.
///
/// Sessions buffer fragment chunks, track arrival times for expiry, and
/// emit the ordered payload only when every index is present. Values are
/// mutable *inside* the reassembly engine only; nothing here crosses a
/// feature boundary.
final class ReassemblySession {
  ReassemblySession({
    required this.packetId,
    required this.fragmentId,
    required this.fragmentCount,
    required this.expiresAt,
    required this.now,
  }) : _chunks = <int, List<int>>{};

  final PacketId packetId;
  final int fragmentId;
  final int fragmentCount;
  final DateTime Function() now;

  /// When this session gives up waiting.
  final DateTime expiresAt;

  final Map<int, List<int>> _chunks;

  /// Number of distinct fragments accepted so far.
  int get fragmentsPresent => _chunks.length;

  /// True once every index 0..count-1 arrived.
  bool get isComplete => _chunks.length == fragmentCount;

  /// True when [now]() has passed [expiresAt].
  bool get isExpired => now().isAfter(expiresAt);

  /// True when the fragment at [index] was already stored.
  bool contains(int index) => _chunks.containsKey(index);

  /// The index-0 fragment, kept so the reassembler can rebuild the header,
  /// payload type and signature. Non-null once the run completes.
  Packet? firstFragment;

  /// Stores [bytes] at [index]; returns false when already present.
  bool store(int index, List<int> bytes) {
    if (_chunks.containsKey(index)) return false;
    _chunks[index] = List<int>.unmodifiable(bytes);
    return true;
  }

  /// The ordered payload, or `null` while incomplete.
  List<int>? assembleOrdered() {
    if (!isComplete) return null;
    final buffer = <int>[];
    for (var i = 0; i < fragmentCount; i++) {
      buffer.addAll(_chunks[i]!);
    }
    return buffer;
  }
}
