import 'mesh_engine_state.dart';
import 'mesh_network_status.dart';
import 'mesh_statistics.dart';
import 'mesh_topology.dart';

/// A fully-expanded view over every engine subsystem, built on demand by
/// the diagnostics inspector and surfaced to the developer dashboard.
final class MeshDiagnostics {
  const MeshDiagnostics({
    required this.localNodeId,
    required this.engineState,
    required this.radioState,
    required this.startedAt,
    required this.neighborSummary,
    required this.routeSummary,
    required this.topology,
    required this.statistics,
    required this.networkStatus,
    required this.duplicateCache,
    required this.memoryEstimateBytes,
    required this.rssiHistoryNodes,
  });

  final String localNodeId;
  final MeshEngineState engineState;
  final MeshRadioState radioState;
  final DateTime startedAt;

  /// One line per known neighbor.
  final List<String> neighborSummary;

  /// One line per primary route.
  final List<String> routeSummary;

  final TopologySnapshot topology;
  final MeshStatistics statistics;
  final MeshNetworkStatus networkStatus;

  /// Duplicate-detection cache health.
  final DuplicateCacheStats duplicateCache;

  /// Rough heap estimate of the engine's maps, in bytes.
  final int memoryEstimateBytes;

  /// Node ids that currently keep RSSI history.
  final int rssiHistoryNodes;

  /// Human-readable, one-line-per-subsystem dump for the diagnostics panel.
  List<String> get lines => [
    'engine: ${engineState.name} radio: ${radioState.name}',
    'node: $localNodeId',
    'neighbors: ${neighborSummary.length} routes: ${routeSummary.length} '
        'partitions: ${topology.partitions}',
    ...neighborSummary,
    ...routeSummary,
    'stats: $statistics',
    'network: $networkStatus',
    'dupCache: $duplicateCache',
    'mem≈$memoryEstimateBytes B',
  ];

  @override
  String toString() =>
      'MeshDiagnostics('
      '${neighborSummary.length} neighbors, ${routeSummary.length} routes)';
}

/// Bounded-cache health, surfaced in diagnostics and the dev UI.
final class DuplicateCacheStats {
  const DuplicateCacheStats({
    required this.capacity,
    required this.entries,
    required this.hits,
    required this.evictions,
    required this.ttlSeconds,
  });

  final int capacity;
  final int entries;
  final int hits;
  final int evictions;
  final int ttlSeconds;

  @override
  String toString() => '$entries/$capacity (hits $hits, evicted $evictions)';
}
