import 'dart:async';

import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_events.dart';
import 'package:onebit/features/mesh/domain/mesh_neighbor.dart';
import 'package:onebit/features/mesh/domain/mesh_packet.dart';
import 'package:onebit/features/mesh/domain/mesh_route.dart';
import 'loop_detector.dart';
import 'packet_factory.dart';
import 'route_optimizer.dart';
import 'route_table.dart';

/// Owns routing: learning, adaptive selection, dissolution, repair, expiry.
///
/// Routes are learned passively — direct links, relayed packet paths and
/// discovery replies — and maintained adaptively by [RouteOptimizer].
/// Neighbor loss dissolves routes and reports unreachable destinations so
/// the engine can trigger discovery. Control packets (route discovery)
/// are answered here and routed back along the recorded path.
final class RoutingEngine {
  RoutingEngine({
    required this.localNodeId,
    required this._now,
    required this._table,
    required this._optimizer,
    required this._factory,
    required this._neighborOf,
  });

  final String localNodeId;
  final DateTime Function() _now;
  final RouteTable _table;
  final RouteOptimizer _optimizer;
  final MeshPacketFactory _factory;
  final MeshNeighbor? Function(String nodeId) _neighborOf;

  final LoopDetector _loopDetector = const LoopDetector();
  final Map<String, _HopReliability> _reliability = {};
  final StreamController<MeshRouteChangedEvent> _events =
      StreamController<MeshRouteChangedEvent>.broadcast();

  int _discoveriesIssued = 0;
  int _discoveriesLearned = 0;
  int _routeSwitches = 0;

  /// Routing-table changes (learned / switched / dissolved / expired).
  Stream<MeshRouteChangedEvent> get events => _events.stream;

  /// Route-discovery requests originated by the local node.
  int get discoveriesIssued => _discoveriesIssued;

  /// Routes learned from discovery replies.
  int get discoveriesLearned => _discoveriesLearned;

  /// Adaptive primary-route switches.
  int get routeSwitches => _routeSwitches;

  /// The primary route to [destination], or `null`.
  MeshRoute? route(String destination) => _table.primary(destination);

  /// Every cached route for [destination].
  List<MeshRoute> routesFor(String destination) =>
      _table.forDestination(destination);

  /// Primary route for every known destination, sorted by id.
  List<MeshRoute> primaryRoutes() {
    final routes = <MeshRoute>[];
    final destinations = _table.destinations.toList()..sort();
    for (final destination in destinations) {
      final primary = _table.primary(destination);
      if (primary != null) routes.add(primary);
    }
    return routes;
  }

  /// Success history (0..1) of [nextHop]; 1.0 when no samples yet.
  double reliabilityOf(String nextHop) => _reliability[nextHop]?.rate ?? 1.0;

  /// Records the outcome of a forward attempt to [nextHop].
  void noteForwardOutcome(String nextHop, bool success) {
    _reliability.putIfAbsent(nextHop, _HopReliability.new).record(success);
  }

  /// Refreshes the direct (hop count 1) route to a live neighbor.
  void offerDirect(String nodeId) {
    final neighbor = _neighborOf(nodeId);
    if (neighbor == null ||
        neighbor.connectionState == MeshLinkState.disconnected) {
      return;
    }
    _offerRoute(
      destination: nodeId,
      nextHop: nodeId,
      hopCount: 1,
      quality: neighbor.linkQuality,
    );
  }

  /// Learns a reverse route from a relayed packet: back to [packet.source]
  /// through [nodeId] the packet arrived from, at `hopCount + 1` hops.
  void learnRouteFromPacket(MeshPacket packet, String fromNode) {
    if (packet.source == localNodeId) return;
    final neighbor = _neighborOf(fromNode);
    if (neighbor == null) return;
    _offerRoute(
      destination: packet.source,
      nextHop: fromNode,
      hopCount: packet.hopCount + 1,
      quality: neighbor.linkQuality,
    );
  }

  /// Returns a brand-new route-discovery request broadcast for [target].
  MeshPacket? discover(String target) {
    if (target == localNodeId) return null;
    _discoveriesIssued++;
    return _factory.originDiscoveryRequest(target: target);
  }

  /// Handles an incoming control packet and returns the reply to emit when
  /// the request targets the local node, otherwise `null`.
  MeshPacket? ingestControl(MeshPacket packet, String fromNode) {
    final control = packet.control;
    if (control == null) return null;
    switch (control) {
      case RouteDiscoveryRequest():
        learnRouteFromPacket(packet, fromNode);
        if (control.target != localNodeId) return null;
        _discoveriesLearned++;
        return _factory.originDiscoveryReply(
          requester: packet.source,
          target: control.target,
          path: [...packet.path, localNodeId],
        );
      case RouteDiscoveryReply(:final path):
        _learnRouteFromDiscoveryReply(packet, fromNode, path);
    }
    return null;
  }

  /// The next relay on a discovery reply's recorded path, or `null` when
  /// this node is the requester (deliver) or the path is unknown.
  String? nextHopForControl(MeshPacket packet) {
    final control = packet.control;
    if (control is! RouteDiscoveryReply) return null;
    final index = control.path.indexOf(localNodeId);
    if (index <= 0) return null;
    final nextHop = control.path[index - 1];
    if (_loopDetector.wouldCreateLoop(packet, nextHop)) return null;
    return nextHop;
  }

  /// Dissolves routes through a departed neighbor. Returns the destinations
  /// that became fully unreachable — the repair trigger.
  List<String> neighborLost(String nodeId) {
    final affected = _table.dissolveThrough(nodeId);
    for (final destination in affected) {
      _events.add(
        MeshRouteChangedEvent(
          kind: MeshRouteChangeKind.dissolved,
          destination: destination,
          reason: 'next hop $nodeId gone',
        ),
      );
    }
    return affected
        .where((destination) => _table.primary(destination) == null)
        .toList();
  }

  /// Demotes the failed primary; returns whether an alternative remains.
  bool relayFailed(String destination) => _table.demotePrimary(destination);

  /// Drops routes untouched for [ttl]; returns destinations that lost their
  /// primary.
  List<String> expire(DateTime now, Duration ttl) => _table.expire(now, ttl);

  /// Marks every cached route to [destination] as freshly used.
  void touch(String destination) => _table.touch(destination);

  void _offerRoute({
    required String destination,
    required String nextHop,
    required int hopCount,
    required double quality,
  }) {
    final candidate = _optimizer.candidate(
      destination: destination,
      nextHop: nextHop,
      hopCount: hopCount,
      quality: quality,
      reliability: reliabilityOf(nextHop),
      now: _now(),
    );
    final before = _table.primary(destination);
    final becamePrimary = _optimizer.isBetter(
      candidate: candidate,
      current: before,
    );
    _table.install(candidate);
    if (!becamePrimary) return;

    if (before != null && before.nextHop != nextHop) {
      _routeSwitches++;
    }
    final kind = before == null
        ? MeshRouteChangeKind.learned
        : before.nextHop == nextHop
        ? MeshRouteChangeKind.learned
        : MeshRouteChangeKind.switched;
    _events.add(
      MeshRouteChangedEvent(
        kind: kind,
        destination: destination,
        route: _table.primary(destination),
        reason: 'via $nextHop cost=${candidate.cost.toStringAsFixed(2)}',
      ),
    );
  }

  void _learnRouteFromDiscoveryReply(
    MeshPacket packet,
    String fromNode,
    List<String> path,
  ) {
    final control = packet.control;
    if (control is! RouteDiscoveryReply) return;
    final localIndex = path.indexOf(localNodeId);
    if (localIndex < 0 || localIndex + 1 >= path.length) return;
    final towardTarget = path[localIndex + 1];
    final neighbor = _neighborOf(towardTarget);
    if (neighbor == null) return;
    _discoveriesLearned++;
    _offerRoute(
      destination: control.target,
      nextHop: towardTarget,
      hopCount: path.length - 1 - localIndex,
      quality: neighbor.linkQuality,
    );
  }

  void dispose() {
    _events.close();
  }
}

/// Success history of a next-hop relay, feeding route reliability.
final class _HopReliability {
  int _successes = 0;
  int _failures = 0;

  void record(bool success) {
    if (success) {
      _successes++;
    } else {
      _failures++;
    }
  }

  double get rate {
    final total = _successes + _failures;
    return total == 0 ? 1.0 : _successes / total;
  }
}
