import 'mesh_engine_state.dart';

/// An immutable snapshot of a known neighbor node.
///
/// Immutable values produced by [NeighborTable]: every observation creates a
/// new [MeshNeighbor]. All fields are local observations — no global state.
final class MeshNeighbor {
  const MeshNeighbor({
    required this.nodeId,
    required this.firstSeen,
    required this.lastSeen,
    required this.latestRssiDb,
    required this.smoothedRssiDb,
    required this.connectionState,
    this.distanceEstimateMeters,
    this.hopEstimate = 1,
    this.trustStatus = MeshTrustStatus.unknown,
    this.capabilities = const {MeshCapability.relay, MeshCapability.router},
    this.advertisementTimestamp,
    this.lastAdvertisementSequence,
  });

  /// Stable neighbor identifier (device address until the identity phase).
  final String nodeId;

  /// First time this node was seen.
  final DateTime firstSeen;

  /// Most recent observation.
  final DateTime lastSeen;

  /// Raw latest RSSI in dBm (for charting and raw feed).
  final int latestRssiDb;

  /// EMA-smoothed RSSI in dBm; the stable signal for link-quality metrics.
  final double smoothedRssiDb;

  /// Estimated distance in metres from the log-distance model.
  final double? distanceEstimateMeters;

  /// Current link lifecycle.
  final MeshLinkState connectionState;

  /// Best-known hop count to reach this node (1 for direct neighbors).
  final int hopEstimate;

  /// Trust classification; reserved for the identity phase.
  final MeshTrustStatus trustStatus;

  /// Advertised capabilities.
  final Set<MeshCapability> capabilities;

  /// When the latest advertisement for this node was observed.
  final DateTime? advertisementTimestamp;

  /// Sequence of the latest observed advertisement, when reported.
  final int? lastAdvertisementSequence;

  /// Link quality in `0..1` derived from the smoothed RSSI: ≈1 at -50 dBm,
  /// 0 at -90 dBm.
  double get linkQuality {
    final raw = (smoothedRssiDb + 90) / 40;
    return raw.clamp(0.0, 1.0);
  }

  MeshNeighbor copyWith({
    DateTime? firstSeen,
    DateTime? lastSeen,
    int? latestRssiDb,
    double? smoothedRssiDb,
    double? distanceEstimateMeters,
    MeshLinkState? connectionState,
    int? hopEstimate,
    MeshTrustStatus? trustStatus,
    Set<MeshCapability>? capabilities,
    DateTime? advertisementTimestamp,
    int? lastAdvertisementSequence,
  }) {
    return MeshNeighbor(
      nodeId: nodeId,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      latestRssiDb: latestRssiDb ?? this.latestRssiDb,
      smoothedRssiDb: smoothedRssiDb ?? this.smoothedRssiDb,
      distanceEstimateMeters:
          distanceEstimateMeters ?? this.distanceEstimateMeters,
      connectionState: connectionState ?? this.connectionState,
      hopEstimate: hopEstimate ?? this.hopEstimate,
      trustStatus: trustStatus ?? this.trustStatus,
      capabilities: capabilities ?? this.capabilities,
      advertisementTimestamp:
          advertisementTimestamp ?? this.advertisementTimestamp,
      lastAdvertisementSequence:
          lastAdvertisementSequence ?? this.lastAdvertisementSequence,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MeshNeighbor && other.nodeId == nodeId;

  @override
  int get hashCode => nodeId.hashCode;

  @override
  String toString() =>
      'MeshNeighbor($nodeId, smoothed $smoothedRssiDb dBm, '
      '${connectionState.name})';
}
