/// I8.2 — Runtime neighbor table for the routing layer.
///
/// The neighbor table is the routing layer's authoritative representation
/// of directly connected peers. It derives its state from I7's
/// PeerConnectionManager and PeerRegistryService.
///
/// Architecture:
/// ```text
/// I7 PeerConnectionManager
///         ↓
/// I8 NeighborTable (this class)
///         ↓
/// I8 Topology / Route Table
/// ```
///
/// Key principles:
/// - Neighbor identity is PeerId (cryptographic identity)
/// - No duplicate neighbors (keyed by PeerId)
/// - Runtime-only state (no persistence)
/// - Does NOT create connections or sessions
/// - Does NOT store trust, authentication, or session state
library;

import 'dart:async';

import 'package:onebit/features/peer_registry/peer_connection_manager.dart';
import 'package:onebit/features/routing/neighbor_entry.dart';
import 'package:onebit/features/routing/routing_limits.dart';
import 'package:onebit/features/routing/routing_neighbor.dart';
import 'package:onebit/features/routing/routing_node.dart';
import 'package:onebit/features/routing/topology.dart';

/// Runtime neighbor table for the routing layer.
///
/// Manages the set of peers that are currently direct routing neighbors.
/// Derives neighbor state from I7's connection lifecycle and optionally
/// checks trust state for neighbor eligibility.
class NeighborTable {
  NeighborTable({
    required this._connectionManager,
  });

  final PeerConnectionManager _connectionManager;

  /// Internal neighbor storage, keyed by PeerId.
  final Map<String, NeighborEntry> _neighbors = {};

  /// Stream controller for neighbor table changes.
  final _controller = StreamController<List<NeighborEntry>>.broadcast();

  /// Whether this table has been disposed.
  bool _isDisposed = false;

  /// Stream of the current neighbor list, emitted on any change.
  Stream<List<NeighborEntry>> get neighborStream => _controller.stream;

  /// Current snapshot of all active neighbors.
  List<NeighborEntry> get neighbors =>
      _neighbors.values.where((e) => e.isActive).toList();

  /// Current snapshot of all neighbor entries (including stale).
  List<NeighborEntry> get allEntries => _neighbors.values.toList();

  /// Number of active neighbors.
  int get count => neighbors.length;

  /// Whether there are any active neighbors.
  bool get hasNeighbors => count > 0;

  /// Whether this table has been disposed.
  bool get isDisposed => _isDisposed;

  StreamSubscription<List<PeerConnectionRecord>>? _connectionSub;

  /// Initialize the neighbor table by subscribing to I7 connection changes.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  void initialize() {
    if (_isDisposed) return;
    if (_connectionSub != null) return; // Idempotent guard.
    _connectionSub = _connectionManager.connectionStream.listen(
      _onConnectionChange,
    );
    // Sync from current state.
    _syncFromConnections(_connectionManager.connections);
  }

  /// Look up a neighbor by PeerId.
  NeighborEntry? getNeighbor(String peerId) => _neighbors[peerId];

  /// Check if a peer is an active direct neighbor.
  bool isNeighbor(String peerId) {
    final entry = _neighbors[peerId];
    return entry != null && entry.isActive;
  }

  /// Get the set of all active neighbor PeerIds.
  Set<String> get neighborPeerIds =>
      _neighbors.values.where((e) => e.isActive).map((e) => e.peerId).toSet();

  /// Manually add a neighbor.
  ///
  /// This is for controlled domain operations. The primary path for
  /// adding neighbors is through I7 connection state changes.
  ///
  /// If the peer already exists as a neighbor, updates the existing entry.
  void addNeighbor(String peerId, {String? bleDeviceId, int? generation}) {
    if (_isDisposed) return;
    final now = DateTime.now();
    final existing = _neighbors[peerId];

    if (existing != null) {
      // Update existing entry — prevent duplicates.
      _neighbors[peerId] = existing.copyWith(
        state: NeighborState.active,
        lastUpdatedAt: now,
        bleDeviceId: bleDeviceId ?? existing.bleDeviceId,
        generation: generation ?? existing.generation,
      );
    } else {
      // Enforce bounds: evict stale entries if at capacity.
      if (_neighbors.length >= RoutingLimits.maxNeighbors) {
        _evictStaleEntries();
      }
      // If still at capacity after eviction, reject.
      if (_neighbors.length >= RoutingLimits.maxNeighbors) return;
      // Add new entry.
      _neighbors[peerId] = NeighborEntry(
        peerId: peerId,
        state: NeighborState.active,
        addedAt: now,
        lastUpdatedAt: now,
        bleDeviceId: bleDeviceId,
        generation: generation,
      );
    }

    _emitChange();
  }

  /// Remove a neighbor by PeerId.
  ///
  /// This is idempotent — safe to call if the peer does not exist.
  /// Does not delete the peer from I7's registry, revoke trust,
  /// or affect sessions.
  void removeNeighbor(String peerId) {
    if (_isDisposed) return;
    final existing = _neighbors[peerId];
    if (existing == null) return;

    if (existing.isActive) {
      // Mark as stale rather than immediately removing.
      // This supports stale-callback protection: if a reconnect
      // happens, the stale entry is upgraded back to active.
      _neighbors[peerId] = existing.copyWith(
        state: NeighborState.stale,
        lastUpdatedAt: DateTime.now(),
      );
    }

    _emitChange();
  }

  /// Remove a neighbor only if the generation matches.
  ///
  /// This protects against stale disconnect callbacks. If a disconnect
  /// arrives with an older generation than the current neighbor entry,
  /// it is ignored.
  ///
  /// Returns true if the removal was applied.
  bool removeNeighborIfCurrentGeneration(String peerId, int generation) {
    if (_isDisposed) return false;
    final existing = _neighbors[peerId];
    if (existing == null) return false;

    // If the existing entry has a newer generation, ignore this removal.
    if (existing.generation != null &&
        generation < existing.generation!) {
      return false;
    }

    removeNeighbor(peerId);
    return true;
  }

  /// Forcefully remove a neighbor, regardless of generation.
  ///
  /// Used when the connection is confirmed dead (e.g., explicit disconnect).
  void forceRemoveNeighbor(String peerId) {
    if (_isDisposed) return;
    _neighbors.remove(peerId);
    _emitChange();
  }

  /// Build a topology snapshot from the current neighbor table.
  ///
  /// The snapshot includes the local node and all current neighbors.
  TopologySnapshot buildTopologySnapshot({
    required String localPeerId,
    String? localDisplayName,
  }) {
    final localNode = RoutingNode(
      peerId: localPeerId,
      displayName: localDisplayName,
      isLocal: true,
    );

    final neighborNodes = <RoutingNode>[];
    final routingNeighbors = <RoutingNeighbor>[];

    for (final entry in _neighbors.values) {
      if (!entry.isActive) continue;

      neighborNodes.add(RoutingNode(peerId: entry.peerId));
      routingNeighbors.add(RoutingNeighbor(
        peerId: entry.peerId,
        status: NeighborStatus.active,
        lastSeenAt: entry.lastUpdatedAt,
        bleDeviceId: entry.bleDeviceId,
      ));
    }

    return TopologySnapshot(
      nodes: [localNode, ...neighborNodes],
      neighbors: routingNeighbors,
      timestamp: DateTime.now(),
    );
  }

  /// Sync neighbor table from I7 connection records.
  ///
  /// This is the primary mechanism for keeping the neighbor table
  /// in sync with the actual connection state.
  void _syncFromConnections(List<PeerConnectionRecord> connections) {
    // Track which peers are connected in this sync cycle.
    final connectedPeers = <String>{};

    for (final record in connections) {
      if (record.isConnected) {
        connectedPeers.add(record.peerIdentityId);
        _ensureActiveNeighbor(
          record.peerIdentityId,
          bleDeviceId: record.deviceId,
        );
      }
    }

    // Mark peers that are no longer connected as stale.
    for (final peerId in _neighbors.keys.toList()) {
      if (!connectedPeers.contains(peerId)) {
        final entry = _neighbors[peerId]!;
        if (entry.isActive) {
          _neighbors[peerId] = entry.copyWith(
            state: NeighborState.stale,
            lastUpdatedAt: DateTime.now(),
          );
        }
      }
    }

    _emitChange();
  }

  /// Handle I7 connection state changes.
  void _onConnectionChange(List<PeerConnectionRecord> connections) {
    _syncFromConnections(connections);
  }

  /// Ensure a peer exists as an active neighbor.
  ///
  /// If the peer already exists, updates it. If not, creates a new entry.
  void _ensureActiveNeighbor(
    String peerId, {
    String? bleDeviceId,
  }) {
    final existing = _neighbors[peerId];
    final now = DateTime.now();

    if (existing != null) {
      // Upgrade stale→active or update existing active entry.
      _neighbors[peerId] = existing.copyWith(
        state: NeighborState.active,
        lastUpdatedAt: now,
        bleDeviceId: bleDeviceId ?? existing.bleDeviceId,
        generation: (existing.generation ?? 0) + 1,
      );
    } else {
      _neighbors[peerId] = NeighborEntry(
        peerId: peerId,
        state: NeighborState.active,
        addedAt: now,
        lastUpdatedAt: now,
        bleDeviceId: bleDeviceId,
        generation: 1,
      );
    }
  }

  /// Emit a change notification to stream listeners.
  void _emitChange() {
    if (!_isDisposed && !_controller.isClosed) {
      _controller.add(neighbors);
    }
  }

  /// Evict stale entries that have exceeded the grace period.
  ///
  /// Evicts the oldest stale entries first. Called when the neighbor
  /// map is at capacity and a new entry needs to be added.
  void _evictStaleEntries() {
    final cutoff = DateTime.now().subtract(
      RoutingLimits.staleNeighborGracePeriod,
    );
    final staleEntries = _neighbors.entries
        .where((e) => !e.value.isActive && e.value.lastUpdatedAt.isBefore(cutoff))
        .map((e) => e.key)
        .toList()
      ..sort((a, b) {
        final aTime = _neighbors[a]!.lastUpdatedAt;
        final bTime = _neighbors[b]!.lastUpdatedAt;
        return aTime.compareTo(bTime);
      });
    for (final peerId in staleEntries) {
      _neighbors.remove(peerId);
    }
  }

  /// Clear all neighbor entries.
  ///
  /// Used during disposal or reset.
  void clear() {
    if (_isDisposed) return;
    _neighbors.clear();
    _emitChange();
  }

  /// Dispose resources.
  ///
  /// Safe to call multiple times. After disposal, all operations are no-ops.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _connectionSub?.cancel();
    _connectionSub = null;
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
