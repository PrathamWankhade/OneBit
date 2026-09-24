/// I8.1 — Routing domain models.
///
/// Establishes the conceptual and code-level routing model for OneBit.
///
/// Key principles:
/// - Every routing destination resolves to a cryptographic identity (peerId)
/// - Routing sits above the peer/connection layer (I7)
/// - Routing must NOT create connections or sessions
/// - Routing information from the network is untrusted input
library;

/// Represents a node in the routing topology.
///
/// A routing node is identified by its cryptographic identity (peerId).
/// This is the same identity used throughout I7 (hex-encoded Ed25519 public key).
///
/// The local node is a special case where [isLocal] is true.
class RoutingNode {
  const RoutingNode({
    required this.peerId,
    this.displayName,
    this.isLocal = false,
  });

  /// Cryptographic identity (hex-encoded Ed25519 public key).
  final String peerId;

  /// Human-readable name, if known.
  final String? displayName;

  /// Whether this is the local node.
  final bool isLocal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutingNode &&
          runtimeType == other.runtimeType &&
          peerId == other.peerId;

  @override
  int get hashCode => peerId.hashCode;

  @override
  String toString() =>
      'RoutingNode(${isLocal ? "local" : "peer"}, '
      '${peerId.substring(0, 8)}..., '
      '${displayName ?? "?"})';
}

/// The eligibility status of a peer as a routing neighbor.
///
/// Not every connected peer is automatically a routing neighbor.
/// This enum captures the routing-specific view of peer reachability.
enum NeighborStatus {
  /// Peer is not eligible as a routing neighbor.
  /// Either not connected, not authenticated, or not trusted.
  ineligible,

  /// Peer is connected and authenticated but not yet trusted.
  /// May participate in routing information exchange but not forward traffic.
  candidate,

  /// Peer is fully eligible as a routing neighbor.
  /// Connected, authenticated, and trusted.
  active,

  /// Peer was previously active but is now unreachable.
  lost,
}
