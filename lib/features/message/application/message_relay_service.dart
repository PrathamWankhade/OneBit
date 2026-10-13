/// I9.5 — Intermediate relay and message forwarding.
///
/// When a peer receives a message not addressed to itself, this
/// service determines whether to forward it via I8-selected next
/// hop using existing I7 transport.
///
/// ## Architecture
///
/// ```text
/// receive envelope
///       ↓
/// validate structure
///       ↓
/// destination == local?
///       ├── YES → local destination
///       └── NO  → ask I8 → transmit via I7
/// ```
///
/// ## Invariants
///
/// - Original [MessageEnvelope.messageId] is preserved across hops
/// - Original [MessageEnvelope.sourcePeerId] is preserved (relay ≠ sender)
/// - Original [MessageEnvelope.destinationPeerId] is preserved
/// - Payload is treated as opaque — never parsed or modified
/// - No retry, no persistence, no dedup, no TTL (future increments)
/// - I8 remains the authority for route selection
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/features/message/application/message_transmission_service.dart';
import 'package:onebit/features/message/models/message_envelope.dart';
import 'package:onebit/features/message/models/message_envelope_validator.dart';
import 'package:onebit/features/message/models/message_id.dart';
import 'package:onebit/features/message/models/message_state.dart';
import 'package:onebit/features/message/models/onebit_message.dart';

/// Result of a relay evaluation.
///
/// Sealed class representing the three possible outcomes when
/// processing a received message envelope.
sealed class RelayResult {
  const RelayResult();

  /// Message is addressed to the local peer — not a relay candidate.
  const factory RelayResult.localDestination() = LocalDestination;

  /// Message was forwarded to the next hop via I7 transport.
  const factory RelayResult.forwarded({
    required String nextHopPeerId,
    required int routeMetric,
  }) = Forwarded;

  /// Relay attempt failed.
  const factory RelayResult.relayFailed({
    required String reason,
  }) = RelayFailed;
}

/// The message's final destination is this peer.
class LocalDestination extends RelayResult {
  const LocalDestination();
}

/// The message was forwarded to the next hop.
class Forwarded extends RelayResult {
  const Forwarded({
    required this.nextHopPeerId,
    required this.routeMetric,
  });

  /// The peer that will handle the next hop.
  final String nextHopPeerId;

  /// The I8 route metric to the final destination.
  final int routeMetric;
}

/// The relay attempt failed.
class RelayFailed extends RelayResult {
  const RelayFailed({required this.reason});

  /// Human-readable failure reason.
  final String reason;
}

/// Diagnostic event emitted for each relay operation.
///
/// Bounded in-memory log for developer diagnostics.
class RelayEvent {
  const RelayEvent({
    required this.messageId,
    required this.sourcePeerId,
    required this.destinationPeerId,
    required this.localPeerId,
    required this.nextHopPeerId,
    required this.routeMetric,
    required this.result,
    required this.timestamp,
  });

  final MessageId messageId;
  final String sourcePeerId;
  final String destinationPeerId;
  final String localPeerId;
  final String nextHopPeerId;
  final int routeMetric;
  final RelayResult result;
  final DateTime timestamp;
}

/// Maximum number of relay diagnostic events retained in memory.
const int _maxRelayEvents = 100;

/// Intermediate relay and message forwarding service.
///
/// Receives a [MessageEnvelope], determines whether the local peer
/// is the final destination, and forwards non-local messages via
/// the existing [MessageTransmissionService].
///
/// ## Usage
///
/// ```text
/// BLE → I7 → MessageEnvelopeCodec.decode()
///        → MessageRelayService.receiveAndRelay(envelope)
///        → if local: handle locally
///        → if remote: MessageTransmissionService.transmit()
/// ```
///
/// This service does NOT:
/// - Own BLE connections (I7)
/// - Own routing algorithms (I8)
/// - Implement persistence (I9.8)
/// - Implement deduplication (I9.12)
/// - Implement TTL/hop-limit (I9.6)
///
/// ## Retry (I9.11)
///
/// A forward that fails for a *transient* reason — no route yet, next
/// hop not connected, the link dropped mid-send — is held in memory
/// and retried on an exponential backoff: the carrying hop's own
/// outbox, for traffic it does not own. Each attempt re-resolves the
/// route afresh, so a mesh that reorganised meanwhile picks up the new
/// path for free. Deterministic failures (encoding, validation, the
/// relay switch flipped off) are dropped at once. The queue is bounded
/// in count and every entry is bounded in attempts, so a destination
/// that never appears cannot grow the heap — and because the receiver
/// dedups on the message id, a retry that lands after a "failed" first
/// try is still exactly one message. A held envelope lives only as
/// long as this process does (persistence is I9.8, not here).
class MessageRelayService {
  /// I9.11.b retry cadence for held forwards: base wait, ceiling, timer
  /// tick, and the two bounds that keep a held queue honest.
  /// Overridable per service so tests never sleep out real seconds.
  static const defaultRetryBaseBackoff = Duration(seconds: 2);
  static const defaultRetryMaxBackoff = Duration(seconds: 30);
  static const defaultRetryTick = Duration(seconds: 2);
  static const defaultMaxRetryAttempts = 5;
  static const defaultMaxPendingForwards = 64;

  MessageRelayService({
    required this.localPeerId,
    required this._transmissionService,
    this.forwardingAllowed,
    this._retryBaseBackoff = defaultRetryBaseBackoff,
    this._retryMaxBackoff = defaultRetryMaxBackoff,
    this._retryTick = defaultRetryTick,
    this._maxRetryAttempts = defaultMaxRetryAttempts,
    this._maxPendingForwards = defaultMaxPendingForwards,
  });

  final String localPeerId;
  final MessageTransmissionService _transmissionService;

  /// Whether this node is currently willing to forward other peers'
  /// traffic, read from the *Relay participation* setting on each call
  /// so toggling it takes effect without a restart.
  ///
  /// Null means "always forward" (the default, and what tests use).
  final bool Function()? forwardingAllowed;

  /// I9.11.b — how long a held forward waits after a failed attempt,
  /// doubling per attempt up to [_retryMaxBackoff].
  final Duration _retryBaseBackoff;

  /// I9.11.b — ceiling for the doubling wait: transit traffic should
  /// not linger much past a minute even for a faraway destination.
  final Duration _retryMaxBackoff;

  /// I9.11.b — how often the timer looks for holds whose wait elapsed.
  final Duration _retryTick;

  /// I9.11.b — total attempts (first try included) before a held
  /// envelope is written off.
  final int _maxRetryAttempts;

  /// I9.11.b — hard cap on held envelopes; the oldest is evicted.
  final int _maxPendingForwards;

  /// Envelopes owed to the mesh, keyed by wire message id
  /// (insertion-ordered, so eviction drops the oldest hold first).
  final _pending = <String, _PendingForward>{};

  Timer? _retryTimer;
  bool _retrying = false;

  /// In-memory diagnostic event log (bounded at [_maxRelayEvents]).
  final List<RelayEvent> _events = [];

  /// Unmodifiable view of recent relay events.
  List<RelayEvent> get events => List.unmodifiable(_events);

  /// Process a received message envelope.
  ///
  /// 1. Validate envelope structure
  /// 2. Check if destination is the local peer
  /// 3. If local → return [LocalDestination]
  /// 4. If remote → forward via [MessageTransmissionService]
  ///
  /// The original envelope identity (messageId, source, destination)
  /// is preserved across all hops.
  Future<RelayResult> receiveAndRelay(MessageEnvelope envelope) async {
    // 1. Validate envelope structure.
    final validation = MessageEnvelopeValidator.validate(envelope);
    if (!validation.isValid) {
      final result = RelayFailed(
        reason: 'Invalid envelope: ${validation.reason}',
      );
      _recordEvent(envelope, result);
      return result;
    }

    // 2. Check if this peer is the final destination.
    if (envelope.destinationPeerId == localPeerId) {
      AppLogger.info(
        'Relay: message ${_shortId(envelope.messageId)} is for local peer',
      );
      _recordEvent(envelope, const LocalDestination());
      return const LocalDestination();
    }

    // 3. Honour the relay-participation setting. A node that opted out
    //    still accepts messages addressed to it, but never carries
    //    somebody else's traffic. Read on every call so flipping the
    //    switch takes effect immediately.
    if (forwardingAllowed != null && !forwardingAllowed!()) {
      const result = RelayFailed(reason: 'Relaying disabled');
      AppLogger.info(
        'Relay: ${_shortId(envelope.messageId)} dropped — relaying is off',
      );
      _recordEvent(envelope, result);
      return result;
    }

    // 4. Hop budget. The counter is checked *after* the destination test
    //    above, because spending your last hop must not stop a message
    //    arriving — only stop it travelling any further.
    if (envelope.hopLimitReached) {
      const result = RelayFailed(
        reason: 'Hop limit reached ($maxEnvelopeHops)',
      );
      AppLogger.info(
        'Relay: ${_shortId(envelope.messageId)} dropped — hop limit reached',
      );
      _recordEvent(envelope, result);
      return result;
    }

    // 5. Construct OneBitMessage preserving original identity.
    //
    // The relay node does NOT become the source. The original
    // sourcePeerId and destinationPeerId are preserved exactly.
    final message = _messageFor(envelope);

    // 6. Forward via existing I9.4 transmission service.
    //
    // This reuses the same route-lookup → device-resolve → encode
    // → BLE-send pipeline used by origin transmission. The hop counter
    // is the one thing that changes: the relay does not become the
    // source, but it does count as a hop.
    AppLogger.info(
      'Relay: forwarding ${_shortId(envelope.messageId)} '
      'from ${_shortId(envelope.sourcePeerId)} '
      'to ${_shortId(envelope.destinationPeerId)} '
      '(hop ${envelope.hopCount + 1}/$maxEnvelopeHops)',
    );

    final transmissionResult = await _transmissionService.transmit(
      message: message,
      envelope: envelope.withAdditionalHop(),
    );

    // 6. Map transmission result to relay result.
    final result = _relayResultFor(transmissionResult);

    _recordEvent(envelope, result);

    if (result is RelayFailed && _isTransient(transmissionResult)) {
      // Transient — the mesh may look different in a moment. Hold the
      // envelope exactly as received (a hop is spent per attempt, not
      // per queueing) and let the retry timer have another go.
      _holdForRetry(envelope, result.reason);
    }

    if (result is Forwarded) {
      AppLogger.info(
        'Relay: forwarded ${_shortId(envelope.messageId)} '
        'to ${_shortId(result.nextHopPeerId)} '
        '(metric=${result.routeMetric})',
      );
    } else if (result is RelayFailed) {
      AppLogger.info(
        'Relay: failed for ${_shortId(envelope.messageId)}: ${result.reason}',
      );
    }

    return result;
  }

  // ── Retry (I9.11.b) ────────────────────────────────────────────

  /// Start the timer that drains due retries.
  ///
  /// App-scoped: started with the service, stopped with it. Tests that
  /// drive [retryDueForwards] by hand never need it.
  void startRetrying() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(_retryTick, (_) {
      unawaited(retryDueForwards());
    });
  }

  /// Stop the retry timer. Held envelopes go with the service.
  void stopRetrying() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// How many envelopes are currently held for a later attempt.
  int get pendingForwardCount => _pending.length;

  /// When a held envelope is next retried — null when it is not held.
  DateTime? nextForwardRetryAt(MessageId messageId) =>
      _pending[messageId.value]?.nextAttemptAt;

  /// Give every held envelope whose wait has elapsed another attempt.
  ///
  /// Called by the timer; safe to call by hand. Route and device are
  /// re-resolved inside [MessageTransmissionService] on each attempt,
  /// so a mesh that reorganised meanwhile is picked up for free.
  Future<void> retryDueForwards() async {
    if (_retrying) return;
    _retrying = true;
    try {
      final now = DateTime.now();
      final due = _pending.entries
          .where((entry) => !entry.value.nextAttemptAt.isAfter(now))
          .map((entry) => entry.key)
          .toList(growable: false);

      for (final key in due) {
        final held = _pending[key];
        if (held == null) continue;

        // The participation switch may have flipped while the envelope
        // waited; a node that opted out stops mid-queue too.
        if (forwardingAllowed != null && !forwardingAllowed!()) {
          _pending.remove(key);
          _recordEvent(
            held.envelope,
            const RelayFailed(reason: 'Relaying disabled'),
          );
          continue;
        }

        AppLogger.info(
          'Relay: retrying ${_shortId(held.envelope.messageId)} '
          '(attempt ${held.attempts + 1}/$_maxRetryAttempts)',
        );

        TransmissionResult transmissionResult;
        try {
          transmissionResult = await _transmissionService.transmit(
            message: _messageFor(held.envelope),
            envelope: held.envelope.withAdditionalHop(),
          );
        } catch (e) {
          // A thrown send is a transient one as far as the mesh cares.
          AppLogger.error(
            'Relay: retry send failed for ${_shortId(held.envelope.messageId)}',
            e,
          );
          transmissionResult = const TransmissionResult.transportFailed(
            reason: 'retry threw',
          );
        }

        if (_isTransient(transmissionResult)) {
          // Still not there. Spend the attempt and push the wait out —
          // or, budget spent, write the envelope off for good.
          held.attempts += 1;
          if (held.attempts >= _maxRetryAttempts) {
            _pending.remove(key);
            final gaveUp = RelayFailed(
              reason: 'Gave up after ${held.attempts} attempts',
            );
            _recordEvent(held.envelope, gaveUp);
            AppLogger.info(
              'Relay: dropping ${_shortId(held.envelope.messageId)} '
              '— ${gaveUp.reason}',
            );
          } else {
            held.nextAttemptAt =
                DateTime.now().add(_backoffFor(held.attempts));
          }
          continue;
        }

        // Terminal: it went, or it failed for good. Either way the hold
        // is over — only the outcome of the *last* attempt is recorded,
        // so a queue under churn cannot flood the event log.
        _pending.remove(key);
        final result = _relayResultFor(transmissionResult);
        _recordEvent(held.envelope, result);
        if (result is Forwarded) {
          AppLogger.info(
            'Relay: forwarded ${_shortId(held.envelope.messageId)} '
            'to ${_shortId(result.nextHopPeerId)} '
            '(metric=${result.routeMetric})',
          );
        } else if (result is RelayFailed) {
          AppLogger.info(
            'Relay: failed for ${_shortId(held.envelope.messageId)}: '
            '${result.reason}',
          );
        }
      }
    } finally {
      _retrying = false;
    }
  }

  /// Hold a freshly failed forward for a later attempt — the first try
  /// is already spent, so the entry opens at one attempt. A duplicate
  /// arrival of an id already held is ignored: upstream retrying at us
  /// must not double the queue.
  void _holdForRetry(MessageEnvelope envelope, String reason) {
    final key = envelope.messageId.value;
    if (_pending.containsKey(key)) return;

    if (_pending.length >= _maxPendingForwards) {
      _pending.remove(_pending.keys.first);
    }

    _pending[key] = _PendingForward(
      envelope: envelope,
      attempts: 1,
      nextAttemptAt: DateTime.now().add(_backoffFor(1)),
    );
    AppLogger.info(
      'Relay: holding ${_shortId(envelope.messageId)} for retry — $reason',
    );
  }

  /// Whether a failure may fix itself if we simply try again later:
  /// the mesh was not ready. Encoding and validation failures never
  /// will be.
  bool _isTransient(TransmissionResult result) => switch (result) {
        TransmissionNoRoute() ||
        TransmissionNextHopUnavailable() ||
        TransmissionTransportFailed() =>
          true,
        _ => false,
      };

  /// The wait after [attempts] failed attempts: the base delay doubled
  /// per attempt, clamped to the ceiling.
  Duration _backoffFor(int attempts) {
    var delayMs = _retryBaseBackoff.inMilliseconds;
    final maxMs = _retryMaxBackoff.inMilliseconds;
    for (var i = 1; i < attempts && delayMs < maxMs; i++) {
      delayMs *= 2;
    }
    return Duration(milliseconds: math.min(delayMs, maxMs));
  }

  /// The transit record for an envelope: identity preserved exactly —
  /// the relay never becomes the source.
  OneBitMessage _messageFor(MessageEnvelope envelope) => OneBitMessage(
        id: envelope.messageId,
        sourcePeerId: envelope.sourcePeerId,
        destinationPeerId: envelope.destinationPeerId,
        state: MessageState.created,
        createdAt: DateTime.now().toUtc(),
        payloadSizeBytes: envelope.payload.length,
      );

  /// Map a transmission result to the relay's vocabulary.
  RelayResult _relayResultFor(TransmissionResult transmissionResult) =>
      switch (transmissionResult) {
        TransmissionSent(:final nextHopPeerId, :final routeMetric) =>
          Forwarded(
            nextHopPeerId: nextHopPeerId,
            routeMetric: routeMetric,
          ),
        TransmissionNoRoute() => const RelayFailed(reason: 'No route'),
        TransmissionNextHopUnavailable(:final nextHopPeerId) => RelayFailed(
          reason: 'Next hop $nextHopPeerId unavailable',
        ),
        TransmissionTransportFailed(:final reason) => RelayFailed(
          reason: 'Transport failed: $reason',
        ),
        TransmissionEncodingFailed(:final reason) => RelayFailed(
          reason: 'Encoding failed: $reason',
        ),
        TransmissionRejected(:final reason) => RelayFailed(
          reason: 'Rejected: $reason',
        ),
      };

  /// Record a diagnostic event (bounded at [_maxRelayEvents]).
  void _recordEvent(MessageEnvelope envelope, RelayResult result) {
    _events.add(RelayEvent(
      messageId: envelope.messageId,
      sourcePeerId: envelope.sourcePeerId,
      destinationPeerId: envelope.destinationPeerId,
      localPeerId: localPeerId,
      nextHopPeerId: '',
      routeMetric: 0,
      result: result,
      timestamp: DateTime.now().toUtc(),
    ));

    // Evict oldest events when limit exceeded.
    if (_events.length > _maxRelayEvents) {
      _events.removeRange(0, _events.length - _maxRelayEvents);
    }
  }

  /// Truncate a PeerId for log output.
  String _shortId(dynamic id) {
    final s = id.toString();
    if (s.length >= 8) return '${s.substring(0, 8)}...';
    return s;
  }
}

/// A forward owed to the mesh, waiting on its backoff (I9.11.b).
class _PendingForward {
  _PendingForward({
    required this.envelope,
    required this.attempts,
    required this.nextAttemptAt,
  });

  /// The envelope exactly as received — a hop is spent per attempt,
  /// not per queueing, so the retried send carries exactly one more
  /// hop than the original arrival did.
  final MessageEnvelope envelope;

  /// Attempts spent so far (the first try counts).
  int attempts;

  DateTime nextAttemptAt;
}
