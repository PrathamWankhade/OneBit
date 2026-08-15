/// Lifecycle state of a message. Every transition is persisted before any
/// side effect is raised.
///
/// Stable name strings are what SQLite stores (`MessageStatus` in the shared
/// enum vocabulary); add values, never rename.
enum MessageStatus {
  /// The message object exists but has not entered any queue yet.
  created(0),

  /// Inside the local outbox, packet not stored yet.
  queued(1),

  /// Envelope stored into the DTN layer; delivery deferred.
  waiting(2),

  /// The mesh is actively carrying the envelope toward its destination.
  routing(3),

  /// The envelope moved hop-by-hop at least once.
  relayed(4),

  /// The remote node confirmed delivery (delivery receipt applied).
  delivered(5),

  /// The receipt chain verified the payload (future crypto verification).
  verified(6),

  /// A read receipt was applied for the final recipient.
  read(7),

  /// The message TTL passed before reaching a terminal confirmation.
  expired(8),

  /// Permanent failure (validation, protocol, policy).
  failed(9),

  /// Locally deleted (soft tombstone; body is erased by the data layer).
  deleted(10);

  /// Progress rank for forward-only transition checks.
  final int rank;

  const MessageStatus(this.rank);

  bool get isTerminal =>
      this == MessageStatus.expired ||
      this == MessageStatus.failed ||
      this == MessageStatus.deleted;

  bool get isLive =>
      rank > 0 &&
      rank < MessageStatus.expired.rank &&
      this != MessageStatus.deleted;

  /// Stable persistence name (shared vocabulary with the core schema).
  String get wireName => name;

  /// Maps a persisted core-schema name back into the domain status.
  static MessageStatus? fromWireName(String name) => switch (name) {
    'pending' => MessageStatus.queued,
    'sent' => MessageStatus.relayed,
    _ => MessageStatus.values.where((s) => s.name == name).firstOrNull,
  };
}
