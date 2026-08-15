/// Immutable point-in-time snapshot of every DTN queue view.
///
/// Broadcast by the engine on every envelope transition so the developer
/// screens can render queue depth without touching engine internals.
final class DtnQueueSnapshot {
  const DtnQueueSnapshot({
    required this.outgoing,
    required this.deferred,
    required this.retry,
    required this.incoming,
    required this.relaying,
    required this.awaitingAck,
    required this.live,
    required this.takenAt,
  });

  final int outgoing;
  final int deferred;
  final int retry;
  final int incoming;
  final int relaying;
  final int awaitingAck;

  /// All non-expired envelopes regardless of direction (priority view).
  final int live;

  /// When the snapshot was captured.
  final DateTime takenAt;

  static final empty = DtnQueueSnapshot(
    outgoing: 0,
    deferred: 0,
    retry: 0,
    incoming: 0,
    relaying: 0,
    awaitingAck: 0,
    live: 0,
    takenAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  @override
  String toString() =>
      'DtnQueueSnapshot(out:$outgoing def:$deferred retry:$retry '
      'in:$incoming relay:$relaying ack:$awaitingAck live:$live)';
}
