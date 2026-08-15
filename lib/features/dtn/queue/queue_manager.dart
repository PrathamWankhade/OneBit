import '../delivery/store_forward_engine.dart';
import '../domain/dtn_envelope.dart';

/// Read-only views over the engine's internal queues.
///
/// Provides independent queue access for scheduling, monitoring, and diagnostics
/// without exposing engine internals.
final class QueueManager {
  QueueManager(this._engine);

  final StoreForwardEngine _engine;

  /// Outbound queue: envelopes created locally awaiting first transmission.
  /// States: queued, pendingDelivery.
  List<DtnPacket> get outgoing => _engine.envelopes
      .where(
        (p) =>
            p.direction == DtnDirection.outbound &&
            (p.state == DtnPacketState.queued ||
                p.state == DtnPacketState.pendingDelivery),
      )
      .toList();

  /// Incoming queue: envelopes delivered to this node as final destination.
  /// States: deliveredLocally.
  List<DtnPacket> get incoming => _engine.envelopes
      .where((p) => p.state == DtnPacketState.deliveredLocally)
      .toList();

  /// Relay queue: envelopes passing through this node to a third node.
  /// States: relaying.
  List<DtnPacket> get relaying => _engine.envelopes
      .where((p) => p.state == DtnPacketState.relaying)
      .toList();

  /// Retry queue: envelopes waiting for their backoff window.
  /// States: retrying.
  List<DtnPacket> get retrying => _engine.envelopes
      .where((p) => p.state == DtnPacketState.retrying)
      .toList();

  /// Deferred queue: envelopes parked due to connectivity loss or retry limit.
  /// States: deferred.
  List<DtnPacket> get deferred => _engine.envelopes
      .where((p) => p.state == DtnPacketState.deferred)
      .toList();

  /// ACK queue: envelopes awaiting logical acknowledgement.
  /// States: awaitingAck.
  List<DtnPacket> get awaitingAck => _engine.envelopes
      .where((p) => p.state == DtnPacketState.awaitingAck)
      .toList();

  /// Expiration queue: all live envelopes sorted by expiration time (soonest first).
  List<DtnPacket> get byExpiration =>
      _engine.envelopes.where((p) => !p.isTerminal).toList()
        ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));

  /// Priority queue: all live envelopes sorted by priority (highest first), then enqueue order.
  List<DtnPacket> get byPriority =>
      _engine.envelopes.where((p) => !p.isTerminal).toList()
        ..sort(_priorityOrder);

  /// All live (non-terminal) envelopes.
  List<DtnPacket> get live =>
      _engine.envelopes.where((p) => !p.isTerminal).toList();

  /// Counts per queue for quick snapshots.
  QueueCounts counts() {
    var outgoing = 0, incoming = 0, relaying = 0, retrying = 0;
    var deferred = 0, awaitingAck = 0, live = 0;
    for (final p in _engine.envelopes) {
      if (p.isTerminal) continue;
      live++;
      switch (p.state) {
        case DtnPacketState.queued:
        case DtnPacketState.pendingDelivery:
          if (p.direction == DtnDirection.outbound) outgoing++;
          break;
        case DtnPacketState.retrying:
          retrying++;
        case DtnPacketState.deferred:
          deferred++;
        case DtnPacketState.relaying:
          relaying++;
        case DtnPacketState.awaitingAck:
          awaitingAck++;
        case DtnPacketState.deliveredLocally:
          incoming++;
        case DtnPacketState.consumed:
        case DtnPacketState.delivered:
        case DtnPacketState.failed:
        case DtnPacketState.expired:
          break;
      }
    }
    return QueueCounts(
      outgoing: outgoing,
      incoming: incoming,
      relaying: relaying,
      retrying: retrying,
      deferred: deferred,
      awaitingAck: awaitingAck,
      live: live,
    );
  }

  /// Lookup envelope by ID across all queues.
  DtnPacket? find(String packetId) => _engine.statusOf(packetId);

  /// Get all envelopes for a specific destination.
  List<DtnPacket> forDestination(String destination) => _engine.envelopes
      .where((p) => p.destination == destination && !p.isTerminal)
      .toList();

  /// Get all envelopes from a specific source.
  List<DtnPacket> fromSource(String source) => _engine.envelopes
      .where((p) => p.source == source && !p.isTerminal)
      .toList();

  static int _priorityOrder(DtnPacket a, DtnPacket b) {
    // DtnPriority rank is indexed: critical=0 … background=4, so ascending
    // rank is exactly the delivery order (critical first).
    final byPriority = a.priority.rank.compareTo(b.priority.rank);
    if (byPriority != 0) return byPriority;
    final at = a.enqueuedAt ?? a.createdAt;
    final bt = b.enqueuedAt ?? b.createdAt;
    return at.compareTo(bt);
  }
}

/// Aggregate queue counts for monitoring.
final class QueueCounts {
  const QueueCounts({
    required this.outgoing,
    required this.incoming,
    required this.relaying,
    required this.retrying,
    required this.deferred,
    required this.awaitingAck,
    required this.live,
  });

  final int outgoing;
  final int incoming;
  final int relaying;
  final int retrying;
  final int deferred;
  final int awaitingAck;
  final int live;

  int get total =>
      outgoing + incoming + relaying + retrying + deferred + awaitingAck;

  @override
  String toString() =>
      'QueueCounts(out:$outgoing in:$incoming relay:$relaying '
      'retry:$retrying def:$deferred ack:$awaitingAck live:$live)';
}
