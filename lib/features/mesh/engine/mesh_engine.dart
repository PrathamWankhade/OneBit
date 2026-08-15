import 'dart:async';

import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/features/mesh/cache/duplicate_packet_detector.dart';
import 'package:onebit/features/mesh/diagnostics/mesh_diagnostics_builder.dart';
import 'package:onebit/features/mesh/domain/mesh_clock.dart';
import 'package:onebit/features/mesh/domain/mesh_diagnostics.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_events.dart';
import 'package:onebit/features/mesh/domain/mesh_neighbor.dart';
import 'package:onebit/features/mesh/domain/mesh_network_status.dart';
import 'package:onebit/features/mesh/domain/mesh_packet.dart';
import 'package:onebit/features/mesh/domain/mesh_repository.dart';
import 'package:onebit/features/mesh/domain/mesh_route.dart';
import 'package:onebit/features/mesh/domain/mesh_statistics.dart';
import 'package:onebit/features/mesh/domain/mesh_topology.dart';
import 'package:onebit/features/mesh/domain/mesh_transport.dart';
import 'package:onebit/features/mesh/metrics/network_monitor.dart';
import 'package:onebit/features/mesh/metrics/rssi_history.dart';
import 'package:onebit/features/mesh/neighbor/neighbor_discovery_engine.dart';
import 'package:onebit/features/mesh/neighbor/neighbor_table.dart';
import 'package:onebit/features/mesh/relay/relay_decision.dart';
import 'package:onebit/features/mesh/relay/relay_engine.dart';
import 'package:onebit/features/mesh/relay/relay_queue.dart';
import 'package:onebit/features/mesh/relay/ttl_manager.dart';
import 'package:onebit/features/mesh/routing/loop_detector.dart';
import 'package:onebit/features/mesh/routing/packet_factory.dart';
import 'package:onebit/features/mesh/routing/route_optimizer.dart';
import 'package:onebit/features/mesh/routing/route_table.dart';
import 'package:onebit/features/mesh/routing/routing_engine.dart';
import 'package:onebit/features/mesh/statistics/mesh_statistics_tracker.dart';
import 'package:onebit/features/mesh/topology/topology_manager.dart';

/// The mesh composition root.
///
/// Wires every sub-engine to a [MeshTransport] and drives the periodic
/// sweep (neighbor/route expiry, duplicate-cache eviction, relay-queue
/// drain) on the injected [MeshClock]. All timestamps flow through the
/// clock; callers using [SystemMeshClock] get real-time behaviour and
/// tests use a [ManualMeshClock].
final class MeshEngine {
  MeshEngine({
    required this.localNodeId,
    required this._transport,
    required this._clock,
    this._logger,
    this.neighborTtl = const Duration(seconds: 90),
    this.routeTtl = const Duration(minutes: 5),
    this.rssiHistoryTtl = const Duration(minutes: 2),
    this.sweepInterval = const Duration(seconds: 5),
    this.duplicateCapacity = 2048,
    this.duplicateWindow = const Duration(seconds: 10),
    this.relayQueueCapacity = 64,
    this.maxAlternatives = 3,
    this.defaultTtl = 8,
  }) {
    _neighborTable = NeighborTable();
    _discovery = NeighborDiscoveryEngine(
      table: _neighborTable,
      neighborTtl: neighborTtl,
    );
    _optimizer = RouteOptimizer();
    _routeTable = RouteTable(
      time: _clock.now,
      maxAlternatives: maxAlternatives,
    );
    _factory = MeshPacketFactory(localNodeId: localNodeId, now: _clock.now);
    _loopDetector = const LoopDetector();
    _routing = RoutingEngine(
      localNodeId: localNodeId,
      now: _clock.now,
      table: _routeTable,
      optimizer: _optimizer,
      factory: _factory,
      neighborOf: _discovery.neighbor,
    );
    _ttl = TTLManager(defaultTtl: defaultTtl);
    _duplicates = DuplicatePacketDetector(
      capacity: duplicateCapacity,
      window: duplicateWindow,
      now: _clock.now,
    );
    _queue = InMemoryRelayQueue(capacity: relayQueueCapacity);
    _relay = RelayEngine(
      localNodeId: localNodeId,
      routing: _routing,
      ttl: _ttl,
      loopDetector: _loopDetector,
      duplicateDetector: _duplicates,
      queue: _queue,
      liveNeighborIds: () => _discovery
          .snapshot()
          .where((n) => n.connectionState != MeshLinkState.disconnected)
          .map((n) => n.nodeId)
          .toList(),
      now: _clock.now,
    );
    _topology = TopologyManager(
      localNodeId: localNodeId,
      neighbors: () => _discovery.snapshot(),
      primaryRoutes: _routing.primaryRoutes,
      now: _clock.now,
    );
    _statistics = MeshStatisticsTracker(now: _clock.now);
    _monitor = NetworkMonitor(
      neighbors: () => _discovery.snapshot(),
      primaryRoutes: _routing.primaryRoutes,
      engineState: () => _state,
      statistics: _statistics.snapshot,
      partitions: () => _topology.snapshot().partitions,
    );
    _rssiHistory = MeshRssiHistory();
    _diagnostics = MeshDiagnosticsBuilder(
      localNodeId: localNodeId,
      engineState: () => _state,
      radioState: () => _radio,
      neighbors: () => _discovery.snapshot(),
      routes: _routing.primaryRoutes,
      topology: _topology.snapshot,
      statistics: _statistics.snapshot,
      network: () => _monitor.status(_clock.now()),
      duplicateCache: _duplicateCacheStats,
      trackedRssiNodes: () => _rssiHistory.trackedNodes,
    );
  }

  final String localNodeId;
  final MeshTransport _transport;
  final MeshClock _clock;
  final AppLogger? _logger;

  final Duration neighborTtl;
  final Duration routeTtl;
  final Duration rssiHistoryTtl;
  final Duration sweepInterval;
  final int duplicateCapacity;
  final Duration duplicateWindow;
  final int relayQueueCapacity;
  final int maxAlternatives;
  final int defaultTtl;

  static const Duration _discoveryCooldown = Duration(seconds: 10);

  late final NeighborTable _neighborTable;
  late final NeighborDiscoveryEngine _discovery;
  late final MeshPacketFactory _factory;
  late final RouteTable _routeTable;
  late final RouteOptimizer _optimizer;
  late final LoopDetector _loopDetector;
  late final RoutingEngine _routing;
  late final TTLManager _ttl;
  late final DuplicatePacketDetector _duplicates;
  late final InMemoryRelayQueue _queue;
  late final RelayEngine _relay;
  late final TopologyManager _topology;
  late final MeshStatisticsTracker _statistics;
  late final NetworkMonitor _monitor;
  late final MeshDiagnosticsBuilder _diagnostics;
  late final MeshRssiHistory _rssiHistory;

  final Map<String, DateTime> _lastDiscoveryAt = {};
  MeshEngineState _state = MeshEngineState.stopped;
  MeshRadioState _radio = MeshRadioState.unknown;
  DateTime? _startedAt;
  StreamSubscription<MeshTransportEvent>? _subscription;
  MeshScheduledTask? _pendingTick;
  String? _scanId;
  String? _advertisingId;

  final StreamController<MeshEngineState> _stateController =
      StreamController<MeshEngineState>.broadcast();
  final StreamController<TopologySnapshot> _topologyController =
      StreamController<TopologySnapshot>.broadcast();
  final StreamController<MeshNetworkStatus> _networkController =
      StreamController<MeshNetworkStatus>.broadcast();
  final StreamController<MeshStatistics> _statsController =
      StreamController<MeshStatistics>.broadcast();
  final StreamController<MeshDiagnostics> _diagnosticsController =
      StreamController<MeshDiagnostics>.broadcast();
  final StreamController<MeshPacket> _deliveredController =
      StreamController<MeshPacket>.broadcast();

  MeshEngineState get state => _state;
  MeshRadioState get radioState => _radio;
  DateTime? get startedAt => _startedAt;
  bool get isRunning =>
      _state == MeshEngineState.running || _state == MeshEngineState.degraded;

  Stream<MeshEngineState> get stateStream => _stateController.stream;
  Stream<MeshNeighborEvent> get neighborEvents => _discovery.events;
  Stream<MeshRouteChangedEvent> get routeEvents => _routing.events;
  Stream<MeshRelayEvent> get relayEvents => _relay.events;
  Stream<TopologySnapshot> get topologyStream => _topologyController.stream;
  Stream<MeshNetworkStatus> get networkStatusStream =>
      _networkController.stream;
  Stream<MeshStatistics> get statisticsStream => _statsController.stream;
  Stream<MeshDiagnostics> get diagnosticsStream =>
      _diagnosticsController.stream;
  Stream<MeshPacket> get deliveredUpStream => _deliveredController.stream;

  List<MeshNeighbor> get neighbors => _discovery.snapshot();
  List<MeshRoute> get routes => _routing.primaryRoutes();
  TopologySnapshot get topologySnapshot => _topology.snapshot();
  MeshStatistics get statisticsSnapshot => _statistics.snapshot();
  MeshNetworkStatus get networkStatus => _monitor.status(_clock.now());
  MeshDiagnostics get diagnosticsSnapshot => _diagnostics.build();
  MeshRssiHistory get rssiHistory => _rssiHistory;
  NeighborTable get neighborTable => _neighborTable;

  /// Starts the engine. Idempotent.
  Future<void> start() async {
    if (_state != MeshEngineState.stopped) return;
    _state = MeshEngineState.starting;
    _startedAt = _clock.now();
    _emitState();

    _subscription = _transport.events.listen(
      _onTransportEvent,
      onError: (Object error) {
        _logger?.error(
          'Mesh transport stream error',
          tag: LogTags.mesh,
          error: error,
        );
      },
      onDone: () {
        _logger?.warning('Mesh transport stream ended', tag: LogTags.mesh);
      },
    );

    final scan = await _transport.startScan();
    if (scan.isOk) {
      _scanId = scan.value;
    } else {
      _logger?.warning(
        'Scan start failed',
        tag: LogTags.mesh,
        error: '${scan.failure}',
      );
    }
    final advertising = await _transport.startAdvertising();
    if (advertising.isOk) {
      _advertisingId = advertising.value;
    } else {
      _logger?.warning(
        'Advertising start failed',
        tag: LogTags.mesh,
        error: '${advertising.failure}',
      );
    }

    _scheduleTick();
    _state = _radio == MeshRadioState.off
        ? MeshEngineState.degraded
        : MeshEngineState.running;
    _emitState();
    _refresh(emitAll: true);
  }

  /// Stops the engine. Idempotent.
  Future<void> stop() async {
    if (_state == MeshEngineState.stopped) return;
    _pendingTick?.cancel();
    _pendingTick = null;
    await _subscription?.cancel();
    _subscription = null;
    if (_scanId != null) {
      await _transport.stopScan(_scanId!);
      _scanId = null;
    }
    if (_advertisingId != null) {
      await _transport.stopAdvertising(_advertisingId!);
      _advertisingId = null;
    }
    _state = MeshEngineState.stopped;
    _emitState();
  }

  /// Sends opaque [payload] to [destination].
  ///
  /// Returns [MeshSendForwarded] when a hop accepted the packet,
  /// [MeshSendDeliveredLocally] for the local node, or
  /// [MeshSendDiscoveryPending] when no route existed and a discovery
  /// request was broadcast (also covers relay drops such as a full queue).
  MeshSendResult send({
    required String destination,
    required List<int> payload,
    int ttl = 8,
  }) {
    final packet = _factory.originData(
      destination: destination,
      payload: payload,
      ttl: ttl,
    );
    final route = destination == localNodeId
        ? null
        : _routing.route(destination);
    final outcome = _relay.decide(packet, origin: true);
    switch (outcome) {
      case RelayDeliverUp():
        _statistics.recordDeliverUp();
        _deliveredController.add(packet);
        return MeshSendDeliveredLocally(destination);
      case RelayQueued(:final forwards):
        for (final task in forwards) {
          _statistics.recordForward();
          unawaited(_sendQueued(task));
          _relay.removeQueued(task);
        }
        final nextHop = forwards.isEmpty
            ? (route?.nextHop ?? '')
            : forwards.first.to;
        return MeshSendForwarded(
          destination: destination,
          nextHop: nextHop,
          hopCount: forwards.isEmpty ? route?.hopCount ?? 0 : 1,
        );
      case RelayDropped(:final packet, :final reason):
        if (reason == RelayDropReason.noRoute && !packet.isBroadcast) {
          _maybeDiscovery(destination);
        }
        return MeshSendDiscoveryPending(destination);
    }
  }

  /// Broadcasts a route-discovery request for [destination].
  void discoverRoute(String destination) {
    _maybeDiscovery(destination);
  }

  void _onTransportEvent(MeshTransportEvent event) {
    switch (event) {
      case NeighborAdvertisementSeen():
        final isNew = _discovery.handle(event);
        _rssiHistory.record(event.nodeId, event.rssiDb, event.timestamp);
        if (isNew) {
          _statistics.recordNeighborJoin();
          _topologyController.add(_topology.snapshot());
        }
        _routing.offerDirect(event.nodeId);
      case LinkStateChanged():
        _discovery.handle(event);
        if (event.state == MeshLinkState.connected) {
          _routing.offerDirect(event.nodeId);
        }
      case RssiObserved():
        _discovery.handle(event);
        _rssiHistory.record(event.nodeId, event.rssiDb, event.timestamp);
      case PacketReceived(:final packet):
        _onPacketReceived(packet);
      case RadioChanged():
        _onRadioChanged(event.state);
      case ScanStateChanged():
      case BatterySaverChanged():
    }
  }

  void _onRadioChanged(MeshRadioState radio) {
    _radio = radio;
    if (radio == MeshRadioState.off) {
      if (_state == MeshEngineState.running) {
        _state = MeshEngineState.degraded;
        _emitState();
      }
    } else if (_state == MeshEngineState.degraded) {
      _state = MeshEngineState.running;
      _emitState();
      unawaited(_rearm());
    }
    _refresh(emitAll: true);
  }

  Future<void> _rearm() async {
    final scan = await _transport.startScan();
    if (scan.isOk) {
      _scanId = scan.value;
    } else {
      _logger?.warning(
        'Scan re-arm failed',
        tag: LogTags.mesh,
        error: '${scan.failure}',
      );
    }
  }

  void _onPacketReceived(MeshPacket packet) {
    _statistics.recordPacketSeen();

    final fromNode = packet.path.isEmpty ? packet.source : packet.path.last;
    if (fromNode != localNodeId) {
      _routing.learnRouteFromPacket(packet, fromNode);
    }

    if (packet.control != null) {
      final reply = _routing.ingestControl(packet, fromNode);
      if (reply != null) {
        _statistics.recordDiscoveryLearned();
        _dispatchLocal(reply);
      }
    }

    final outcome = _relay.decide(packet);
    _applyOutcome(outcome);
  }

  /// Feeds a locally-originated packet through the relay pipeline,
  /// bypassing the own-packet drop.
  void _dispatchLocal(MeshPacket packet) {
    final outcome = _relay.decide(packet, origin: true);
    _applyOutcome(outcome);
  }

  void _applyOutcome(RelayOutcome outcome) {
    switch (outcome) {
      case RelayDeliverUp(:final packet):
        _statistics.recordDeliverUp();
        _deliveredController.add(packet);
      case RelayQueued(:final forwards):
        for (final task in forwards) {
          _statistics.recordForward();
          unawaited(_sendQueued(task));
          _relay.removeQueued(task);
        }
      case RelayDropped(:final packet, :final reason):
        _statistics.recordDrop(reason);
        if (reason == RelayDropReason.noRoute &&
            !packet.isBroadcast &&
            packet.destination.isNotEmpty &&
            packet.destination != localNodeId) {
          _maybeDiscovery(packet.destination);
        }
    }
  }

  Future<void> _sendQueued(RelayTask task) async {
    final result = await _transport.send(task.to, task.packet);
    if (result.isOk) {
      _routing.noteForwardOutcome(task.to, true);
    } else {
      _routing.noteForwardOutcome(task.to, false);
      if (_routing.relayFailed(task.packet.destination) &&
          !task.packet.isBroadcast) {
        _maybeDiscovery(task.packet.destination);
      }
    }
  }

  void _maybeDiscovery(String destination) {
    if (destination.isEmpty || destination == localNodeId) return;
    final last = _lastDiscoveryAt[destination];
    final now = _clock.now();
    if (last != null && now.difference(last) < _discoveryCooldown) return;
    _lastDiscoveryAt[destination] = now;
    final request = _routing.discover(destination);
    if (request != null) {
      _statistics.recordDiscoveryIssued();
      _dispatchLocal(request);
    }
  }

  void _tick() {
    if (_state == MeshEngineState.stopped) return;
    final now = _clock.now();

    for (final nodeId in _discovery.sweep(now)) {
      _statistics.recordNeighborLeave();
      final lost = _routing.neighborLost(nodeId);
      for (final destination in lost) {
        _maybeDiscovery(destination);
      }
    }

    _routing.expire(now, routeTtl);
    _duplicates.sweep(now);

    RelayTask? task;
    while (true) {
      task = _relay.dequeue();
      if (task == null) break;
      _statistics.recordForward();
      unawaited(_sendQueued(task));
    }

    _rssiHistory.prune(now.subtract(rssiHistoryTtl));
    _refresh(emitAll: true);
    _scheduleTick();
  }

  void _scheduleTick() {
    _pendingTick = _clock.schedule(sweepInterval, _tick);
  }

  void _refresh({required bool emitAll}) {
    _statistics.syncDuplicateCache(
      hits: _duplicates.hits,
      evictions: _duplicates.evictions,
      size: _duplicates.size,
      capacity: _duplicates.capacity,
    );
    if (!emitAll) return;
    _topologyController.add(_topology.snapshot());
    _networkController.add(_monitor.status(_clock.now()));
    _statsController.add(_statistics.snapshot());
    _diagnosticsController.add(_diagnostics.build());
  }

  void _emitState() => _stateController.add(_state);

  DuplicateCacheStats _duplicateCacheStats() {
    return DuplicateCacheStats(
      capacity: _duplicates.capacity,
      entries: _duplicates.size,
      hits: _duplicates.hits,
      evictions: _duplicates.evictions,
      ttlSeconds: duplicateWindow.inSeconds,
    );
  }

  void dispose() {
    unawaited(stop());
    _topologyController.close();
    _networkController.close();
    _statsController.close();
    _diagnosticsController.close();
    _deliveredController.close();
    _stateController.close();
    _discovery.dispose();
    _routing.dispose();
    _relay.dispose();
  }
}
