/// I8.4 — Topology exchange service.
///
/// Responsible for:
/// - Building topology advertisements from local I8.2/I8.3 state
/// - Validating incoming advertisements
/// - Submitting valid advertisements to the topology repository
/// - Providing topology queries for later routing increments
///
/// ## Architecture
///
/// ```text
/// Local NeighborTable + PeerReachability
///         ↓
/// buildAdvertisement(localPeerId)
///         ↓
/// TopologyAdvertisement
///         ↓
/// encode → secure transport → remote peer
///
/// Remote peer → decode → validate → recordAdvertisement
///         ↓
/// TopologyRepository
/// ```
///
/// ## What This Does NOT Do
///
/// - Does not create routes (I8.5)
/// - Does not select next hops (I8.7)
/// - Does not forward messages
/// - Does not create BLE connections
/// - Does not initiate authentication/trust
library;

import 'dart:typed_data';

import 'package:onebit/features/routing/neighbor_table.dart';
import 'package:onebit/features/routing/peer_reachability.dart';
import 'package:onebit/features/routing/topology_advertisement.dart';
import 'package:onebit/features/routing/topology_advertisement_codec.dart';
import 'package:onebit/features/routing/topology_repository.dart';

/// Result of processing an incoming topology advertisement.
enum AdvertisementResult {
  /// Advertisement accepted and applied.
  accepted,

  /// Advertisement rejected: older or duplicate sequence.
  rejectedStale,

  /// Advertisement rejected: invalid structure or encoding.
  rejectedMalformed,

  /// Advertisement rejected: source identity is the local node.
  rejectedSelfSource,

  /// Advertisement rejected: contains self-loop (source advertises itself).
  rejectedSelfLoop,
}

/// Service for building, validating, and processing topology advertisements.
///
/// Bridges the local I8.2/I8.3 state with the topology repository.
class TopologyExchangeService {
  TopologyExchangeService({
    required this._neighborTable,
    required this._reachability,
    required this._repository,
  });

  final NeighborTable _neighborTable;
  final PeerReachability _reachability;
  final TopologyRepository _repository;

  /// Local advertisement sequence counter.
  ///
  /// Incremented each time a new local advertisement is built.
  /// Not persisted across restarts — see restart semantics below.
  int _localSequence = 0;

  /// Get the current local sequence number.
  int get localSequence => _localSequence;

  // ── Local Advertisement Generation ────────────────────────

  /// Build the current topology advertisement for the local node.
  ///
  /// Uses the I8.2 neighbor table and I8.3 reachability to determine
  /// which peers to advertise as direct neighbors.
  ///
  /// Only reachable neighbors are advertised — disconnected or
  /// stale peers are excluded.
  TopologyAdvertisement buildAdvertisement({
    required String localPeerId,
  }) {
    // Use reachable neighbors as the advertised set.
    // These are peers that are connected AND in the neighbor table.
    final advertisedNeighbors = _reachability.getReachableNeighbors();

    // If no reachable neighbors, still send an empty advertisement
    // so the receiver knows this source exists with no current neighbors.
    return TopologyAdvertisement(
      sourceIdentity: localPeerId,
      sequence: _localSequence,
      neighborPeerIds: advertisedNeighbors,
    );
  }

  /// Build and increment the local sequence counter.
  ///
  /// Call this when generating a new advertisement that should
  /// supersede previous ones.
  TopologyAdvertisement buildAdvertisementWithIncrement({
    required String localPeerId,
  }) {
    // Guard against int64 overflow (practically unreachable but defensive).
    if (_localSequence < 0x7FFFFFFFFFFFFFFE) {
      _localSequence++;
    }
    return buildAdvertisement(localPeerId: localPeerId);
  }

  // ── Incoming Advertisement Processing ─────────────────────

  /// Validate and process an incoming topology advertisement.
  ///
  /// Checks:
  /// 1. Structural validity (PeerId format, size bounds)
  /// 2. Self-source rejection (source != local node)
  /// 3. Self-loop rejection (source not in own neighbor list)
  /// 4. Freshness (newer or equal sequence)
  ///
  /// Returns the result and, if accepted, updates the repository.
  AdvertisementResult processAdvertisement({
    required TopologyAdvertisement advertisement,
    required String localPeerId,
  }) {
    // Structural validation.
    if (!advertisement.isValid) {
      return AdvertisementResult.rejectedMalformed;
    }

    // Reject self-source (remote claiming to be local node).
    if (advertisement.sourceIdentity == localPeerId) {
      return AdvertisementResult.rejectedSelfSource;
    }

    // Reject self-loop (source advertises itself as neighbor).
    if (advertisement.hasSelfLoop) {
      return AdvertisementResult.rejectedSelfLoop;
    }

    // Record in repository (handles freshness check internally).
    final accepted = _repository.recordAdvertisement(advertisement);
    if (!accepted) {
      return AdvertisementResult.rejectedStale;
    }

    return AdvertisementResult.accepted;
  }

  /// Process a raw binary advertisement.
  ///
  /// Decodes, validates, and processes the advertisement.
  /// Returns the result and the decoded advertisement if successful.
  ({AdvertisementResult result, TopologyAdvertisement? advertisement})
      processRawAdvertisement({
    required List<int> bytes,
    required String localPeerId,
  }) {
    try {
      final ad = TopologyAdvertisementCodec.decode(
        bytes is! Uint8List ? Uint8List.fromList(bytes) : bytes,
      );
      final result = processAdvertisement(
        advertisement: ad,
        localPeerId: localPeerId,
      );
      return (result: result, advertisement: ad);
    } on TopologyDecodeException {
      return (
        result: AdvertisementResult.rejectedMalformed,
        advertisement: null,
      );
    }
  }

  // ── Topology Queries ──────────────────────────────────────

  /// Get the set of all known PeerIds from topology knowledge.
  ///
  /// Includes local neighbors, remote sources, and their advertised
  /// neighbors. Does not include the local node itself.
  Set<String> get allKnownTopologyPeerIds => _repository.allKnownPeerIds;

  /// Get the set of PeerIds that are advertised by remote sources
  /// but are NOT direct local neighbors.
  ///
  /// These are "topology-known" peers — reachable only through
  /// multi-hop routing (future I8.5+).
  Set<String> get indirectlyKnownPeerIds {
    final localNeighbors = _neighborTable.neighborPeerIds;
    final remoteKnown = <String>{};
    for (final entry in _repository.remoteEntries) {
      remoteKnown.addAll(entry.neighborPeerIds);
    }
    return remoteKnown.difference(localNeighbors);
  }

  /// Check if a peer is known through topology (remote advertisement)
  /// but is not a direct local neighbor.
  bool isIndirectlyKnown(String peerId) {
    return indirectlyKnownPeerIds.contains(peerId);
  }

  // ── Lifecycle ─────────────────────────────────────────────

  /// Handle a peer disconnecting.
  ///
  /// Removes the peer's advertised topology and, if the peer was
  /// a source, cleans up its remote entries.
  void onPeerDisconnected(String peerId) {
    // If the disconnected peer was a remote topology source,
    // remove its advertised information.
    _repository.removeSource(peerId);
  }

  /// Reset local sequence counter.
  ///
  /// Called on app restart. The sequence starts at 0, which is
  /// safe because receivers accept equal sequences (idempotent)
  /// and peers restart with fresh connections.
  void resetLocalSequence() {
    _localSequence = 0;
  }

  /// Clear all topology knowledge.
  void clear() {
    _repository.clear();
    _localSequence = 0;
  }
}
