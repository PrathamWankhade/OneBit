import 'package:onebit/features/mesh/domain/mesh_diagnostics.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_neighbor.dart';
import 'package:onebit/features/mesh/domain/mesh_network_status.dart';
import 'package:onebit/features/mesh/domain/mesh_route.dart';
import 'package:onebit/features/mesh/domain/mesh_statistics.dart';
import 'package:onebit/features/mesh/domain/mesh_topology.dart';

/// Assembles [MeshDiagnostics] from live engine state.
///
/// Pure formatting + memory estimation; recomputed on every sweep tick so
/// the inspector is always fresh.
final class MeshDiagnosticsBuilder {
  MeshDiagnosticsBuilder({
    required this.localNodeId,
    required this._engineState,
    required this._radioState,
    required this._neighbors,
    required this._routes,
    required this._topology,
    required this._statistics,
    required this._network,
    required this._duplicateCache,
    required this._trackedRssiNodes,
  });

  final String localNodeId;
  final MeshEngineState Function() _engineState;
  final MeshRadioState Function() _radioState;
  final List<MeshNeighbor> Function() _neighbors;
  final List<MeshRoute> Function() _routes;
  final TopologySnapshot Function() _topology;
  final MeshStatistics Function() _statistics;
  final MeshNetworkStatus Function() _network;
  final DuplicateCacheStats Function() _duplicateCache;
  final int Function() _trackedRssiNodes;

  MeshDiagnostics build() {
    final neighbors = _neighbors();
    final routes = _routes();
    final statistics = _statistics();

    final neighborLines = neighbors.map((neighbor) {
      final distance = neighbor.distanceEstimateMeters == null
          ? '— m'
          : '${neighbor.distanceEstimateMeters!.toStringAsFixed(1)} m';
      return '${neighbor.nodeId} '
          'rssi=${neighbor.smoothedRssiDb.toStringAsFixed(1)} '
          '$distance '
          'state=${neighbor.connectionState.name}';
    }).toList();

    final routeLines = routes.map((route) {
      return '${route.destination} → ${route.nextHop} '
          '(hops ${route.hopCount}, cost ${route.cost.toStringAsFixed(2)})';
    }).toList();

    return MeshDiagnostics(
      localNodeId: localNodeId,
      engineState: _engineState(),
      radioState: _radioState(),
      startedAt: statistics.startedAt,
      neighborSummary: neighborLines,
      routeSummary: routeLines,
      topology: _topology(),
      statistics: statistics,
      networkStatus: _network(),
      duplicateCache: _duplicateCache(),
      memoryEstimateBytes: _estimateMemory(neighbors.length, routes.length),
      rssiHistoryNodes: _trackedRssiNodes(),
    );
  }

  /// Rough approximation of the engine's map overhead (bytes).
  int _estimateMemory(int neighborCount, int routeCount) {
    const overheadPerEntry = 160;
    return (neighborCount + routeCount) * overheadPerEntry + 2048;
  }
}
