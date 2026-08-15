import 'dart:math';

import '../delivery/dtn_config.dart';
import '../delivery/store_forward_engine.dart';
import '../domain/dtn_envelope.dart';

/// Retry bookkeeping: when an envelope may be attempted again.
///
/// Centralizes the backoff computation ([DtnRetryPolicy]), the retry-limit
/// decision and the "which retries are due right now" query, so the engine
/// only records attempt outcomes while this manager owns retry policy.
final class RetryManager {
  RetryManager({required this.config, required this.now});

  final DtnEngineConfig config;
  final DateTime Function() now;

  /// Backoff delay for the next attempt (attempt is 1-based).
  Duration delayFor(int nextAttempt, {Random? random}) =>
      config.retryPolicy.delayFor(nextAttempt, random: random);

  /// Whether [attemptCount] has reached the retry cap.
  bool isExhausted(int attemptCount) =>
      attemptCount >= config.retryPolicy.limit;

  /// When the next attempt may happen after a failure at [failedAt].
  DateTime nextAttemptTime(
    DateTime failedAt,
    int attemptsSoFar, {
    Random? random,
  }) {
    return failedAt.add(delayFor(attemptsSoFar + 1, random: random));
  }

  /// Envelopes in retry state whose window has opened (ordered by deadline).
  List<DtnPacket> due(StoreForwardEngine engine, {DateTime? at}) {
    final current = at ?? now();
    final due = engine.retriesDue(current)
      ..sort((a, b) {
        final atime = a.nextAttemptAt ?? a.enqueuedAt ?? a.createdAt;
        final btime = b.nextAttemptAt ?? b.enqueuedAt ?? b.createdAt;
        return atime.compareTo(btime);
      });
    return due;
  }

  /// Re-arm due retries back into the outgoing queue.
  void rearm(StoreForwardEngine engine, List<DtnPacket> due) {
    engine.rearmRetries(due);
  }

  /// Immediate retry: schedule a retry that is due instantly.
  DtnPacket immediateRetry(
    StoreForwardEngine engine,
    DtnPacket packet, {
    String? error,
    DateTime? at,
  }) {
    final when = at ?? now();
    final attempt = packet.attemptCount + 1;
    final retrying = packet.copyWith(
      state: DtnPacketState.retrying,
      attemptCount: attempt,
      lastAttemptAt: when,
      lastError: error,
      nextAttemptAt: when, // due immediately
      enqueuedAt: when,
    );
    engine.reattach(retrying);
    return retrying;
  }
}

/// Per-envelope retry counters (dev diagnostics).
final class RetryTracker {
  RetryTracker({this.capacity = 512});

  final int capacity;
  final Map<String, int> _attempts = {};
  final Map<String, DateTime> _lastFailure = {};

  int attempts(String packetId) => _attempts[packetId] ?? 0;

  DateTime? lastFailure(String packetId) => _lastFailure[packetId];

  void recordAttempt(String packetId, {required bool failed, DateTime? at}) {
    _prune();
    final count = (_attempts[packetId] ?? 0) + 1;
    _attempts[packetId] = count;
    if (failed) {
      _lastFailure[packetId] = at ?? DateTime.now();
    }
  }

  void forget(String packetId) {
    _attempts.remove(packetId);
    _lastFailure.remove(packetId);
  }

  void _prune() {
    if (_attempts.length > capacity) {
      final oldest = _attempts.keys.take(_attempts.length - capacity).toList();
      for (final id in oldest) {
        _attempts.remove(id);
        _lastFailure.remove(id);
      }
    }
  }
}
