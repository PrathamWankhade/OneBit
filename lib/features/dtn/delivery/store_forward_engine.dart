import 'dart:async';

import '../ack/acknowledgement_manager.dart';
import '../domain/dtn_connectivity.dart';
import '../domain/dtn_diagnostics.dart';
import '../domain/dtn_envelope.dart';
import '../domain/dtn_failure.dart';
import '../domain/dtn_priority.dart';
import '../domain/dtn_queue_snapshot.dart';
import '../domain/dtn_statistics.dart';
import 'dtn_config.dart';
import 'dtn_gateway.dart';

/// A packet id (e.g. an ack reference) that is in the dedupe window.
///
/// Kept in [AcknowledgementManager]'s bounded ledger.
typedef PacketId = String;

/// Single seam for durable persistence behind the engine.
///
/// The engine is fully synchronous and *persistence-agnostic*; the wiring
/// (data layer) implements this over `DtnDao` and swaps it for an in-memory
/// fake in tests.
abstract interface class DtnPersistence {
  /// Durably store one envelope row.
  Future<void> upsert(DtnPacket packet);

  /// Durably delete one envelope row.
  Future<void> deletePacket(String packetId);

  /// Load everything known (called once during restore).
  Future<List<DtnPacket>> loadAll();
}

/// In-memory persistence used by tests and the no-storage builds.
final class MemoryDtnPersistence implements DtnPersistence {
  final Map<String, DtnPacket> _rows = <String, DtnPacket>{};

  Map<String, DtnPacket> get rows => _rows;

  @override
  Future<void> upsert(DtnPacket packet) async {
    _rows[packet.packetId] = packet;
  }

  @override
  Future<void> deletePacket(String packetId) async {
    _rows.remove(packetId);
  }

  @override
  Future<List<DtnPacket>> loadAll() async => _rows.values.toList();
}

/// Statistics recorder; emits [DtnStatisticsSnapshot] after every event.
final class DeliveryStatistics {
  DeliveryStatistics();

  final StreamController<DtnStatisticsSnapshot> _controller =
      StreamController.broadcast();

  int stored = 0;
  int delivered = 0;
  int acknowledged = 0;
  int expired = 0;
  int retried = 0;
  int relayed = 0;
  int recovered = 0;
  int parked = 0;
  int deduplicated = 0;
  int liveEnvelopes = 0;
  double _latencySum = 0;
  int _latencySamples = 0;

  static const _latencyWindow = 64;

  Stream<DtnStatisticsSnapshot> get stream => _controller.stream;

  DtnStatisticsSnapshot snapshot() => DtnStatisticsSnapshot(
    stored: stored,
    delivered: delivered,
    acknowledged: acknowledged,
    expired: expired,
    retried: retried,
    relayed: relayed,
    recovered: recovered,
    parked: parked,
    deduplicated: deduplicated,
    liveEnvelopes: liveEnvelopes,
    avgDeliveryLatency: _latencySamples == 0
        ? null
        : _latencySum / _latencySamples,
    recordedAt: DateTime.now(),
  );

  void publish() {
    if (!_controller.isClosed) {
      _controller.add(snapshot());
    }
  }

  void recordSample(DateTime created, DateTime deliveredAt) {
    final latency = deliveredAt.difference(created).inMilliseconds / 1000.0;
    _latencySum += latency;
    _latencySamples = (_latencySamples + 1).clamp(1, _latencyWindow);
    if (_latencySamples == _latencyWindow) {
      _latencySum /= 2; // simple decay so old samples fade
      _latencySamples = _latencyWindow ~/ 2;
    }
  }

  void dispose() => _controller.close();
}

/// The store-and-forward state machine.
///
/// This is the *only* place transition edges live. It holds the envelope map
/// (source of truth), exposes ordered views for the scheduler, and emits
/// snapshots + diagnostics on every change. All methods are synchronous so
/// tests drive them deterministically; persistence happens through the
/// injected [DtnPersistence] on every transition.
final class StoreForwardEngine {
  StoreForwardEngine({
    required this.config,
    required this.persistence,
    required this._now,
    required this.gateway,
  }) : ackManager = AcknowledgementManager(ackTimeout: config.ackTimeout);

  final DtnEngineConfig config;
  final DtnPersistence persistence;
  final DateTime Function() _now;
  final DtnGateway gateway;

  /// The engine's wall clock (injectable; shared with the scheduler).
  DateTime get now => _now();

  final Map<String, DtnPacket> _envelopes = {};
  final AcknowledgementManager ackManager;
  late final DeliveryStatistics statistics = DeliveryStatistics();
  late final DtnDiagnosticsRing diagnostics = DtnDiagnosticsRing();

  final StreamController<DtnQueueSnapshot> _queueController =
      StreamController.broadcast();
  final StreamController<DtnPacket> _inboundController =
      StreamController.broadcast();
  final StreamController<DtnConnectivitySnapshot> _connectivityController =
      StreamController.broadcast();

  DtnConnectivitySnapshot _connectivity = DtnConnectivitySnapshot.initial;

  /// Set at construction (tests) or after restore; never replaced.
  bool _started = false;

  /// Live envelopes (all non-terminal states).
  Iterable<DtnPacket> get envelopes => _envelopes.values;

  /// Ordered views (cached, rebuilt on mutation).
  late final List<DtnPacket> _outgoing = [];
  late final List<DtnPacket> _retry = [];
  late final List<DtnPacket> _deferred = [];
  late final List<DtnPacket> _relaying = [];

  Stream<DtnQueueSnapshot> get queueSnapshots => _queueController.stream;
  Stream<DtnPacket> get inboundDeliveries => _inboundController.stream;
  Stream<DtnConnectivitySnapshot> get connectivityChanges =>
      _connectivityController.stream;

  DtnConnectivitySnapshot get connectivity => _connectivity;

  // ---- Lifecycle -----------------------------------------------------------------

  /// Load persisted envelopes into the engine (idempotent).
  void restore(List<DtnPacket> persisted, {DateTime? at}) {
    if (_started) {
      throw StateError('restore() must run before start()');
    }
    final now = at ?? _now();
    for (final packet in persisted) {
      if (packet.isTerminal || packet.expiresAt.isBefore(now)) {
        if (packet.expiresAt.isBefore(now)) {
          statistics.expired++;
        }
        unawaited(persistence.deletePacket(packet.packetId));
        continue;
      }
      _insertEnvelope(packet, notify: false);
    }
    statistics.recovered = persisted.length;
    _started = true;
    _publishSnapshot();
  }

  void start() {
    if (!_started) {
      _started = true;
    }
    _publishSnapshot();
  }

  void dispose() {
    _queueController.close();
    _inboundController.close();
    _connectivityController.close();
    statistics.dispose();
  }

  // ---- Public API (store / cancel / ack) -----------------------------------------

  DtnPacket store(DtnPacket packet, {DateTime? at}) {
    final now = at ?? _now();
    _validateNew(packet);
    final existing = _envelopes[packet.packetId];
    if (existing != null) {
      // Idempotent: the same packet id is already known.
      return existing;
    }
    if (_liveCount() >= config.maxLiveEnvelopes) {
      throw DtnFailure.queueOverflow(config.maxLiveEnvelopes);
    }
    statistics.stored++;
    final stored = packet.copyWith(enqueuedAt: now);
    _insertEnvelope(stored);
    unawaited(persistence.upsert(stored));
    _logTransition(DtnDiagnosticEventKind.stored, stored);
    return stored;
  }

  DtnPacket cancel(String packetId) {
    final packet = _envelopes[packetId];
    if (packet == null) {
      throw DtnFailure.notFound(packetId);
    }
    if (packet.isTerminal) {
      throw DtnFailure.alreadyTerminal(packetId);
    }
    _removeEnvelope(packetId);
    unawaited(persistence.deletePacket(packetId));
    _logTransition(
      DtnDiagnosticEventKind.rejectedPermanently,
      packet,
      message: 'cancelled by caller',
    );
    return packet;
  }

  /// Current state of an envelope, or null when unknown to this node.
  DtnPacket? statusOf(String packetId) => _envelopes[packetId];

  /// Insert an envelope that is already in a life-cycle state (managers,
  /// recovery and tests). Idempotent per packet id.
  DtnPacket reattach(DtnPacket packet, {bool notify = true}) {
    final existing = _envelopes[packet.packetId];
    if (existing != null && !existing.isTerminal) {
      _replace(existing, packet, publish: notify);
    } else {
      _insertEnvelope(packet, notify: notify);
      unawaited(persistence.upsert(packet));
    }
    return packet;
  }

  /// The destination node confirmed delivery of [packetId].
  void acknowledge(String packetId, {String? by, DateTime? at}) {
    final now = at ?? _now();
    final packet = _envelopes[packetId];
    if (packet == null || packet.isTerminal) {
      if (packet == null) {
        // Late ack for an already-removed envelope: still record it so a
        // duplicate is never re-sent.
        statistics.deduplicated++;
      }
      return;
    }
    final fresh = ackManager.acknowledge(packetId, now);
    if (!fresh) {
      statistics.deduplicated++;
      return;
    }
    final deliveredAt = now;
    statistics.delivered++;
    statistics.acknowledged++;
    statistics.recordSample(packet.createdAt, deliveredAt);
    final updated = packet.copyWith(
      state: DtnPacketState.delivered,
      ackState: DtnAckState.received,
      ackedBy: by,
      deliveredAt: deliveredAt,
    );
    _removeEnvelope(packetId);
    _insertEnvelope(updated, notify: false);
    unawaited(persistence.upsert(updated));
    _logTransition(
      DtnDiagnosticEventKind.acked,
      updated,
      details: {'by': by ?? '?'},
    );
    _publishSnapshot();
  }

  // ---- Inbound / local delivery --------------------------------------------------

  /// A packet reached this node as final destination: hand it to the upper
  /// layer and remember it as delivered-locally.
  void deliverLocally(DtnPacket packet, {DateTime? at}) {
    final now = at ?? _now();
    final existing = _envelopes[packet.packetId];
    if (existing != null && existing.isTerminal) {
      return;
    }
    if (existing != null) {
      _removeEnvelope(packet.packetId);
    }
    final updated = packet.copyWith(
      state: DtnPacketState.deliveredLocally,
      deliveredAt: now,
    );
    _insertEnvelope(updated, notify: false);
    statistics.delivered++;
    statistics.recordSample(updated.createdAt, now);
    unawaited(persistence.upsert(updated));
    _logTransition(DtnDiagnosticEventKind.delivered, updated);
    _inboundController.add(updated);
    _publishSnapshot();
  }

  /// An inbound envelope was consumed by the upper layer.
  void consume(DtnPacket packet, {DateTime? at}) {
    if (packet.state != DtnPacketState.deliveredLocally) {
      return;
    }
    _removeEnvelope(packet.packetId);
    final consumed = packet.copyWith(state: DtnPacketState.consumed);
    _insertEnvelope(consumed, notify: false);
    unawaited(persistence.deletePacket(packet.packetId));
    _logTransition(DtnDiagnosticEventKind.ackRequest, consumed);
    _publishSnapshot();
  }

  // ---- Scheduler-facing transitions ----------------------------------------------

  /// Select the next batch of envelopes to attempt, in priority order.
  List<DtnPacket> outgoingCandidates({int? limit}) {
    final list = _outgoing.toList()..sort(_deliveryOrder);
    return list.take(limit ?? config.batchLimit).toList();
  }

  /// Attempt a transmit; the scheduler asks the gateway and reports back.
  void noteAttempt(
    String packetId,
    bool succeeded, {
    String? error,
    bool permanent = false,
    bool willAck = false,
    DateTime? at,
  }) {
    final now = at ?? _now();
    final packet = _envelopes[packetId];
    if (packet == null || packet.isTerminal) {
      return;
    }
    if (succeeded) {
      _onTransmitOk(packet, willAck: willAck, at: now);
    } else {
      _onTransmitFail(packet, error: error, permanent: permanent, at: now);
    }
  }

  void _onTransmitOk(
    DtnPacket packet, {
    required bool willAck,
    required DateTime at,
  }) {
    if (packet.direction == DtnDirection.inbound) {
      return; // never scheduled
    }
    if (willAck && !packet.isAckEnvelope) {
      ackManager.expectAck(packet.packetId, at);
      final updated = packet.copyWith(
        state: DtnPacketState.awaitingAck,
        ackState: DtnAckState.awaiting,
        ackDeadlineAt: at.add(config.ackTimeout),
        lastAttemptAt: at,
      );
      _replace(packet, updated);
      _logTransition(
        DtnDiagnosticEventKind.attempt,
        updated,
        details: {'outcome': 'ok'},
      );
    } else {
      // Fire-and-forget (or relay hop): locally considered delivered.
      final updated = packet.copyWith(
        state: packet.direction == DtnDirection.relay
            ? DtnPacketState.relaying
            : DtnPacketState.delivered,
        lastAttemptAt: at,
        ackState: DtnAckState.none,
        ackedBy: packet.destination,
        deliveredAt: at,
      );
      if (updated.state == DtnPacketState.relaying) {
        _replace(packet, updated);
        statistics.relayed++;
        _logTransition(DtnDiagnosticEventKind.forwarded, updated);
      } else {
        _finishDelivered(packet, updated, at: at);
      }
    }
    _publishSnapshot();
  }

  void _onTransmitFail(
    DtnPacket packet, {
    required bool permanent,
    required DateTime at,
    String? error,
  }) {
    if (permanent) {
      final failed = packet.copyWith(
        state: DtnPacketState.failed,
        lastAttemptAt: at,
        lastError: error ?? 'permanent rejection',
      );
      _replace(packet, failed);
      _logTransition(
        DtnDiagnosticEventKind.rejectedPermanently,
        failed,
        message: error,
      );
      _publishSnapshot();
      return;
    }
    final attempt = packet.attemptCount + 1;
    if (attempt >= config.retryPolicy.limit) {
      final parked = packet.copyWith(
        state: DtnPacketState.deferred,
        attemptCount: attempt,
        lastAttemptAt: at,
        lastError: error,
        enqueuedAt: at,
      );
      _replace(packet, parked);
      statistics.parked++;
      _logTransition(
        DtnDiagnosticEventKind.parked,
        parked,
        message: 'retry limit reached',
      );
      _publishSnapshot();
      return;
    }
    final delay = config.retryPolicy.delayFor(attempt);
    final nextAttempt = at.add(delay);
    final retrying = packet.copyWith(
      state: DtnPacketState.retrying,
      attemptCount: attempt,
      lastAttemptAt: at,
      lastError: error,
      nextAttemptAt: nextAttempt,
      enqueuedAt: at,
    );
    _replace(packet, retrying);
    statistics.retried++;
    _logTransition(
      DtnDiagnosticEventKind.retried,
      retrying,
      message: error,
      details: {'nextAttempt': nextAttempt.toIso8601String()},
    );
    _publishSnapshot();
  }

  /// Retry windows that have opened.
  List<DtnPacket> retriesDue(DateTime now) => _retry
      .where((p) => p.nextAttemptAt != null && !p.nextAttemptAt!.isAfter(now))
      .toList();

  /// Move due retries back to the outgoing queue.
  void rearmRetries(List<DtnPacket> due) {
    for (final packet in due) {
      _move(packet, DtnPacketState.queued, enqueuedAt: _now());
    }
    if (due.isNotEmpty) {
      _publishSnapshot();
    }
  }

  /// Park everything outbound except critical envelopes.
  void parkAll({DateTime? at}) {
    final now = at ?? _now();
    var parked = 0;
    for (final packet in _outgoing.toList()) {
      if (packet.priority == DtnPriority.critical) {
        continue;
      }
      _move(packet, DtnPacketState.deferred, enqueuedAt: now, notify: false);
      statistics.parked++;
      parked++;
      _logTransition(
        DtnDiagnosticEventKind.parked,
        packet,
        message: 'connectivity lost',
      );
    }
    if (parked > 0) {
      _publishSnapshot();
    }
  }

  /// Re-arm every parked envelope when the network returns.
  void unparkAll({DateTime? at}) {
    final now = at ?? _now();
    var unparked = 0;
    for (final packet in _deferred.toList()) {
      _move(packet, DtnPacketState.queued, enqueuedAt: now, notify: false);
      unparked++;
      _logTransition(
        DtnDiagnosticEventKind.unparked,
        packet,
        message: 'connectivity restored',
      );
    }
    if (unparked > 0) {
      _publishSnapshot();
    }
  }

  /// A relay envelope should be tried again (topology changed).
  void rearmRelaying() {
    var rearmed = 0;
    for (final packet in _relaying.toList()) {
      _move(packet, DtnPacketState.queued, enqueuedAt: _now(), notify: false);
      rearmed++;
    }
    if (rearmed > 0) {
      _publishSnapshot();
    }
  }

  /// Expire envelopes past their TTL (sweep).
  List<DtnPacket> expiredDue(DateTime now) => _envelopes.values
      .where((p) => !p.isTerminal && p.expiresAt.isBefore(now))
      .toList();

  /// Remove [packets] as expired (called by the scheduler after the sweep).
  void expireAll(List<DtnPacket> packets, {DateTime? at}) {
    for (final packet in packets) {
      _removeEnvelope(packet.packetId);
      unawaited(persistence.deletePacket(packet.packetId));
      statistics.expired++;
      _logTransition(
        DtnDiagnosticEventKind.expired,
        packet,
        message: 'ttl ${packet.ttlSeconds}s',
      );
    }
    if (packets.isNotEmpty) {
      _publishSnapshot();
    }
  }

  /// Ack deadlines that passed — re-arm those envelopes for delivery.
  List<String> ackTimeouts(DateTime now) => ackManager.timedOut(now);

  void rearmAckTimeouts(List<String> packetIds, {DateTime? at}) {
    final now = at ?? _now();
    for (final id in packetIds) {
      final packet = _envelopes[id];
      if (packet == null || packet.isTerminal) {
        continue;
      }
      final rearmed = packet.copyWith(
        state: DtnPacketState.queued,
        ackState: DtnAckState.timedOut,
        ackDeadlineAt: null,
        enqueuedAt: now,
      );
      _replace(packet, rearmed);
      _logTransition(DtnDiagnosticEventKind.ackTimeout, rearmed);
    }
    if (packetIds.isNotEmpty) {
      _publishSnapshot();
    }
  }

  /// Update the perceived connectivity (gateway reported a change).
  void setConnectivity(DtnConnectivitySnapshot snapshot) {
    _connectivity = snapshot;
    _connectivityController.add(snapshot);
    _logTransition(
      DtnDiagnosticEventKind.connectivityChanged,
      DtnPacket(
        packetId: 'connectivity',
        source: '',
        destination: '',
        payload: const [],
        priority: DtnPriority.normal,
        direction: DtnDirection.outbound,
        ttlSeconds: 0,
        createdAt: _now(),
        expiresAt: _now(),
      ),
      details: {'reachable': snapshot.reachable},
    );
  }

  // ---- Views / snapshots ----------------------------------------------------------

  DtnQueueSnapshot snapshot() {
    var outgoing = 0, deferred = 0, retry = 0, incoming = 0;
    var relaying = 0, awaitingAck = 0, live = 0;
    for (final p in _envelopes.values) {
      if (p.isTerminal || p.state == DtnPacketState.delivered) {
        continue;
      }
      live++;
      switch (p.state) {
        case DtnPacketState.queued:
          outgoing++;
        case DtnPacketState.pendingDelivery:
          outgoing++;
        case DtnPacketState.retrying:
          retry++;
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
    return DtnQueueSnapshot(
      outgoing: outgoing,
      deferred: deferred,
      retry: retry,
      incoming: incoming,
      relaying: relaying,
      awaitingAck: awaitingAck,
      live: live,
      takenAt: _now(),
    );
  }

  // ---- Internals -----------------------------------------------------------------

  int _liveCount() => _envelopes.values.where((p) => !p.isTerminal).length;

  void _validateNew(DtnPacket packet) {
    if (packet.ttlSeconds <= 0) {
      throw DtnFailure.invalidRequest(
        packet.packetId,
        'ttlSeconds must be positive',
      );
    }
    if (packet.payload.length > 1 << 20) {
      throw DtnFailure.invalidRequest(
        packet.packetId,
        'payload exceeds 1 MiB limit',
      );
    }
    if (packet.direction == DtnDirection.inbound) {
      throw DtnFailure.invalidRequest(
        packet.packetId,
        'inbound envelopes are created by the engine, not stored',
      );
    }
  }

  void _insertEnvelope(DtnPacket packet, {bool notify = true}) {
    _envelopes[packet.packetId] = packet;
    switch (packet.state) {
      case DtnPacketState.queued:
        _outgoing.add(packet);
      case DtnPacketState.pendingDelivery:
        _outgoing.add(packet);
      case DtnPacketState.retrying:
        _retry.add(packet);
      case DtnPacketState.deferred:
        _deferred.add(packet);
      case DtnPacketState.relaying:
        _relaying.add(packet);
      case DtnPacketState.awaitingAck:
      case DtnPacketState.delivered:
      case DtnPacketState.deliveredLocally:
      case DtnPacketState.consumed:
      case DtnPacketState.failed:
      case DtnPacketState.expired:
        break;
    }
    if (notify) {
      _publishSnapshot();
    }
  }

  void _removeEnvelope(String packetId) {
    final packet = _envelopes.remove(packetId);
    if (packet == null) {
      return;
    }
    switch (packet.state) {
      case DtnPacketState.queued:
      case DtnPacketState.pendingDelivery:
        _outgoing.remove(packet);
      case DtnPacketState.retrying:
        _retry.remove(packet);
      case DtnPacketState.deferred:
        _deferred.remove(packet);
      case DtnPacketState.relaying:
        _relaying.remove(packet);
      case DtnPacketState.awaitingAck:
      case DtnPacketState.delivered:
      case DtnPacketState.deliveredLocally:
      case DtnPacketState.consumed:
      case DtnPacketState.failed:
      case DtnPacketState.expired:
        break;
    }
  }

  void _replace(DtnPacket old, DtnPacket updated, {bool publish = true}) {
    _removeEnvelope(old.packetId);
    _insertEnvelope(updated, notify: publish);
    unawaited(persistence.upsert(updated));
  }

  /// Move a packet between lifecycle queues with a state change.
  void _move(
    DtnPacket packet,
    DtnPacketState to, {
    DateTime? enqueuedAt,
    bool notify = true,
  }) {
    final updated = packet.copyWith(
      state: to,
      enqueuedAt: enqueuedAt ?? _now(),
    );
    _replace(packet, updated, publish: notify);
  }

  void _finishDelivered(
    DtnPacket old,
    DtnPacket updated, {
    required DateTime at,
  }) {
    _removeEnvelope(old.packetId);
    _insertEnvelope(updated, notify: false);
    statistics.delivered++;
    statistics.recordSample(updated.createdAt, at);
    unawaited(persistence.upsert(updated));
    _logTransition(
      DtnDiagnosticEventKind.delivered,
      updated,
      details: {'route': 'direct'},
    );
  }

  void _publishSnapshot() {
    if (!_queueController.isClosed) {
      _queueController.add(snapshot());
    }
    statistics.liveEnvelopes = _liveCount();
    statistics.publish();
  }

  void _logTransition(
    DtnDiagnosticEventKind kind,
    DtnPacket packet, {
    String? message,
    Map<String, Object?> details = const {},
  }) {
    diagnostics.logTransition(kind, packet, message: message, details: details);
  }

  /// Delivery order: priority first, then enqueue order.
  static int _deliveryOrder(DtnPacket a, DtnPacket b) {
    final byPriority = a.priority.rank.compareTo(b.priority.rank);
    if (byPriority != 0) {
      return byPriority;
    }
    final at = a.enqueuedAt ?? a.createdAt;
    final bt = b.enqueuedAt ?? b.createdAt;
    return at.compareTo(bt);
  }
}
