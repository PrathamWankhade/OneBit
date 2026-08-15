/// Immutable broadcast snapshot of delivery counters and gauges.
///
/// The engine publishes a fresh snapshot after every lifecycle-relevant
/// event; persistence into the shared `Statistics` table happens in the data
/// layer, and the dev screens consume [DtnStatisticsSnapshot.stream] (or the
/// cache in [DtnStatisticsSnapshot.latest]).
final class DtnStatisticsSnapshot {
  const DtnStatisticsSnapshot({
    required this.stored,
    required this.delivered,
    required this.acknowledged,
    required this.expired,
    required this.retried,
    required this.relayed,
    required this.recovered,
    required this.parked,
    required this.deduplicated,
    required this.liveEnvelopes,
    required this.avgDeliveryLatency,
    required this.recordedAt,
  });

  final int stored;
  final int delivered;
  final int acknowledged;
  final int expired;
  final int retried;
  final int relayed;
  final int recovered;
  final int parked;
  final int deduplicated;

  /// Number of live (non-terminal) envelopes right now.
  final int liveEnvelopes;

  /// Rolling average delivery time in seconds (null until the first sample).
  final double? avgDeliveryLatency;

  final DateTime recordedAt;

  static final empty = DtnStatisticsSnapshot(
    stored: 0,
    delivered: 0,
    acknowledged: 0,
    expired: 0,
    retried: 0,
    relayed: 0,
    recovered: 0,
    parked: 0,
    deduplicated: 0,
    liveEnvelopes: 0,
    avgDeliveryLatency: null,
    recordedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  DtnStatisticsSnapshot copyWith({
    int? stored,
    int? delivered,
    int? acknowledged,
    int? expired,
    int? retried,
    int? relayed,
    int? recovered,
    int? parked,
    int? deduplicated,
    int? liveEnvelopes,
    double? avgDeliveryLatency,
    DateTime? recordedAt,
  }) {
    return DtnStatisticsSnapshot(
      stored: stored ?? this.stored,
      delivered: delivered ?? this.delivered,
      acknowledged: acknowledged ?? this.acknowledged,
      expired: expired ?? this.expired,
      retried: retried ?? this.retried,
      relayed: relayed ?? this.relayed,
      recovered: recovered ?? this.recovered,
      parked: parked ?? this.parked,
      deduplicated: deduplicated ?? this.deduplicated,
      liveEnvelopes: liveEnvelopes ?? this.liveEnvelopes,
      avgDeliveryLatency: avgDeliveryLatency ?? this.avgDeliveryLatency,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }
}
