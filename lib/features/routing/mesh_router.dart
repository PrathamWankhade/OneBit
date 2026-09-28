/// Binds neighbor state, topology exchange, and the routing table
/// together so that OneBit can actually reach a peer it is not
/// directly connected to.
///
/// The pieces below this class (neighbor table, topology repository,
/// BFS route discovery, routing table, recovery) are all complete and
/// unit-tested. What was missing was the wiring: nothing ever called
/// [TopologyRepository.setLocalNeighbors], nothing ever pushed an
/// advertisement onto the wire, and nothing ever installed a route.
/// As a result every non-local send resolved to `NoRoute`.
///
/// ## Responsibilities
///
/// ```text
/// neighbor changes ──► set local topology edges
///                  ──► install / retire direct routes
///                  ──► advertise our edge set to neighbours
///                  ──► re-run BFS for indirectly known peers
///
/// inbound topologyAdvertisement packet
///                  ──► validate + record in the repository
///                  ──► re-run BFS for indirectly known peers
///
/// while neighbours exist ──► periodic re-advertisement
/// ```
///
/// ## What this does NOT do
///
/// - Does not create BLE connections (I7 owns that)
/// - Does not select the next hop (I8.7 [RoutingTable.bestRoute] does)
/// - Does not forward messages (I9.5 [MessageRelayService] does)
/// - Does not send or retry messages — [routesChanged] only announces
///   that the table moved, so whoever owns the outbox can try again
/// - Does not persist anything
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/protocol/onebit_packet.dart';
import 'package:onebit/features/protocol/packet_chunking.dart';
import 'package:onebit/features/protocol/packet_codec.dart';
import 'package:onebit/features/reliable/transfer.dart';
import 'package:onebit/features/routing/neighbor_entry.dart';
import 'package:onebit/features/routing/neighbor_table.dart';
import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/route_discovery.dart';
import 'package:onebit/features/routing/routing_table.dart';
import 'package:onebit/features/routing/routing_validators.dart';
import 'package:onebit/features/routing/topology_advertisement_codec.dart';
import 'package:onebit/features/routing/topology_exchange_service.dart';
import 'package:onebit/features/routing/topology_repository.dart';

/// Keeps the routing table in sync with the live topology.
class MeshRouter {
  MeshRouter({
    required this.localPeerId,
    required this.neighborTable,
    required this.topologyExchange,
    required this.topologyRepository,
    required this.routingTable,
    required this.bleService,
    required this.getReachableNeighbors,
    required this.discoverRoute,
    this.advertisementInterval = const Duration(seconds: 30),
  });

  /// Our own cryptographic identity. Every route must be for a
  /// 64-char lowercase hex peer ID, so the router stays inert until
  /// this is valid.
  final String localPeerId;

  final NeighborTable neighborTable;
  final TopologyExchangeService topologyExchange;
  final TopologyRepository topologyRepository;
  final RoutingTable routingTable;
  final BleService bleService;

  /// Returns the peers we can currently reach in one hop.
  final List<String> Function() getReachableNeighbors;

  /// BFS over the topology graph (I8.6).
  final DiscoveryResult Function({
    required String localPeerId,
    required String destinationPeerId,
  })
  discoverRoute;

  /// How often to refresh neighbours while we have any.
  final Duration advertisementInterval;

  StreamSubscription<List<NeighborEntry>>? _neighborSub;
  StreamSubscription<ReliableDataReceived>? _dataSub;
  Timer? _refreshTimer;

  int _packetIdCounter = 0;

  /// Puts the slices of a chunked advertisement back together on arrival.
  final _chunks = PacketChunkReassembler();
  bool _started = false;
  bool _disposed = false;

  /// The neighbor set we last put on the wire, used to avoid
  /// re-advertising an unchanged graph on every connection event.
  Set<String> _lastAdvertised = const {};

  /// The neighbour set as of the last sync, so departures are visible
  /// (the neighbour stream only ever emits live entries).
  Set<String> _activePeers = const {};

  /// Fires after routes were recomputed.
  ///
  /// Not the routes themselves — listeners care that *something* changed,
  /// so a message that previously had nowhere to go might now have a
  /// next hop.
  final _routesChanged = StreamController<void>.broadcast();

  /// Broadcast stream of route recomputation.
  Stream<void> get routesChanged => _routesChanged.stream;

  /// Whether the router is allowed to do anything at all.
  bool get _usable => !_disposed && RoutingValidators.isValidPeerId(localPeerId);

  /// Whether the router has been started.
  bool get isStarted => _started;

  /// Start listening. No-op if already started or if the local
  /// identity is not ready yet — the provider recreates the router
  /// once the identity loads.
  void start() {
    if (_started || _disposed) return;
    if (!RoutingValidators.isValidPeerId(localPeerId)) {
      AppLogger.info('MeshRouter: local peer ID not ready, staying inert');
      return;
    }
    _started = true;

    _neighborSub = neighborTable.neighborStream.listen(_onNeighbors);
    _dataSub = bleService.reliableDataReceived.listen(
      _onData,
      onError: (Object e) => AppLogger.error('MeshRouter: receive error', e),
    );

    // Sync immediately from whatever is already known.
    _onNeighbors(neighborTable.neighbors);
    AppLogger.info('MeshRouter: started for ${_short(localPeerId)}');
  }

  // ── Neighbor changes ──────────────────────────────────────

  void _onNeighbors(List<NeighborEntry> entries) {
    if (!_usable || !_started) return;

    final active = <String>{
      for (final entry in entries)
        if (entry.isActive) entry.peerId,
    };

    // 1. Publish our half of the graph. RouteDiscovery reads this to
    //    build the local edges of its adjacency list — without it the
    //    BFS never even sees our own neighbours.
    final reachable = getReachableNeighbors();
    topologyRepository.setLocalTopology(reachable.toSet());

    // 2. Direct routes: install for live neighbours, retire the rest.
    _syncDirectRoutes(active);

    // 3. A neighbour that left stops being a trustworthy witness for
    //    the peers it advertised. Drop that evidence before searching.
    for (final departed in _activePeers.difference(active)) {
      topologyExchange.onPeerDisconnected(departed);
      // Anything still routed through the departed hop is gone with it.
      routingTable.removeRoutesVia(departed);
    }
    _activePeers = active;

    // 4. Indirect routes from whatever topology we already hold.
    _refreshIndirectRoutes();

    // 5. Tell neighbours about the new edge set, but only when it
    //    actually changed — connection events fire often.
    final advertised = Set<String>.from(reachable)..addAll(active);
    if (advertised != _lastAdvertised) {
      _lastAdvertised = advertised;
      advertiseNow();
    }

    _syncRefreshTimer(active.isNotEmpty);
    _notifyRoutesChanged();
  }

  /// Let listeners know the next hop for something may have appeared
  /// or vanished. Never throws — a listener's failure must not undo
  /// the bookkeeping above.
  void _notifyRoutesChanged() {
    if (_disposed) return;
    try {
      _routesChanged.add(null);
    } catch (_) {
      // A closed controller during teardown is not worth reporting.
    }
  }

  void _syncDirectRoutes(Set<String> active) {
    // Retire routes for peers that are no longer reachable directly.
    // Removing by destination (rather than by entry) also clears any
    // stale alternative; step 4 below re-adds a viable indirect route
    // if the peer is still reachable the long way round.
    final noLongerDirect = <String>{
      for (final route in routingTable.allRoutes)
        if (route.source == RouteSource.direct &&
            !active.contains(route.destinationPeerId))
          route.destinationPeerId,
    };
    for (final destination in noLongerDirect) {
      routingTable.removeRoutesTo(destination);
    }

    final now = DateTime.now();
    for (final peerId in active) {
      if (peerId == localPeerId) continue;
      _addRoute(
        Route(
          destinationPeerId: peerId,
          nextHopPeerId: peerId,
          metric: 1,
          state: RouteState.active,
          source: RouteSource.direct,
          createdAt: now,
          lastValidatedAt: now,
        ),
      );
    }
  }

  /// Ask I8.6 for a path to every peer we know about but cannot
  /// currently reach, and install whatever it finds.
  ///
  /// Also retires advertised routes whose destination we can no longer
  /// justify — a peer that left, or an advertisement that aged out,
  /// must not leave a stale next-hop behind.
  void _refreshIndirectRoutes() {
    final known = <String>{
      ..._activePeers,
      ...topologyExchange.indirectlyKnownPeerIds,
    };

    final unjustified = <String>{
      for (final route in routingTable.allRoutes)
        if (route.source == RouteSource.advertised &&
            !known.contains(route.destinationPeerId))
          route.destinationPeerId,
    };
    for (final destination in unjustified) {
      routingTable.removeRoutesTo(destination);
    }

    for (final peerId in topologyExchange.indirectlyKnownPeerIds) {
      if (peerId == localPeerId) continue;
      if (routingTable.hasRouteTo(peerId)) continue;

      final result = discoverRoute(
        localPeerId: localPeerId,
        destinationPeerId: peerId,
      );
      if (result.isFound && result.route != null) {
        if (_addRoute(result.route!)) {
          AppLogger.info(
            'MeshRouter: learned indirect route to ${_short(peerId)} '
                'via ${_short(result.route!.nextHopPeerId)} '
                '(metric ${result.route!.metric})',
          );
        }
      }
    }
  }

  /// Add a route, swallowing validation failures. A malformed peer ID
  /// from an untrusted advertisement must not take the router down.
  bool _addRoute(Route route) {
    try {
      routingTable.addRoute(route);
      return true;
    } on RouteValidationException catch (e) {
      AppLogger.warning('MeshRouter: rejected route: ${e.message}');
      return false;
    }
  }

  // ── Outbound advertisement ────────────────────────────────

  /// Push our current neighbor set to every connected neighbour.
  ///
  /// An advertisement with more than one packet's worth of neighbours is
  /// split across them; each link still only ever carries one transfer at
  /// a time, so this queues behind whatever is already in flight rather
  /// than being turned away.
  Future<void> advertiseNow() async {
    if (!_usable || !_started) return;

    final advertisement = topologyExchange.buildAdvertisementWithIncrement(
      localPeerId: localPeerId,
    );

    final Uint8List adBytes;
    try {
      adBytes = TopologyAdvertisementCodec.encode(advertisement);
    } catch (e) {
      AppLogger.warning('MeshRouter: could not encode advertisement: $e');
      return;
    }

    final packetId = _nextPacketId();

    final neighbors = neighborTable.neighbors;
    if (neighbors.isEmpty) return;

    for (final neighbor in neighbors) {
      final deviceId = neighbor.bleDeviceId;
      if (deviceId == null) continue;
      unawaited(
        sendInPackets(
          adBytes,
          type: PacketType.topologyAdvertisement,
          packetId: packetId,
          send: (bytes) => bleService.sendReliable(deviceId, bytes),
        ).then(
          (result) {
            if (result != TransferResult.delivered) {
              AppLogger.info(
                'MeshRouter: advertisement to ${_short(neighbor.peerId)} '
                    'not delivered ($result)',
              );
            }
          },
          onError: (Object e) => AppLogger.info(
            'MeshRouter: advertisement to ${_short(neighbor.peerId)} '
                'failed: $e',
          ),
        ),
      );
    }
  }

  // ── Inbound advertisement ─────────────────────────────────

  void _onData(ReliableDataReceived data) {
    if (!_usable || !_started) return;

    final OneBitPacket packet;
    try {
      packet = PacketCodec.decode(Uint8List.fromList(data.payload));
    } catch (_) {
      return; // Not our packet — MessageTransport logs it.
    }

    if (packet.type != PacketType.topologyAdvertisement) return;

    final payload = _chunks.accept(
      data.deviceId,
      packet.packetId,
      Uint8List.fromList(packet.payload),
    );
    if (payload == null) return; // still assembling

    final outcome = topologyExchange.processRawAdvertisement(
      bytes: payload,
      localPeerId: localPeerId,
    );

    switch (outcome.result) {
      case AdvertisementResult.accepted:
        AppLogger.info(
          'MeshRouter: accepted topology from a peer '
              '(${payload.length} bytes)',
        );
        _refreshIndirectRoutes();
        _notifyRoutesChanged();
      case AdvertisementResult.rejectedStale:
      case AdvertisementResult.rejectedMalformed:
      case AdvertisementResult.rejectedSelfSource:
      case AdvertisementResult.rejectedSelfLoop:
        AppLogger.info(
          'MeshRouter: topology rejected: ${outcome.result.name}',
        );
    }
  }

  // ── Refresh timer ─────────────────────────────────────────

  /// Advertise periodically, but only while there is somebody to
  /// advertise to. An idle app holds no timer.
  void _syncRefreshTimer(bool hasNeighbors) {
    if (_disposed) return;

    if (hasNeighbors && _refreshTimer == null) {
      _refreshTimer = Timer.periodic(advertisementInterval, (_) {
        // Force a refresh even if the edge set is unchanged.
        _lastAdvertised = const {};
        advertiseNow();
      });
    } else if (!hasNeighbors && _refreshTimer != null) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  int _nextPacketId() {
    _packetIdCounter = (_packetIdCounter + 1) & 0xFF;
    return _packetIdCounter;
  }

  static String _short(String id) =>
      id.length >= 8 ? '${id.substring(0, 8)}...' : id;

  /// Tear down. Idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _started = false;
    _neighborSub?.cancel();
    _neighborSub = null;
    _dataSub?.cancel();
    _dataSub = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _routesChanged.close();
  }
}
