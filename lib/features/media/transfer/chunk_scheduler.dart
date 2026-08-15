import 'dart:collection';

import 'transfer_bitmap.dart';

/// Pure scheduling decisions of the chunk pump.
///
/// Given the authoritative bitmap + the set of in-flight chunk indices,
/// produces the next chunk to transmit under the engine's window rules.
/// Deterministic and fully unit-testable — no I/O.
final class ChunkScheduler {
  const ChunkScheduler({required this.window});

  /// How many chunks may be selected ahead of the acknowledged frontier
  /// (sequential BLE delivery prefers low windows).
  final int window;

  /// The next chunk index to send, or null when nothing is pending.
  ///
  /// [inFlight] holds indices already dispatched; candidates are the
  /// missing chunks within `[lastAcked+1, lastAcked+1+window)` — chunks
  /// beyond the window wait, keeping the wire sequential and the resume
  /// bitmap compact.
  int? nextChunk(TransferBitmap bitmap, Set<int> inFlight) {
    if (bitmap.isComplete) return null;
    var frontier = -1;
    for (var i = 0; i < bitmap.totalChunks; i++) {
      if (bitmap.acknowledged(i)) {
        frontier = i;
      } else {
        break;
      }
    }
    final upper = (frontier + 1 + window).clamp(0, bitmap.totalChunks);
    for (var i = frontier + 1; i < upper; i++) {
      if (!bitmap.acknowledged(i) && !inFlight.contains(i)) {
        return i;
      }
    }
    return null;
  }

  /// The missing indices beyond the window, ascending (used by requests
  /// and complete outcomes).
  List<int> backlog(TransferBitmap bitmap, Set<int> inFlight) {
    final result = <int>[];
    for (var i = 0; i < bitmap.totalChunks; i++) {
      if (!bitmap.acknowledged(i) && !inFlight.contains(i)) {
        result.add(i);
      }
    }
    return result;
  }

  /// Unmodifiable copy of [inFlight] (defensive for callers).
  static Set<int> freeze(Set<int> inFlight) => UnmodifiableSetView(inFlight);
}
