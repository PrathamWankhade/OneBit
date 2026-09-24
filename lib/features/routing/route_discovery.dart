/// I8.6 — Route discovery via local graph search.
///
/// Given the topology knowledge established by I8.4 and the direct
/// neighbor/reachability state from I8.2/I8.3, this service discovers
/// paths to indirect logical destinations.
///
/// ## Algorithm
///
/// Uses breadth-first search (BFS) over the topology graph:
///
/// ```text
/// Local node
///     ↓ (direct neighbors from I8.2/I8.3)
/// Reachable neighbor B
///     ↓ (B's advertised neighbors from I8.4)
/// Indirect destination C
/// ```
///
/// ## Graph Model
///
/// Nodes = PeerIds (cryptographic identities)
/// Edges = topology relationships:
///   - Local → direct neighbor (from I8.2/I8.3)
///   - Remote source → advertised neighbor (from I8.4)
///
/// ## What This Does NOT Do
///
/// - Does not create BLE connections
/// - Does not establish sessions
/// - Does not authenticate peers
/// - Does not propagate trust
/// - Does not forward messages
/// - Does not implement route selection policy (I8.7)
/// - Does not expire routes (I8.8)
/// - Does not handle route failure (I8.9)
library;

import 'dart:collection';

import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/routing_limits.dart';
import 'package:onebit/features/routing/topology_repository.dart';

/// Result of a route discovery attempt.
///
/// Encapsulates the three possible outcomes:
/// - A route was found
/// - No route exists
/// - The request was invalid
class DiscoveryResult {
  /// A route was successfully discovered.
  const DiscoveryResult.found(this.route)
      : status = DiscoveryStatus.found;

  /// No path exists from local node to destination.
  const DiscoveryResult.notFound()
      : route = null,
        status = DiscoveryStatus.notFound;

  /// The destination peer ID was invalid (empty).
  const DiscoveryResult.invalidDestination()
      : route = null,
        status = DiscoveryStatus.invalidDestination;

  /// The discovered route, if found.
  final Route? route;

  /// The discovery status.
  final DiscoveryStatus status;

  /// Whether a route was found.
  bool get isFound => status == DiscoveryStatus.found;

  /// Whether no route exists.
  bool get isNotFound => status == DiscoveryStatus.notFound;

  /// Whether the destination was invalid.
  bool get isInvalid => status == DiscoveryStatus.invalidDestination;
}

/// The possible outcomes of a route discovery attempt.
enum DiscoveryStatus {
  /// A route was found.
  found,

  /// No route exists.
  notFound,

  /// The destination was invalid.
  invalidDestination,
}

/// Route discovery service — determines paths through the topology graph.
///
/// Consumes existing I8.4 topology knowledge and I8.2/I8.3 local
/// neighbor state. Does not own any transport, connection, or session
/// resources.
class RouteDiscovery {
  RouteDiscovery({
    required this._topologyRepository,
    required this._getReachableNeighbors,
  });

  final TopologyRepository _topologyRepository;
  final Set<String> Function() _getReachableNeighbors;

  /// Discover a route to [destinationPeerId].
  ///
  /// Performs a BFS traversal of the topology graph starting from the
  /// local node, using only currently reachable direct neighbors as
  /// first hops.
  ///
  /// Returns a [DiscoveryResult] indicating whether a route was found,
  /// no route exists, or the destination was invalid.
  ///
  /// This is a pure read operation — it does not create connections,
  /// sessions, authentication, trust, or modify the Route Table.
  DiscoveryResult discoverRoute({
    required String localPeerId,
    required String destinationPeerId,
  }) {
    // Validate destination.
    if (destinationPeerId.isEmpty) {
      return const DiscoveryResult.invalidDestination();
    }

    // Self-destination: no route needed.
    if (destinationPeerId == localPeerId) {
      return const DiscoveryResult.notFound();
    }

    // Get currently reachable direct neighbors.
    final reachableNeighbors = _getReachableNeighbors();

    // If no reachable neighbors, no indirect route is possible.
    if (reachableNeighbors.isEmpty) {
      return const DiscoveryResult.notFound();
    }

    // Check direct route first.
    if (reachableNeighbors.contains(destinationPeerId)) {
      final now = DateTime.now();
      return DiscoveryResult.found(Route(
        destinationPeerId: destinationPeerId,
        nextHopPeerId: destinationPeerId,
        metric: 1,
        state: RouteState.active,
        source: RouteSource.direct,
        createdAt: now,
        lastValidatedAt: now,
      ));
    }

    // Build adjacency list from topology knowledge.
    final adjacency = _buildAdjacency();

    // BFS traversal.
    return _bfs(
      localPeerId: localPeerId,
      destinationPeerId: destinationPeerId,
      reachableNeighbors: reachableNeighbors,
      adjacency: adjacency,
    );
  }

  /// Build adjacency list from topology knowledge.
  ///
  /// The adjacency map represents:
  /// - Local → direct neighbor (edges from local node to reachable neighbors)
  /// - Remote source → advertised neighbor (edges from remote sources)
  ///
  /// Returns a map from PeerId to sorted list of neighbor PeerIds.
  Map<String, List<String>> _buildAdjacency() {
    final adjacency = <String, List<String>>{};

    // Add local direct neighbor edges.
    final localNeighbors = _topologyRepository.localNeighborIds;
    for (final neighbor in localNeighbors) {
      adjacency.putIfAbsent(neighbor, () => []);
    }

    // Add remote advertised topology edges.
    for (final entry in _topologyRepository.remoteEntries) {
      final source = entry.sourceIdentity;
      adjacency.putIfAbsent(source, () => []);
      for (final neighbor in entry.neighborPeerIds) {
        adjacency[source]!.add(neighbor);
      }
    }

    // Sort neighbor lists for deterministic traversal.
    for (final key in adjacency.keys) {
      adjacency[key]!.sort();
    }

    return adjacency;
  }

  /// BFS traversal to find shortest path to destination.
  ///
  /// Tracks first hop from local node to construct the final route.
  DiscoveryResult _bfs({
    required String localPeerId,
    required String destinationPeerId,
    required Set<String> reachableNeighbors,
    required Map<String, List<String>> adjacency,
  }) {
    // Visited set to prevent cycles, bounded by maxDiscoveryVisited.
    final visited = <String>{localPeerId};

    // First-hop mapping: peerId → first hop from local node.
    final firstHop = <String, String>{};

    // BFS queue: (currentPeerId, metric).
    final queue = Queue<(String, int)>();

    // Seed BFS with reachable direct neighbors, sorted for determinism.
    final sortedNeighbors = reachableNeighbors.toList()..sort();
    for (final neighbor in sortedNeighbors) {
      if (!visited.contains(neighbor)) {
        visited.add(neighbor);
        firstHop[neighbor] = neighbor;
        queue.add((neighbor, 1));
      }
    }

    // BFS loop.
    while (queue.isNotEmpty) {
      // Bound visited set size.
      if (visited.length >= RoutingLimits.maxDiscoveryVisited) break;

      final (current, metric) = queue.removeFirst();

      // Check if we reached the destination.
      if (current == destinationPeerId) {
        final now = DateTime.now();
        return DiscoveryResult.found(Route(
          destinationPeerId: destinationPeerId,
          nextHopPeerId: firstHop[current]!,
          metric: metric,
          state: RouteState.active,
          source: RouteSource.advertised,
          createdAt: now,
          lastValidatedAt: now,
        ));
      }

      // Bound search depth.
      if (metric >= RoutingLimits.maxDiscoveryDepth) continue;

      // Explore neighbors of current node.
      final neighbors = adjacency[current];
      if (neighbors == null) continue;

      for (final neighbor in neighbors) {
        if (!visited.contains(neighbor)) {
          visited.add(neighbor);
          firstHop[neighbor] = firstHop[current]!;
          queue.add((neighbor, metric + 1));
        }
      }
    }

    return const DiscoveryResult.notFound();
  }
}
