/// Lifecycle state of a transfer session.
///
/// Values are persisted as stable names — never rename or reorder once
/// released. Only the [TransferEngine] writes transitions.
enum TransferState {
  /// Session created, announce accepted; chunks not yet dispatched.
  queued,

  /// The chunk pump is dispatching envelopes.
  transferring,

  /// Scheduler stopped; the session resumes from its bitmap.
  paused,

  /// Resume in progress (bitmap read, missing chunks re-queued).
  resuming,

  /// All chunks acked; the whole-file hash check is running.
  verifying,

  /// Fully delivered and verified. Terminal.
  completed,

  /// Failed permanently (integrity, storage, retry budget). Retry allowed.
  failed,

  /// Cancelled by the user. Terminal; temp files purged.
  cancelled,

  /// Session TTL passed. Terminal.
  expired;

  /// Stable persistence / wire name.
  String get wireName => name;

  /// Maps a persisted name back; null when unknown (forward compatibility).
  static TransferState? fromWireName(String name) => switch (name) {
    'queued' => TransferState.queued,
    'transferring' => TransferState.transferring,
    'paused' => TransferState.paused,
    'resuming' => TransferState.resuming,
    'verifying' => TransferState.verifying,
    'completed' => TransferState.completed,
    'failed' => TransferState.failed,
    'cancelled' => TransferState.cancelled,
    'expired' => TransferState.expired,
    _ => null,
  };

  /// True while the session is still expected to make progress.
  bool get isActive =>
      this == TransferState.queued ||
      this == TransferState.transferring ||
      this == TransferState.paused ||
      this == TransferState.resuming ||
      this == TransferState.verifying;

  /// True once the session cannot transition back to active.
  bool get isTerminal =>
      isCompleted ||
      this == TransferState.failed ||
      this == TransferState.cancelled ||
      this == TransferState.expired;

  bool get isCompleted => this == TransferState.completed;
}

/// Which side of the wire a session represents at this node.
enum TransferDirection {
  /// This node owns the file and pumps chunks to [TransferSession.peerNodeId].
  send,

  /// This node receives the file and acknowledges chunks.
  receive;

  String get wireName => name;

  static TransferDirection? fromWireName(String name) => switch (name) {
    'send' => TransferDirection.send,
    'receive' => TransferDirection.receive,
    _ => null,
  };
}

/// State of one chunk inside a session's ledger.
enum ChunkState {
  /// Not yet transmitted (or requeued after a nack / timeout).
  pending,

  /// Transmitted and awaiting its acknowledgement.
  inFlight,

  /// Verified by the receiver and acknowledged.
  acknowledged,

  /// Exhausted its retry budget.
  failed;

  String get wireName => name;

  static ChunkState? fromWireName(String name) => switch (name) {
    'pending' => ChunkState.pending,
    'inFlight' => ChunkState.inFlight,
    'acknowledged' => ChunkState.acknowledged,
    'failed' => ChunkState.failed,
    _ => null,
  };
}
