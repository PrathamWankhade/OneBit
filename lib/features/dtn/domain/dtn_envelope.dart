import 'dtn_priority.dart';

/// Which side of a conversation an envelope represents at this node.
enum DtnDirection {
  /// Created locally; the scheduler eventually transmits it to its
  /// [DtnPacket.destination].
  outbound,

  /// Arrived from the mesh and awaits pickup by an upper layer
  /// ([observeDelivered]).
  inbound,

  /// Passing through this node toward a third node (not yet picked for the
  /// next hop — always a candidate for opportunistic forwarding).
  relay;

  String get wireName => name;
}

/// What the envelope body is.
enum DtnEnvelopeType {
  /// Application data (the message body in Phase 8).
  message,

  /// A logical acknowledgement whose payload is the acked packet id.
  ack,

  /// A control envelope (route hints, liveness), handled by the engine.
  control;

  String get wireName => name;
}

/// Lifecycle state of an envelope (persisted; never rename values).
///
/// The engine's `StoreForwardEngine` is the only writer of state
/// transitions; the enum itself never encodes scheduling policy.
enum DtnPacketState {
  /// Freshly stored, waiting for the scheduler to pick it up.
  queued,

  /// Transmit requested; no outcome recorded yet.
  pendingDelivery,

  /// A transmit failed; waiting for its backoff window to pass.
  retrying,

  /// Delivery attempts are paused (connectivity lost, or retry limit hit).
  /// The envelope is not lost — it resumes when the network returns.
  deferred,

  /// Multi-hop envelope waiting for its next relay hop to be selected.
  relaying,

  /// Awaiting the logical acknowledgement from the destination.
  awaitingAck,

  /// Fully delivered (acknowledged or locally confirmed). Removed from the
  /// queues; kept in the history only for dev diagnostics.
  delivered,

  /// Handed to the upper layer (this node is the final destination).
  deliveredLocally,

  /// Inbound envelope picked up by the upper layer.
  consumed,

  /// Failed permanently (gateway refused, envelope invalid).
  failed,

  /// TTL expired; cleaned from the queues and database.
  expired;

  String get wireName => name;
}

/// Acknowledgement handshake state of an outbound envelope.
enum DtnAckState {
  /// No ack expected (control frames, fire-and-forget messages).
  none,

  /// Transmit succeeded; waiting for the logical ack before `deliveredAt`.
  awaiting,

  /// The logical ack arrived; delivery is confirmed.
  received,

  /// The ack deadline passed; the envelope re-enters delivery.
  timedOut;

  String get wireName => name;
}

/// An immutable delay-tolerant envelope.
///
/// The envelope is the *only* representation of a packet in this phase: it
/// is what upper layers store, what the queues index, what the database
/// persists and what the gateway transmits. Nothing else carries delivery
/// state, so memory, disk and wires can never disagree about one packet.
final class DtnPacket {
  const DtnPacket({
    required this.packetId,
    required this.source,
    required this.destination,
    required this.payload,
    required this.priority,
    required this.direction,
    required this.ttlSeconds,
    required this.createdAt,
    required this.expiresAt,
    this.type = DtnEnvelopeType.message,
    this.state = DtnPacketState.queued,
    this.attemptCount = 0,
    this.lastAttemptAt,
    this.nextAttemptAt,
    this.lastError,
    this.ackState = DtnAckState.none,
    this.ackDeadlineAt,
    this.ackedBy,
    this.deliveredAt,
    this.hopCount = 0,
    this.enqueuedAt,
  });

  /// Unique id: `localNode:sequence`. Idempotency key for store().
  final String packetId;

  /// Origin node id (the local node for outbound envelopes).
  final String source;

  /// Final destination node id.
  final String destination;

  /// Opaque bytes carried by the envelope.
  final List<int> payload;

  final DtnPriority priority;

  final DtnDirection direction;

  /// Time-to-live of the envelope in (fractional) seconds.
  final int ttlSeconds;

  final DateTime createdAt;

  /// Hard wall-clock bound: `createdAt + ttl`. Never moved once set.
  final DateTime expiresAt;

  final DtnEnvelopeType type;

  final DtnPacketState state;

  /// Number of transmit attempts so far.
  final int attemptCount;

  final DateTime? lastAttemptAt;

  /// The wall-clock moment after which a retrying envelope may be tried again
  /// (nil while parked).
  final DateTime? nextAttemptAt;

  /// Human-readable reason of the latest failed attempt.
  final String? lastError;

  final DtnAckState ackState;

  /// Wall-clock deadline for the awaited ack.
  final DateTime? ackDeadlineAt;

  /// Node that acknowledged delivery (dev diagnostics).
  final String? ackedBy;

  /// When delivery was confirmed end-to-end.
  final DateTime? deliveredAt;

  /// Number of relay hops the envelope has already travelled.
  final int hopCount;

  /// When the envelope entered its current queue (sorting key).
  final DateTime? enqueuedAt;

  /// True when this node's envelope already reached its destination.
  bool get isDelivered =>
      state == DtnPacketState.delivered ||
      state == DtnPacketState.deliveredLocally ||
      state == DtnPacketState.consumed;

  /// True when the envelope is no longer eligible for delivery.
  bool get isTerminal =>
      state == DtnPacketState.expired ||
      state == DtnPacketState.failed ||
      state == DtnPacketState.consumed;

  bool get isAckEnvelope => type == DtnEnvelopeType.ack;

  /// A copy with any subset of fields replaced.
  DtnPacket copyWith({
    DtnPacketState? state,
    int? attemptCount,
    DateTime? lastAttemptAt,
    DateTime? nextAttemptAt,
    String? lastError,
    DtnAckState? ackState,
    DateTime? ackDeadlineAt,
    String? ackedBy,
    DateTime? deliveredAt,
    int? hopCount,
    DateTime? enqueuedAt,
    DtnDirection? direction,
  }) {
    return DtnPacket(
      packetId: packetId,
      source: source,
      destination: destination,
      payload: payload,
      priority: priority,
      direction: direction ?? this.direction,
      ttlSeconds: ttlSeconds,
      createdAt: createdAt,
      expiresAt: expiresAt,
      type: type,
      state: state ?? this.state,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      ackState: ackState ?? this.ackState,
      ackDeadlineAt: ackDeadlineAt ?? this.ackDeadlineAt,
      ackedBy: ackedBy ?? this.ackedBy,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      hopCount: hopCount ?? this.hopCount,
      enqueuedAt: enqueuedAt ?? this.enqueuedAt,
    );
  }

  @override
  String toString() =>
      'DtnPacket($packetId → $destination '
      '[${priority.name}, $state])';
}
