import '../domain/dtn_envelope.dart';

/// A candidate relay node discovered via mesh/neighborhood.
///
/// Immutable snapshot of a neighbor's forwarding suitability at a moment in
/// time. Used by [ForwardingEngine] to score and select the best next hop.
final class RelayCandidate {
  const RelayCandidate({
    required this.nodeId,
    required this.rssiDbm,
    required this.estimatedHops,
    required this.trustScore,
    required this.deliverySuccessRate,
    required this.lastSeenAt,
    this.metadata = const {},
  });

  /// Unique node identifier.
  final String nodeId;

  /// Received Signal Strength Indicator in dBm (higher = stronger, closer).
  final int rssiDbm;

  /// Estimated hop count from this candidate to the final destination.
  final int estimatedHops;

  /// Trust score [0.0, 1.0] based on identity verification, behavior history.
  final double trustScore;

  /// Historical delivery success rate [0.0, 1.0] for packets forwarded through
  /// this neighbor.
  final double deliverySuccessRate;

  /// When this candidate was last observed.
  final DateTime lastSeenAt;

  /// Opaque metadata for policy extensions.
  final Map<String, Object?> metadata;

  /// Whether the candidate is considered healthy for forwarding.
  bool get isHealthy =>
      trustScore >= 0.3 &&
      deliverySuccessRate >= 0.3 &&
      estimatedHops > 0 &&
      estimatedHops <= 8;

  /// Create a candidate with updated metrics (immutable update).
  RelayCandidate copyWith({
    int? rssiDbm,
    int? estimatedHops,
    double? trustScore,
    double? deliverySuccessRate,
    DateTime? lastSeenAt,
    Map<String, Object?>? metadata,
  }) {
    return RelayCandidate(
      nodeId: nodeId,
      rssiDbm: rssiDbm ?? this.rssiDbm,
      estimatedHops: estimatedHops ?? this.estimatedHops,
      trustScore: trustScore ?? this.trustScore,
      deliverySuccessRate: deliverySuccessRate ?? this.deliverySuccessRate,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() =>
      'RelayCandidate($nodeId rssi=$rssiDbm hops=$estimatedHops '
      'trust=${trustScore.toStringAsFixed(2)} '
      'success=${deliverySuccessRate.toStringAsFixed(2)})';
}

/// Policy interface for scoring and selecting relay candidates.
abstract interface class RelayPolicy {
  /// Score a candidate for a specific envelope. Higher = better.
  double score(RelayCandidate candidate, DtnPacket envelope);

  /// Whether a candidate is strictly better than the current relay.
  bool isBetter(
    RelayCandidate candidate,
    RelayCandidate current,
    DtnPacket envelope,
  );

  /// Default policy combining hop count, RSSI, trust, and delivery history.
  static const RelayPolicy defaultPolicy = _DefaultRelayPolicy();
}

final class _DefaultRelayPolicy implements RelayPolicy {
  const _DefaultRelayPolicy();

  @override
  double score(RelayCandidate c, DtnPacket e) {
    if (!c.isHealthy) {
      return double.negativeInfinity;
    }
    // Weights: hop count (40%), RSSI (25%), trust (20%), history (15%).
    // Normalize each to [0,1].
    final hopScore = (8 - c.estimatedHops).clamp(0, 7) / 7.0;
    final rssiScore = ((c.rssiDbm + 100).clamp(0, 50) / 50.0).clamp(0.0, 1.0);
    final trustScore = c.trustScore.clamp(0.0, 1.0);
    final historyScore = c.deliverySuccessRate.clamp(0.0, 1.0);
    return 0.40 * hopScore +
        0.25 * rssiScore +
        0.20 * trustScore +
        0.15 * historyScore;
  }

  @override
  bool isBetter(
    RelayCandidate candidate,
    RelayCandidate current,
    DtnPacket envelope,
  ) {
    if (!candidate.isHealthy) {
      return false;
    }
    if (!current.isHealthy) {
      return true;
    }
    const margin = 0.05; // 5% improvement threshold to avoid flapping
    return score(candidate, envelope) > score(current, envelope) + margin;
  }
}
