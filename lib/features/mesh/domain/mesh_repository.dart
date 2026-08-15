import 'package:onebit/core/result/result.dart';
import 'mesh_diagnostics.dart';
import 'mesh_engine_state.dart';
import 'mesh_events.dart';
import 'mesh_neighbor.dart';
import 'mesh_network_status.dart';
import 'mesh_route.dart';
import 'mesh_statistics.dart';
import 'mesh_topology.dart';

/// Outcome of a `send` attempt.
sealed class MeshSendResult {
  const MeshSendResult();
}

/// The packet was handed to [nextHop] for [destination].
final class MeshSendForwarded extends MeshSendResult {
  const MeshSendForwarded({
    required this.destination,
    required this.nextHop,
    required this.hopCount,
  });

  final String destination;
  final String nextHop;
  final int hopCount;
}

/// The destination was the local node; delivered immediately.
final class MeshSendDeliveredLocally extends MeshSendResult {
  const MeshSendDeliveredLocally(this.destination);

  final String destination;
}

/// No route existed; a discovery request was broadcast.
final class MeshSendDiscoveryPending extends MeshSendResult {
  const MeshSendDiscoveryPending(this.destination);

  final String destination;
}

/// Contract the presentation layer consumes.
///
/// All streams are broadcast, `Result`-wrapped and never throw: transport
/// hiccups surface as [Err] emissions so the UI can degrade gracefully.
abstract interface class MeshRepository {
  /// Starts the engine (idempotent).
  Future<Result<void>> start();

  /// Stops the engine (idempotent).
  Future<Result<void>> stop();

  /// Sends opaque [payload] to [destination].
  Future<Result<MeshSendResult>> send({
    required String destination,
    required List<int> payload,
    int ttl = 8,
  });

  /// Broadcasts a route-discovery request for [destination].
  Future<Result<void>> discoverRoute(String destination);

  Stream<Result<List<MeshNeighbor>>> observeNeighbors();
  Stream<Result<List<MeshRoute>>> observeRoutes();
  Stream<Result<TopologySnapshot>> observeTopology();
  Stream<Result<MeshStatistics>> observeStatistics();
  Stream<Result<MeshNetworkStatus>> observeNetworkStatus();
  Stream<Result<MeshDiagnostics>> observeDiagnostics();
  Stream<Result<MeshRelayEvent>> observeRelayEvents();
  Stream<Result<MeshNeighborEvent>> observeNeighborEvents();
  Stream<Result<MeshRouteChangedEvent>> observeRouteEvents();
  Stream<Result<MeshEngineState>> observeState();
}
