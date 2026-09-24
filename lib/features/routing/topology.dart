/// I8.1 — Topology representation.
///
/// The topology model represents the known network graph.
/// It tracks:
/// - Which nodes exist
/// - Which nodes are directly connected (neighbors)
/// - The overall reachability structure
///
/// Key principle: The topology is derived from the neighbor table
/// and routing advertisements. It does not manage connections.
library;

import 'package:onebit/features/routing/routing_neighbor.dart';
import 'package:onebit/features/routing/routing_node.dart';

/// A snapshot of the network topology.
///
/// This is an immutable representation of the known network state
/// at a specific point in time.
class TopologySnapshot {
  const TopologySnapshot({
    required this.nodes,
    required this.neighbors,
    required this.timestamp,
  });

  /// All known nodes in the topology.
  final List<RoutingNode> nodes;

  /// The local node's neighbor table.
  final List<RoutingNeighbor> neighbors;

  /// When this snapshot was taken.
  final DateTime timestamp;

  /// The local node (the node computing this topology).
  RoutingNode? get localNode =>
      nodes.where((n) => n.isLocal).firstOrNull;

  /// All neighbors that are eligible for routing.
  List<RoutingNeighbor> get eligibleNeighbors =>
      neighbors.where((n) => n.isEligible).toList();

  /// All neighbor peer IDs.
  Set<String> get neighborPeerIds =>
      neighbors.map((n) => n.peerId).toSet();

  /// Check if a peer is a direct neighbor.
  bool isNeighbor(String peerId) =>
      neighbors.any((n) => n.peerId == peerId);

  /// Get a specific neighbor.
  RoutingNeighbor? neighbor(String peerId) =>
      neighbors.where((n) => n.peerId == peerId).firstOrNull;

  /// All peer IDs in the topology.
  Set<String> get allPeerIds => nodes.map((n) => n.peerId).toSet();

  /// Number of known nodes.
  int get nodeCount => nodes.length;

  /// Number of neighbors.
  int get neighborCount => neighbors.length;

  @override
String toString() =>
      'TopologySnapshot(nodes=$nodeCount, '
      'neighbors=$neighborCount, '
      'eligible=${eligibleNeighbors.length})';
}

/// A topology edge — a direct connection between two nodes.
///
/// This represents a bidirectional BLE connection at the topology level.
/// The edge is derived from the I7 connection layer, not created by routing.
class TopologyEdge {
  const TopologyEdge({
    required this.fromPeerId,
    required this.toPeerId,
    this.rssi,
    this.createdAt,
  });

  /// The first node's peer ID.
  final String fromPeerId;

  /// The second node's peer ID.
  final String toPeerId;

  /// Signal strength, if available.
  final int? rssi;

  /// When this edge was first observed.
  final DateTime? createdAt;

  /// Whether this edge involves a specific peer.
  bool involves(String peerId) =>
      fromPeerId == peerId || toPeerId == peerId;

  /// Get the other end of the edge.
  String otherEnd(String peerId) {
    if (peerId == fromPeerId) return toPeerId;
    if (peerId == toPeerId) return fromPeerId;
    throw ArgumentError('Peer $peerId is not part of this edge');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopologyEdge &&
          runtimeType == other.runtimeType &&
          ((fromPeerId == other.fromPeerId && toPeerId == other.toPeerId) ||
           (fromPeerId == other.toPeerId && toPeerId == other.fromPeerId));

  @override
  int get hashCode {
    // Order-independent hash: sort the two peer IDs to ensure
    // (A, B) and (B, A) produce the same hash.
    final sorted = [fromPeerId, toPeerId]..sort();
    return Object.hash(sorted[0], sorted[1]);
  }

  @override
  String toString() =>
      'TopologyEdge(${fromPeerId.substring(0, 8)}... ↔ '
      '${toPeerId.substring(0, 8)}...)';
}
