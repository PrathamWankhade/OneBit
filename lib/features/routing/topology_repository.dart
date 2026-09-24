/// I8.4 — Topology repository for storing local and remote topology knowledge.
///
/// Maintains two separate concerns:
///
/// 1. **Local topology** — the node's own direct neighbor observations
///    (derived from I8.2/I8.3, never overwritten by remote data).
///
/// 2. **Remote topology** — topology advertisements received from
///    directly reachable peers, keyed by source identity.
///
/// ## Snapshot Semantics
///
/// Each remote advertisement is a **full snapshot** of the source's
/// current neighbor set. A newer advertisement (higher sequence)
/// completely replaces the previous one for that source.
///
/// ## Thread Safety
///
/// All operations are synchronous and operate on in-memory state.
/// Concurrent updates from different sources are isolated — each
/// source has its own independent state.
library;

import 'dart:collection';

import 'package:onebit/features/routing/routing_limits.dart';
import 'package:onebit/features/routing/topology_advertisement.dart';

/// Stored topology information for a single remote source.
class RemoteTopologyEntry {
  const RemoteTopologyEntry({
    required this.sourceIdentity,
    required this.neighborPeerIds,
    required this.sequence,
    required this.receivedAt,
  });

  /// The peer identity that generated this advertisement.
  final String sourceIdentity;

  /// The source's advertised direct neighbor PeerIds.
  final List<String> neighborPeerIds;

  /// The sequence number of the accepted advertisement.
  final int sequence;

  /// When this advertisement was received and accepted.
  final DateTime receivedAt;

  @override
  String toString() =>
      'RemoteTopologyEntry(source: ${sourceIdentity.substring(0, 8)}..., '
      'seq: $sequence, neighbors: ${neighborPeerIds.length})';
}

/// Topology knowledge repository.
///
/// Separates local observation from remote advertising information.
/// Each remote source is independently tracked.
class TopologyRepository {
  /// Local direct neighbor PeerIds (from I8.2/I8.3 observation).
  ///
  /// This is the authoritative local topology — it is never
  /// overwritten by remote advertisements.
  Set<String> _localNeighborIds = {};

  /// Remote advertised topology, keyed by source PeerId.
  final Map<String, RemoteTopologyEntry> _remoteEntries = {};

  /// Sequence numbers accepted per source (for replay protection).
  final Map<String, int> _acceptedSequences = {};

  // ── Local Topology ────────────────────────────────────────

  /// Get the current local direct neighbor PeerIds.
  UnmodifiableSetView<String> get localNeighborIds =>
      UnmodifiableSetView(_localNeighborIds);

  /// Update the local topology from I8.2/I8.3 state.
  ///
  /// This replaces the entire local neighbor set atomically.
  void setLocalTopology(Set<String> neighborIds) {
    _localNeighborIds = Set.unmodifiable(neighborIds);
  }

  // ── Remote Topology ───────────────────────────────────────

  /// Get all remote source PeerIds that have advertised topology.
  Set<String> get remoteSourceIds => Set.unmodifiable(_remoteEntries.keys);

  /// Get the remote topology entry for a specific source.
  RemoteTopologyEntry? getRemoteEntry(String sourcePeerId) =>
      _remoteEntries[sourcePeerId];

  /// Get all remote topology entries.
  List<RemoteTopologyEntry> get remoteEntries =>
      List.unmodifiable(_remoteEntries.values);

  /// Get the set of PeerIds advertised by a specific source.
  Set<String> advertisedNeighborsOf(String sourcePeerId) {
    final entry = _remoteEntries[sourcePeerId];
    if (entry == null) return {};
    return Set.unmodifiable(entry.neighborPeerIds);
  }

  /// Record a topology advertisement from a remote source.
  ///
  /// Uses snapshot semantics: the advertisement fully replaces
  /// the source's previous advertised neighbor set.
  ///
  /// Returns `true` if the advertisement was accepted (newer or
  /// equal sequence), `false` if rejected (older/replayed).
  bool recordAdvertisement(TopologyAdvertisement ad) {
    final source = ad.sourceIdentity;

    // Check freshness — reject older sequence.
    final currentSeq = _acceptedSequences[source];
    if (currentSeq != null && ad.sequence < currentSeq) {
      return false; // Older advertisement — reject.
    }

    // Enforce bounds: if at capacity and this is a new source, reject.
    if (!_remoteEntries.containsKey(source) &&
        _remoteEntries.length >= RoutingLimits.maxTopologySources) {
      return false;
    }

    // Accept: store the new topology.
    _remoteEntries[source] = RemoteTopologyEntry(
      sourceIdentity: source,
      neighborPeerIds: List.unmodifiable(ad.neighborPeerIds),
      sequence: ad.sequence,
      receivedAt: DateTime.now(),
    );
    _acceptedSequences[source] = ad.sequence;

    return true;
  }

  /// Remove all topology for a specific source.
  ///
  /// Called when a peer disconnects or its identity changes.
  void removeSource(String sourcePeerId) {
    _remoteEntries.remove(sourcePeerId);
    _acceptedSequences.remove(sourcePeerId);
  }

  /// Remove all remote topology knowledge.
  ///
  /// Does not affect local topology.
  void clearRemote() {
    _remoteEntries.clear();
    _acceptedSequences.clear();
  }

  /// Clear everything (local + remote).
  void clear() {
    _localNeighborIds = {};
    clearRemote();
  }

  // ── Combined Queries ──────────────────────────────────────

  /// Get all known PeerIds across local and remote topology.
  ///
  /// This includes:
  /// - Local direct neighbors
  /// - All remote advertised neighbors (from all sources)
  /// - All remote source identities
  Set<String> get allKnownPeerIds {
    final all = <String>{..._localNeighborIds};
    for (final entry in _remoteEntries.values) {
      all.add(entry.sourceIdentity);
      all.addAll(entry.neighborPeerIds);
    }
    return all;
  }

  /// Get the number of remote sources with active topology.
  int get remoteSourceCount => _remoteEntries.length;
}
