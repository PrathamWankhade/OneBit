import 'dart:async';

import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/mesh/domain/mesh_diagnostics.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_events.dart';
import 'package:onebit/features/mesh/domain/mesh_neighbor.dart';
import 'package:onebit/features/mesh/domain/mesh_network_status.dart';
import 'package:onebit/features/mesh/domain/mesh_repository.dart';
import 'package:onebit/features/mesh/domain/mesh_route.dart';
import 'package:onebit/features/mesh/domain/mesh_statistics.dart';
import 'package:onebit/features/mesh/domain/mesh_topology.dart';
import 'package:onebit/features/mesh/engine/mesh_engine.dart';

/// Bridges [MeshEngine] to the [MeshRepository] contract.
///
/// Every stream is broadcast and `Result`-wrapped; engine state is replayed
/// on subscription (value streams) while event streams are live-only.
final class MeshRepositoryImpl implements MeshRepository {
  MeshRepositoryImpl({required this._engine}) {
    _stateController = StreamController<Result<MeshEngineState>>.broadcast(
      onListen: _onStateListened,
    );
    _neighborsController =
        StreamController<Result<List<MeshNeighbor>>>.broadcast(
          onListen: _onNeighborsListened,
        );
    _routesController = StreamController<Result<List<MeshRoute>>>.broadcast(
      onListen: _onRoutesListened,
    );
    _topologyController = StreamController<Result<TopologySnapshot>>.broadcast(
      onListen: _onTopologyListened,
    );
    _statisticsController = StreamController<Result<MeshStatistics>>.broadcast(
      onListen: _onStatisticsListened,
    );
    _networkController = StreamController<Result<MeshNetworkStatus>>.broadcast(
      onListen: _onNetworkListened,
    );
    _diagnosticsController =
        StreamController<Result<MeshDiagnostics>>.broadcast(
          onListen: _onDiagnosticsListened,
        );

    _stateSubscription = _engine.stateStream.listen(_emitState);
    _neighborEventsSubscription = _engine.neighborEvents.listen(
      (event) => _neighborsController.add(Ok(_engine.neighbors)),
    );
    _routeEventsSubscription = _engine.routeEvents.listen(
      (event) => _routesController.add(Ok(_engine.routes)),
    );
    _relayEventsSubscription = _engine.relayEvents
        .map<Result<MeshRelayEvent>>(Ok<MeshRelayEvent>.new)
        .listen(
          _relayController.add,
          onError: (Object error) {
            _relayController.add(Err(_wrap(error)));
          },
        );
    _neighborEventSubscription = _engine.neighborEvents
        .map<Result<MeshNeighborEvent>>(Ok<MeshNeighborEvent>.new)
        .listen(
          _neighborController.add,
          onError: (Object error) {
            _neighborController.add(Err(_wrap(error)));
          },
        );
    _routeEventSubscription = _engine.routeEvents
        .map<Result<MeshRouteChangedEvent>>(Ok<MeshRouteChangedEvent>.new)
        .listen(
          _routeController.add,
          onError: (Object error) {
            _routeController.add(Err(_wrap(error)));
          },
        );
    _topologySubscription = _engine.topologyStream
        .map<Result<TopologySnapshot>>(Ok<TopologySnapshot>.new)
        .listen(
          _topologyController.add,
          onError: (Object error) {
            _topologyController.add(Err(_wrap(error)));
          },
        );
    _networkSubscription = _engine.networkStatusStream
        .map<Result<MeshNetworkStatus>>(Ok<MeshNetworkStatus>.new)
        .listen(
          _networkController.add,
          onError: (Object error) {
            _networkController.add(Err(_wrap(error)));
          },
        );
    _statisticsSubscription = _engine.statisticsStream
        .map<Result<MeshStatistics>>(Ok<MeshStatistics>.new)
        .listen(
          _statisticsController.add,
          onError: (Object error) {
            _statisticsController.add(Err(_wrap(error)));
          },
        );
    _diagnosticsSubscription = _engine.diagnosticsStream
        .map<Result<MeshDiagnostics>>(Ok<MeshDiagnostics>.new)
        .listen(
          _diagnosticsController.add,
          onError: (Object error) {
            _diagnosticsController.add(Err(_wrap(error)));
          },
        );
  }

  final MeshEngine _engine;

  late final StreamController<Result<MeshEngineState>> _stateController;
  late final StreamController<Result<List<MeshNeighbor>>> _neighborsController;
  late final StreamController<Result<List<MeshRoute>>> _routesController;
  late final StreamController<Result<TopologySnapshot>> _topologyController;
  late final StreamController<Result<MeshStatistics>> _statisticsController;
  late final StreamController<Result<MeshNetworkStatus>> _networkController;
  late final StreamController<Result<MeshDiagnostics>> _diagnosticsController;

  final StreamController<Result<MeshRelayEvent>> _relayController =
      StreamController<Result<MeshRelayEvent>>.broadcast();
  final StreamController<Result<MeshNeighborEvent>> _neighborController =
      StreamController<Result<MeshNeighborEvent>>.broadcast();
  final StreamController<Result<MeshRouteChangedEvent>> _routeController =
      StreamController<Result<MeshRouteChangedEvent>>.broadcast();

  StreamSubscription<MeshEngineState>? _stateSubscription;
  StreamSubscription<MeshNeighborEvent>? _neighborEventsSubscription;
  StreamSubscription<MeshRouteChangedEvent>? _routeEventsSubscription;
  StreamSubscription<Result<MeshRelayEvent>>? _relayEventsSubscription;
  StreamSubscription<Result<MeshNeighborEvent>>? _neighborEventSubscription;
  StreamSubscription<Result<MeshRouteChangedEvent>>? _routeEventSubscription;
  StreamSubscription<Result<TopologySnapshot>>? _topologySubscription;
  StreamSubscription<Result<MeshNetworkStatus>>? _networkSubscription;
  StreamSubscription<Result<MeshStatistics>>? _statisticsSubscription;
  StreamSubscription<Result<MeshDiagnostics>>? _diagnosticsSubscription;

  @override
  Future<Result<void>> start() async {
    try {
      await _engine.start();
      return const Ok(null);
    } catch (error) {
      return Err(_wrap(error));
    }
  }

  @override
  Future<Result<void>> stop() async {
    try {
      await _engine.stop();
      return const Ok(null);
    } catch (error) {
      return Err(_wrap(error));
    }
  }

  @override
  Future<Result<MeshSendResult>> send({
    required String destination,
    required List<int> payload,
    int ttl = 8,
  }) async {
    try {
      final result = _engine.send(
        destination: destination,
        payload: payload,
        ttl: ttl,
      );
      return Ok(result);
    } catch (error) {
      return Err(_wrap(error));
    }
  }

  @override
  Future<Result<void>> discoverRoute(String destination) async {
    try {
      _engine.discoverRoute(destination);
      return const Ok(null);
    } catch (error) {
      return Err(_wrap(error));
    }
  }

  @override
  Stream<Result<List<MeshNeighbor>>> observeNeighbors() =>
      _neighborsController.stream;

  @override
  Stream<Result<List<MeshRoute>>> observeRoutes() => _routesController.stream;

  @override
  Stream<Result<TopologySnapshot>> observeTopology() =>
      _topologyController.stream;

  @override
  Stream<Result<MeshStatistics>> observeStatistics() =>
      _statisticsController.stream;

  @override
  Stream<Result<MeshNetworkStatus>> observeNetworkStatus() =>
      _networkController.stream;

  @override
  Stream<Result<MeshDiagnostics>> observeDiagnostics() =>
      _diagnosticsController.stream;

  @override
  Stream<Result<MeshRelayEvent>> observeRelayEvents() =>
      _relayController.stream;

  @override
  Stream<Result<MeshNeighborEvent>> observeNeighborEvents() =>
      _neighborController.stream;

  @override
  Stream<Result<MeshRouteChangedEvent>> observeRouteEvents() =>
      _routeController.stream;

  @override
  Stream<Result<MeshEngineState>> observeState() => _stateController.stream;

  void _onStateListened() => _emitState(_engine.state);
  void _onNeighborsListened() =>
      _neighborsController.add(Ok(_engine.neighbors));
  void _onRoutesListened() => _routesController.add(Ok(_engine.routes));
  void _onTopologyListened() =>
      _topologyController.add(Ok(_engine.topologySnapshot));
  void _onStatisticsListened() =>
      _statisticsController.add(Ok(_engine.statisticsSnapshot));
  void _onNetworkListened() =>
      _networkController.add(Ok(_engine.networkStatus));
  void _onDiagnosticsListened() =>
      _diagnosticsController.add(Ok(_engine.diagnosticsSnapshot));

  void _emitState(MeshEngineState state) => _stateController.add(Ok(state));

  Failure _wrap(Object error) {
    if (error is Failure) return error;
    return UnexpectedFailure(cause: error, message: 'Mesh repository error');
  }

  void dispose() {
    _stateSubscription?.cancel();
    _neighborEventsSubscription?.cancel();
    _routeEventsSubscription?.cancel();
    _relayEventsSubscription?.cancel();
    _neighborEventSubscription?.cancel();
    _routeEventSubscription?.cancel();
    _topologySubscription?.cancel();
    _networkSubscription?.cancel();
    _statisticsSubscription?.cancel();
    _diagnosticsSubscription?.cancel();
    _stateController.close();
    _neighborsController.close();
    _routesController.close();
    _topologyController.close();
    _statisticsController.close();
    _networkController.close();
    _diagnosticsController.close();
    _relayController.close();
    _neighborController.close();
    _routeController.close();
    _engine.dispose();
  }
}
