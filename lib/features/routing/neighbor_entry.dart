/// I8.2 — A single neighbor entry in the routing neighbor table.
///
/// A neighbor entry represents a peer that is currently a direct
/// routing neighbor of the local node. It is keyed by the peer's
/// cryptographic identity (PeerId), not by BLE address.
///
/// Key principles:
/// - Neighbor ≠ Trust (trust is owned by I6/I7)
/// - Neighbor ≠ Session (sessions are owned by I7.6)
/// - Neighbor ≠ Authentication (authentication is owned by I7.5)
/// - Neighbor is a routing-layer view of direct connectivity
library;

/// The direct-relationship state of a neighbor.
///
/// This captures the I7 connection lifecycle as seen by the routing layer.
enum NeighborState {
  /// Peer is actively connected and usable as a direct neighbor.
  active,

  /// Peer was previously active but is now disconnected.
  /// Kept briefly to support stale-callback protection.
  stale,
}

/// A single entry in the neighbor table.
///
/// Represents: "Peer [peerId] is a direct neighbor with
/// [state] relationship to the local node."
///
/// The entry is minimal by design. It does not store:
/// - trust state (owned by I6/I7)
/// - session state (owned by I7.6)
/// - BLE device details (consumed from I7, not stored here)
/// - routing metrics (computed from neighbor table, not stored in entries)
class NeighborEntry {
  const NeighborEntry({
    required this.peerId,
    required this.state,
    required this.addedAt,
    required this.lastUpdatedAt,
    this.bleDeviceId,
    this.generation,
  });

  /// Cryptographic identity of the neighbor (PeerId).
  /// This is the sole authoritative key for the neighbor.
  final String peerId;

  /// Current state of this neighbor relationship.
  final NeighborState state;

  /// When this neighbor was first added to the table.
  final DateTime addedAt;

  /// When this neighbor's state was last updated.
  final DateTime lastUpdatedAt;

  /// BLE device ID (MAC address) for the current connection.
  /// This is a runtime detail consumed from I7, not used as identity.
  final String? bleDeviceId;

  /// Connection generation from I7's PeerConnectionManager.
  /// Used for stale-callback protection. If a disconnect callback
  /// arrives with an older generation, it is ignored.
  final int? generation;

  /// Whether this neighbor is currently active (directly connected).
  bool get isActive => state == NeighborState.active;

  /// Whether this neighbor is stale (previously active, now disconnected).
  bool get isStale => state == NeighborState.stale;

  /// Create a copy with updated fields.
  NeighborEntry copyWith({
    NeighborState? state,
    DateTime? lastUpdatedAt,
    String? bleDeviceId,
    int? generation,
  }) {
    return NeighborEntry(
      peerId: peerId,
      state: state ?? this.state,
      addedAt: addedAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      bleDeviceId: bleDeviceId ?? this.bleDeviceId,
      generation: generation ?? this.generation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NeighborEntry &&
          runtimeType == other.runtimeType &&
          peerId == other.peerId &&
          state == other.state;

  @override
  int get hashCode => Object.hash(peerId, state);

  @override
  String toString() =>
      'NeighborEntry(${peerId.substring(0, 8)}..., '
      'state=${state.name}, '
      'gen=$generation)';
}
