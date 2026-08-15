import 'dart:async';

import 'package:onebit/features/mesh/domain/mesh_events.dart';
import 'package:onebit/features/mesh/domain/mesh_neighbor.dart';
import 'package:onebit/features/mesh/domain/mesh_transport.dart';
import '../neighbor/neighbor_table.dart';

/// Turns [MeshTransportEvent] observations into neighbor state.
///
/// Pure projection logic: the engine per event dispatches here. Emits
/// [MeshNeighborEvent]s (seen / left / link changed) so routing and
/// topology can react to churn immediately.
final class NeighborDiscoveryEngine {
  NeighborDiscoveryEngine({required this._table, required this.neighborTtl});

  final NeighborTable _table;
  final Duration neighborTtl;

  final StreamController<MeshNeighborEvent> _events =
      StreamController<MeshNeighborEvent>.broadcast();

  /// Neighbor lifecycle events.
  Stream<MeshNeighborEvent> get events => _events.stream;

  /// Applies one transport event. Returns `true` when it changed state.
  bool handle(MeshTransportEvent event) {
    switch (event) {
      case NeighborAdvertisementSeen(
        :final nodeId,
        :final rssiDb,
        :final timestamp,
        :final advertisement,
      ):
        final result = _table.upsertAdvertisement(
          nodeId,
          rssiDb,
          timestamp,
          capabilities: advertisement?.capabilities,
        );
        _events.add(MeshNeighborSeen(nodeId, result.isNew));
        return result.isNew;
      case LinkStateChanged(:final nodeId, :final state):
        final updated = _table.setConnectionState(nodeId, state);
        if (updated == null) return false;
        _events.add(MeshNeighborLinkChanged(nodeId, state));
        return true;
      case RssiObserved(:final nodeId, :final rssiDb, :final timestamp):
        final updated = _table.touchRssi(nodeId, rssiDb, timestamp);
        return updated != null;
      case PacketReceived():
      case RadioChanged():
      case ScanStateChanged():
      case BatterySaverChanged():
        return false;
    }
  }

  /// Expires stale neighbors. Returns the removed node ids.
  List<String> sweep(DateTime now) {
    final removed = _table.expire(now, neighborTtl);
    for (final nodeId in removed) {
      _events.add(MeshNeighborLeft(nodeId));
    }
    return removed;
  }

  /// Removes [nodeId] explicitly (e.g. explicit link drop).
  void remove(String nodeId) {
    if (_table.remove(nodeId) == null) return;
    _events.add(MeshNeighborLeft(nodeId));
  }

  /// Latest neighbor snapshot.
  List<MeshNeighbor> snapshot() => _table.all;

  /// One neighbor, or `null`.
  MeshNeighbor? neighbor(String nodeId) => _table.byId(nodeId);

  /// Neighbor table (for direct table reads by other engines).
  NeighborTable get table => _table;

  void dispose() {
    _events.close();
  }
}
