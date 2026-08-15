import 'dart:math';

import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_neighbor.dart';

/// Log-distance path-loss estimator.
///
/// `distance = 10^((txPower - rssi) / (10 * pathLossExponent))`, clamped to
/// a sane physical range. Informational only — routing never uses distance.
abstract final class MeshDistanceEstimator {
  static const double _txPowerDb = -59;
  static const double _pathLossExponent = 2.5;

  /// Estimates metres from [rssiDb].
  static double estimate(int rssiDb) {
    final power = (_txPowerDb - rssiDb) / (10 * _pathLossExponent);
    return pow(10, power).clamp(0.5, 200.0).toDouble();
  }
}

/// The neighbor registry: fresh observations in, immutable [MeshNeighbor]
/// values out.
///
/// Responsibilities:
/// - upsert advertisements (with EMA RSSI smoothing),
/// - track connection state,
/// - expire stale entries (self-healing feed for routing and topology),
/// - estimate distances for diagnostics.
///
/// Thread-safety is by design: the mesh engine is single-threaded; all
/// mutation happens on its event loop.
final class NeighborTable {
  NeighborTable({this._emaAlpha = 0.3});

  static const double _rssiFloor = -127.0;

  final double _emaAlpha;
  final Map<String, MeshNeighbor> _byId = {};

  /// Live entries, sorted by node id for stable iteration.
  List<MeshNeighbor> get all {
    final list = _byId.values.toList()
      ..sort((a, b) => a.nodeId.compareTo(b.nodeId));
    return list;
  }

  /// Number of tracked neighbors.
  int get count => _byId.length;

  /// Returns the entry for [nodeId], or `null`.
  MeshNeighbor? byId(String nodeId) => _byId[nodeId];

  /// Records an advertisement observation.
  ///
  /// Returns the (possibly new) entry and whether it was newly inserted.
  ({MeshNeighbor entry, bool isNew}) upsertAdvertisement(
    String nodeId,
    int rssiDb,
    DateTime seenAt, {
    Set<MeshCapability>? capabilities,
    int? advertisementSequence,
  }) {
    final existing = _byId[nodeId];
    final smoothed = _smooth(existing?.smoothedRssiDb, rssiDb);
    final entry = MeshNeighbor(
      nodeId: nodeId,
      firstSeen: existing?.firstSeen ?? seenAt,
      lastSeen: seenAt,
      latestRssiDb: rssiDb,
      smoothedRssiDb: smoothed,
      distanceEstimateMeters: MeshDistanceEstimator.estimate(smoothed.round()),
      connectionState: existing?.connectionState ?? MeshLinkState.advertising,
      hopEstimate: existing?.hopEstimate ?? 1,
      trustStatus: existing?.trustStatus ?? MeshTrustStatus.unknown,
      capabilities:
          capabilities ??
          existing?.capabilities ??
          const {MeshCapability.relay, MeshCapability.router},
      advertisementTimestamp: seenAt,
      lastAdvertisementSequence: advertisementSequence,
    );
    _byId[nodeId] = entry;
    return (entry: entry, isNew: existing == null);
  }

  /// Updates the connection state of [nodeId].
  ///
  /// Returns `null` when the node is not tracked (no advertisement seen).
  MeshNeighbor? setConnectionState(String nodeId, MeshLinkState state) {
    final existing = _byId[nodeId];
    if (existing == null) return null;
    final updated = existing.copyWith(connectionState: state);
    _byId[nodeId] = updated;
    return updated;
  }

  /// Applies a connected-link RSSI reading without changing identity fields.
  MeshNeighbor? touchRssi(String nodeId, int rssiDb, DateTime seenAt) {
    final existing = _byId[nodeId];
    if (existing == null) return null;
    final smoothed = _smooth(existing.smoothedRssiDb, rssiDb);
    final updated = existing.copyWith(
      lastSeen: seenAt,
      latestRssiDb: rssiDb,
      smoothedRssiDb: smoothed,
      distanceEstimateMeters: MeshDistanceEstimator.estimate(smoothed.round()),
      connectionState: MeshLinkState.connected,
    );
    _byId[nodeId] = updated;
    return updated;
  }

  /// Removes stale entries (no observation within [ttl]) and returns the
  /// removed node ids — the self-healing trigger for routing/topology.
  List<String> expire(DateTime now, Duration ttl) {
    final removed = <String>[];
    _byId.removeWhere((nodeId, entry) {
      final stale = now.difference(entry.lastSeen) > ttl;
      if (stale) removed.add(nodeId);
      return stale;
    });
    return removed;
  }

  /// Explicitly removes [nodeId]; returns the removed entry, or `null`.
  MeshNeighbor? remove(String nodeId) => _byId.remove(nodeId);

  double _smooth(double? previous, int rssiDb) {
    final raw = rssiDb.toDouble();
    if (previous == null) return raw.clamp(_rssiFloor, 0.0);
    return (previous * (1 - _emaAlpha) + raw * _emaAlpha)
        .clamp(_rssiFloor, 0.0)
        .toDouble();
  }
}
