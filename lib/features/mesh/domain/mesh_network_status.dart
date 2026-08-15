import 'mesh_engine_state.dart';

/// Rolling health snapshot of the local mesh, computed by the network
/// monitor on every sweep tick.
final class MeshNetworkStatus {
  const MeshNetworkStatus({
    required this.engineState,
    required this.activeNeighborCount,
    required this.knownNodeCount,
    required this.disconnectedNeighborCount,
    required this.averageRssiDb,
    required this.averageHopCount,
    required this.relayedPacketsPerMinute,
    required this.connectionQuality,
    required this.meshStability,
    required this.packetSuccessRate,
    required this.partitionCount,
    required this.observedAt,
  });

  final MeshEngineState engineState;

  /// Neighbors currently in a connected/advertising state.
  final int activeNeighborCount;

  /// Total nodes this node knows (neighbors + routed destinations).
  final int knownNodeCount;

  /// Neighbors whose link dropped but the entry is still cached.
  final int disconnectedNeighborCount;

  /// Mean smoothed RSSI across live neighbors; `null` when none.
  final double? averageRssiDb;

  /// Mean hop count across current primary routes.
  final double? averageHopCount;

  /// Forwards per minute (rolling).
  final int relayedPacketsPerMinute;

  /// Blend of mean link quality and link up-time (0..1).
  final double connectionQuality;

  /// `1 - (join+leave churn / window)` (0..1); 1 = perfectly stable.
  final double meshStability;

  /// Share of handled traffic that was not dropped (0..1); `null` idle.
  final double? packetSuccessRate;

  /// Components from the local topology view.
  final int partitionCount;

  final DateTime observedAt;

  @override
  String toString() =>
      'MeshNetworkStatus(active $activeNeighborCount, '
      'known $knownNodeCount, avgRssi $averageRssiDb, '
      'stability ${meshStability.toStringAsFixed(2)})';
}
