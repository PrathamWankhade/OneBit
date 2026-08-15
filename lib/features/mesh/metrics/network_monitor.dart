import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_neighbor.dart';
import 'package:onebit/features/mesh/domain/mesh_network_status.dart';
import 'package:onebit/features/mesh/domain/mesh_route.dart';
import 'package:onebit/features/mesh/domain/mesh_statistics.dart';

/// Aggregates the mesh health metrics for [MeshNetworkStatus].
///
/// Pure computation over the current tables plus the statistics tracker's
/// rolling rates; the engine calls [status] on each sweep.
final class NetworkMonitor {
  NetworkMonitor({
    required this._neighbors,
    required this._primaryRoutes,
    required this._engineState,
    required this._statistics,
    required this._partitions,
  });

  final List<MeshNeighbor> Function() _neighbors;
  final List<MeshRoute> Function() _primaryRoutes;
  final MeshEngineState Function() _engineState;
  final MeshStatistics Function() _statistics;
  final int Function() _partitions;

  /// Computes the current [MeshNetworkStatus].
  MeshNetworkStatus status(DateTime now) {
    final neighborList = _neighbors();
    final routes = _primaryRoutes();
    final stats = _statistics();

    var active = 0;
    var disconnected = 0;
    var rssiSum = 0.0;
    var qualitySum = 0.0;
    var qualityCount = 0;
    for (final neighbor in neighborList) {
      final connected =
          neighbor.connectionState == MeshLinkState.connected ||
          neighbor.connectionState == MeshLinkState.advertising;
      if (connected) {
        active++;
        rssiSum += neighbor.smoothedRssiDb;
        qualitySum += neighbor.linkQuality;
        qualityCount++;
      } else {
        disconnected++;
      }
    }

    var hopSum = 0;
    for (final route in routes) {
      hopSum += route.hopCount;
    }

    final stability = _stability(stats.neighborJoins + stats.neighborLeaves);

    return MeshNetworkStatus(
      engineState: _engineState(),
      activeNeighborCount: active,
      knownNodeCount: neighborList.length + routes.length,
      disconnectedNeighborCount: disconnected,
      averageRssiDb: qualityCount == 0 ? null : rssiSum / qualityCount,
      averageHopCount: routes.isEmpty ? null : hopSum / routes.length,
      relayedPacketsPerMinute: stats.packetsPerMinute,
      connectionQuality: qualityCount == 0 ? 0.0 : qualitySum / qualityCount,
      meshStability: stability,
      packetSuccessRate: stats.packetSuccessRate,
      partitionCount: _partitions(),
      observedAt: now,
    );
  }

  /// `1 - (churn / budget)`, clamped; 16 join/leave events per minute is
  /// considered fully unstable.
  double _stability(int churn) {
    final raw = 1.0 - churn / 16.0;
    return raw.clamp(0.0, 1.0);
  }
}
