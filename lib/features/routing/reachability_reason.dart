/// I8.3 — Why a peer is or is not directly routing-reachable.
///
/// This enum is a diagnostic aid, not a state machine. It explains
/// the result of a reachability evaluation.
///
/// Conceptual separation (do not collapse):
///   KNOWN → CONNECTED → AUTHENTICATED → TRUSTED → ROUTING-REACHABLE
///
/// These remain independent. This enum describes only the final
/// routing-reachability result.
library;

/// Reasons a peer is or is not directly routing-reachable.
enum ReachabilityReason {
  /// Peer exists in the registry and has an active, usable direct connection
  /// that is also represented in the I8.2 neighbor table.
  reachable,

  /// Peer is not present in the authoritative I7 peer registry.
  unknownPeer,

  /// Peer exists but has no active connection (lifecycle state is not
  /// `PeerLifecycleState.connected`).
  notConnected,

  /// Peer exists and is connected, but the connection is stale (a newer
  /// connection generation has superseded this one).
  staleConnection,

  /// Peer exists and is connected, but is not represented as an active
  /// neighbor in the I8.2 neighbor table.
  notNeighbor,

  /// Peer exists in the registry but the connection context is missing
  /// (e.g., no BLE device ID mapping).
  missingContext,
}
