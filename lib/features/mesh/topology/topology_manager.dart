import 'package:onebit/features/mesh/domain/mesh_neighbor.dart';
import 'package:onebit/features/mesh/domain/mesh_route.dart';
import 'package:onebit/features/mesh/domain/mesh_topology.dart';

/// Builds the local topology view from neighbor and route tables.
///
/// The view is always local: the node itself, live neighbors, and the links
/// it can observe (neighbor edges + route edges to remote destinations).
/// [TopologySnapshot.partitions] counts connected components among the
/// observed node set — a "> 1" reading means the local node sees islands
/// reachable through different relays, which is the earliest signal of a
/// broken mesh region.
final class TopologyManager {
  TopologyManager({
    required this.localNodeId,
    required this._neighbors,
    required this._primaryRoutes,
    required this._now,
  });

  final String localNodeId;
  final List<MeshNeighbor> Function() _neighbors;
  final List<MeshRoute> Function() _primaryRoutes;
  final DateTime Function() _now;

  /// Recomputes and returns the current snapshot.
  TopologySnapshot snapshot() {
    final now = _now();
    final neighborList = _neighbors();
    final routes = _primaryRoutes();

    final nodes = <String, ({int? rssiDb, int? hops, bool local})>{};
    nodes[localNodeId] = (rssiDb: null, hops: null, local: true);
    for (final neighbor in neighborList) {
      nodes[neighbor.nodeId] = (
        rssiDb: neighbor.smoothedRssiDb.round(),
        hops: neighbor.hopEstimate,
        local: false,
      );
    }

    final links = <TopologyLink>[];
    final adjacency = <String, Set<String>>{};

    void addEdge(String a, String b, double quality) {
      final (first, second) = a.compareTo(b) < 0 ? (a, b) : (b, a);
      links.add(TopologyLink(nodeA: first, nodeB: second, quality: quality));
      adjacency.putIfAbsent(first, () => {}).add(second);
      adjacency.putIfAbsent(second, () => {}).add(first);
    }

    for (final neighbor in neighborList) {
      nodes[neighbor.nodeId] ??= (
        rssiDb: neighbor.smoothedRssiDb.round(),
        hops: neighbor.hopEstimate,
        local: false,
      );
      addEdge(localNodeId, neighbor.nodeId, neighbor.linkQuality);
    }
    for (final route in routes) {
      nodes[route.destination] ??= (
        rssiDb: null,
        hops: route.hopCount,
        local: false,
      );
      nodes[route.nextHop] ??= (rssiDb: null, hops: null, local: false);
      addEdge(route.nextHop, route.destination, route.quality);
    }

    final nodeList =
        nodes.entries
            .map(
              (entry) => TopologyNode(
                nodeId: entry.key,
                isLocal: entry.value.local,
                rssiDb: entry.value.rssiDb,
                hopCount: entry.value.hops,
              ),
            )
            .toList()
          ..sort((a, b) => a.nodeId.compareTo(b.nodeId));

    return TopologySnapshot(
      nodes: nodeList,
      links: links,
      partitions: _partitionCount(adjacency, nodes.keys),
      observedAt: now,
    );
  }

  int _partitionCount(
    Map<String, Set<String>> adjacency,
    Iterable<String> nodeIds,
  ) {
    final visited = <String>{};
    var partitions = 0;
    for (final nodeId in nodeIds.toList()..sort()) {
      if (visited.contains(nodeId)) continue;
      partitions++;
      final queue = [nodeId];
      visited.add(nodeId);
      while (queue.isNotEmpty) {
        final current = queue.removeLast();
        for (final next in adjacency[current] ?? const <String>{}) {
          if (visited.add(next)) queue.add(next);
        }
      }
    }
    return partitions;
  }
}
