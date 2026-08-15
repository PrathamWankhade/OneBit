import 'dart:collection';

import 'package:onebit/features/mesh/domain/mesh_packet.dart';

/// Bounded seen-cache that makes forwarding a DAG.
///
/// Keys are 32-bit hashes of `source:sequence`, stored in insertion order
/// so the oldest entries are evicted first when [capacity] is exceeded.
/// Entries also expire after [window], so memory stays flat no matter how
/// much traffic flows.
final class DuplicatePacketDetector {
  DuplicatePacketDetector({
    this.capacity = 2048,
    this.window = const Duration(seconds: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int capacity;
  final Duration window;
  final DateTime Function() _now;

  final LinkedHashMap<int, DateTime> _seen = LinkedHashMap<int, DateTime>();

  int _hits = 0;
  int _evictions = 0;

  /// Number of cached entries.
  int get size => _seen.length;

  /// Duplicate hits (packets re-seen within the window).
  int get hits => _hits;

  /// Capacity overflows evicted.
  int get evictions => _evictions;

  /// True when the packet is new (not seen within [window]).
  ///
  /// Call once per packet pass: the first call inserts and returns `true` —
  /// the relay pipeline treats "seen before" as a duplicate drop.
  bool markSeen(MeshPacket packet) {
    final key = _keyOf(packet);
    final seenAt = _seen[key];
    if (seenAt != null) {
      _hits++;
      return false;
    }
    _seen[key] = _now();
    while (_seen.length > capacity) {
      _evictions++;
      _seen.remove(_seen.keys.first);
    }
    return true;
  }

  /// True when the packet was already recorded inside the window.
  bool isSeen(MeshPacket packet) => _seen.containsKey(_keyOf(packet));

  /// Drops entries older than [window] measured against [now].
  void sweep(DateTime now) {
    final cutoff = now.subtract(window);
    _seen.removeWhere((_, seenAt) => seenAt.isBefore(cutoff));
  }

  /// Stable non-negative hash of the packet's unique id.
  int _keyOf(MeshPacket packet) {
    final raw = packet.packetId.hashCode;
    return raw & 0x7FFFFFFF;
  }
}
