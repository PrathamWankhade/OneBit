/// I8.1 — Routing state ownership model.
///
/// Defines the routing-specific view of peer state.
/// This is the bridge between I7 (peer/connection) and I8 (routing).
///
/// Key principle: Routing consumes I7 state, it does not own it.
/// The routing layer asks: "Can I use Peer B as a next hop?"
/// It does NOT create connections or sessions.
library;

/// The routing eligibility of a peer.
///
/// This is derived from I7 state but represents the routing-specific view.
/// A peer must satisfy ALL of these to be a routing neighbor:
/// - Connected (lifecycle state)
/// - Authenticated (cryptographic proof)
/// - Trusted (user explicitly granted trust)
enum RoutingEligibility {
  /// Not connected — cannot route through this peer.
  notConnected,

  /// Connected but not authenticated — cannot route.
  notAuthenticated,

  /// Connected and authenticated but not trusted — cannot route.
  notTrusted,

  /// Connected, authenticated, and trusted — eligible for routing.
  eligible,
}

/// A summary of a peer's routing-relevant state.
///
/// This is a read-only snapshot of I7 state that the routing layer
/// uses for neighbor eligibility decisions.
class RoutingPeerState {
  const RoutingPeerState({
    required this.peerId,
    required this.isConnected,
    required this.isAuthenticated,
    required this.isTrusted,
    required this.lifecycleState,
    this.displayName,
  });

  /// Cryptographic identity.
  final String peerId;

  /// Whether the peer is currently connected (from I7 lifecycle).
  final bool isConnected;

  /// Whether the peer is authenticated (cryptographic proof).
  final bool isAuthenticated;

  /// Whether the peer is trusted (user explicitly granted trust).
  final bool isTrusted;

  /// The full lifecycle state from I7.
  final String lifecycleState;

  /// Human-readable name, if known.
  final String? displayName;

  /// Compute routing eligibility from I7 state.
  RoutingEligibility get eligibility {
    if (!isConnected) return RoutingEligibility.notConnected;
    if (!isAuthenticated) return RoutingEligibility.notAuthenticated;
    if (!isTrusted) return RoutingEligibility.notTrusted;
    return RoutingEligibility.eligible;
  }

  /// Whether this peer is eligible as a routing neighbor.
  bool get isEligibleForRouting =>
      eligibility == RoutingEligibility.eligible;

  @override
  String toString() =>
      'RoutingPeerState(${peerId.substring(0, 8)}..., '
      'connected=$isConnected, '
      'authenticated=$isAuthenticated, '
      'trusted=$isTrusted, '
      'eligibility=${eligibility.name})';
}
