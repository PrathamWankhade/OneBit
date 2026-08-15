import 'dart:math';

import '../domain/dtn_priority.dart';

/// Retry backoff policy for failed transmissions.
final class DtnRetryPolicy {
  const DtnRetryPolicy({
    this.baseDelay = const Duration(seconds: 30),
    this.maxDelay = const Duration(hours: 1),
    this.factor = 2.0,
    this.jitterRatio = 0.1,
    this.limit = 12,
  });

  final Duration baseDelay;
  final Duration maxDelay;
  final double factor;
  final double jitterRatio;

  /// Maximum attempts before an envelope is *parked* (deferred) — never
  /// dropped: DTN treats "destination offline" as the normal condition.
  final int limit;

  /// Deterministic for a given attempt count and random seed (tests).
  Duration delayFor(int attempt, {Random? random}) {
    final base = baseDelay.inMilliseconds * pow(factor, max(0, attempt - 1));
    final capped = min(base, maxDelay.inMilliseconds.toDouble());
    final jitter = (jitterRatio * capped) * _jitter(random);
    return Duration(milliseconds: (capped + jitter).round());
  }

  double _jitter(Random? random) {
    final rng = random ?? Random();
    return (rng.nextDouble() - 0.5) * 2;
  }
}

/// Delivery budget consulted by the scheduler before each batch.
///
/// The default admits everything the batch limit allows; a future platform
/// battery implementation can throttle bursts or pause background work.
abstract interface class DtnDeliveryBudget {
  /// Whether a batch of [envelopeCount] envelopes at [priority] may be
  /// transmitted now.
  bool allow(int envelopeCount, DtnPriority priority);
}

/// The default budget: bound only by the batch limit.
final class UnboundedDeliveryBudget implements DtnDeliveryBudget {
  const UnboundedDeliveryBudget();

  @override
  bool allow(int envelopeCount, DtnPriority priority) => true;
}

/// Engine configuration (injectable for tests).
final class DtnEngineConfig {
  const DtnEngineConfig({
    this.batchLimit = 32,
    this.maxLiveEnvelopes = 10000,
    this.ackTimeout = const Duration(minutes: 5),
    this.tickInterval = const Duration(seconds: 5),
    this.retryPolicy = const DtnRetryPolicy(),
    this.budget = const UnboundedDeliveryBudget(),
  });

  /// Maximum envelopes transmitted per delivery pass.
  final int batchLimit;

  /// Hard cap on live (non-terminal) envelopes before store() fails.
  final int maxLiveEnvelopes;

  /// How long a transmitted envelope waits for its logical ack.
  final Duration ackTimeout;

  /// Floor cadence of the scheduler tick.
  final Duration tickInterval;

  final DtnRetryPolicy retryPolicy;

  final DtnDeliveryBudget budget;
}
