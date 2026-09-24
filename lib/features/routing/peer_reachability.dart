/// I8.3 — Direct peer reachability evaluation.
///
/// Answers: "Is this known logical peer currently usable as a
/// direct routing neighbor?"
///
/// ## Architecture
///
/// ```text
/// I7 Peer Registry         (does peer exist?)
/// I7 PeerConnectionManager (is peer connected?)
/// I7 IdentityAssociation   (is identity valid?)
/// I8.2 Neighbor Table      (is peer a routing neighbor?)
///         ↓
/// I8.3 PeerReachability    (is peer directly reachable?)
/// ```
///
/// ## Direct Routing Reachability Criteria
///
/// A peer is directly routing-reachable if and only if ALL of:
///
/// 1. The peer exists in the authoritative I7 peer registry.
/// 2. The peer has an active direct runtime connection
///    (`PeerLifecycleState.connected`).
/// 3. The connection generation is current (not stale).
/// 4. The peer is represented as an active neighbor in the I8.2
///    neighbor table.
///
/// ## What This Does NOT Require
///
/// - Trust (trusted + disconnected = unreachable)
/// - Authentication (authenticated + disconnected = unreachable)
/// - Session (session exists + disconnected = unreachable)
/// - Trust is kept entirely separate from routing reachability.
///
/// ## What This Does NOT Do
///
/// - Does not create BLE connections.
/// - Does not initiate authentication.
/// - Does not establish trust.
/// - Does not forward messages.
/// - Does not compute routes.
/// - Does not advertise topology.
library;

import 'package:onebit/features/peer_registry/peer_connection_manager.dart';
import 'package:onebit/features/peer_registry/peer_lifecycle_state.dart';
import 'package:onebit/features/peer_registry/peer_registry.dart';
import 'package:onebit/features/routing/neighbor_table.dart';
import 'package:onebit/features/routing/reachability_reason.dart';

/// Runtime evaluation of direct peer reachability.
///
/// Consumes existing I7 and I8.2 state without owning any transport
/// resources. All methods are pure/read-oriented except for
/// maintaining the internal subscription to connection state changes.
class PeerReachability {
  PeerReachability({
    required this._registry,
    required this._connectionManager,
    required this._neighborTable,
  });

  final PeerRegistryService _registry;
  final PeerConnectionManager _connectionManager;
  final NeighborTable _neighborTable;

  /// Check if a peer is currently directly routing-reachable.
  ///
  /// Returns `true` if and only if the peer satisfies all reachability
  /// criteria defined in the class documentation.
  ///
  /// This is a pure read operation — it does not create connections,
  /// sessions, authentication, or trust.
  bool isReachable(String peerId) {
    return getReachability(peerId) == ReachabilityReason.reachable;
  }

  /// Get the detailed reachability reason for a peer.
  ///
  /// Returns the specific reason why a peer is or is not directly
  /// routing-reachable. This is useful for diagnostics and UI.
  ReachabilityReason getReachability(String peerId) {
    // Criterion 1: Peer must exist in the authoritative registry.
    final entry = _registry.get(peerId);
    if (entry == null) return ReachabilityReason.unknownPeer;

    // Criterion 2: Peer must have an active connection.
    final lifecycle = _connectionManager.lifecycleStateFor(peerId);
    if (!lifecycle.isConnected) return ReachabilityReason.notConnected;

    // Criterion 2b: Connection context must be valid (device mapping exists).
    final device = _connectionManager.deviceForPeer(peerId);
    if (device == null) return ReachabilityReason.missingContext;

    // Criterion 3: Peer must be an active neighbor in the I8.2 table.
    if (!_neighborTable.isNeighbor(peerId)) {
      return ReachabilityReason.notNeighbor;
    }

    return ReachabilityReason.reachable;
  }

  /// Get all peers that are currently directly routing-reachable.
  ///
  /// Returns a deterministic, snapshot-safe list of PeerIds that
  /// satisfy all reachability criteria.
  ///
  /// Changing one peer's reachability does not affect others.
  List<String> getReachableNeighbors() {
    final neighborIds = _neighborTable.neighborPeerIds;
    final reachable = <String>[];

    for (final peerId in neighborIds) {
      if (isReachable(peerId)) {
        reachable.add(peerId);
      }
    }

    return reachable;
  }

  /// Number of currently reachable peers.
  int get reachableCount => getReachableNeighbors().length;

  /// Whether any peer is currently directly reachable.
  bool get hasReachablePeers => reachableCount > 0;
}
