import 'package:flutter/foundation.dart';

import 'transfer_state.dart';

/// One chunk of a transfer session: absolute file geometry + ledger state.
///
/// Immutable. The [TransferEngine] persists every transition through the
/// repository; the chunk bitmap on the session remains the crash-safe
/// source of truth, this ledger carries hashes and bookkeeping.
@immutable
final class TransferChunk {
  const TransferChunk({
    required this.sessionId,
    required this.index,
    required this.offset,
    required this.sizeBytes,
    this.sha256,
    this.state = ChunkState.pending,
    this.attempts = 0,
    this.sentAt,
    this.ackedAt,
  });

  final String sessionId;

  /// Position in the chunk sequence (0-based; reassembly key).
  final int index;

  /// Absolute byte offset inside the original file.
  final int offset;

  /// Number of payload bytes of this chunk (the tail chunk may be short).
  final int sizeBytes;

  /// Hex SHA-256 of this chunk's payload bytes.
  final String? sha256;

  final ChunkState state;

  /// Transmit attempts so far (a chunk is requeued after nacks/timeouts).
  final int attempts;

  final DateTime? sentAt;
  final DateTime? ackedAt;

  /// True when this chunk may be scheduled for transmission.
  bool get isPending =>
      state == ChunkState.pending || state == ChunkState.failed;

  TransferChunk copyWith({
    String? sha256,
    ChunkState? state,
    int? attempts,
    DateTime? sentAt,
    DateTime? ackedAt,
  }) => TransferChunk(
    sessionId: sessionId,
    index: index,
    offset: offset,
    sizeBytes: sizeBytes,
    sha256: sha256 ?? this.sha256,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    sentAt: sentAt ?? this.sentAt,
    ackedAt: ackedAt ?? this.ackedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is TransferChunk &&
      other.sessionId == sessionId &&
      other.index == index;

  @override
  int get hashCode => Object.hash(sessionId, index);

  @override
  String toString() =>
      'TransferChunk($sessionId#$index off=$offset len=$sizeBytes '
      '[$state, $attempts attempts])';
}
