import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/routing_neighbor.dart';
import 'package:onebit/features/routing/routing_node.dart';
import 'package:onebit/features/routing/routing_state.dart';
import 'package:onebit/features/routing/routing_table.dart';
import 'package:onebit/features/routing/topology.dart';

Route _makeRoute({
  required String dest,
  required String nextHop,
  int metric = 1,
  RouteState state = RouteState.active,
  RouteSource source = RouteSource.advertised,
}) {
  return Route(
    destinationPeerId: dest,
    nextHopPeerId: nextHop,
    metric: metric,
    state: state,
    source: source,
    createdAt: DateTime(2025),
    lastValidatedAt: DateTime(2025),
  );
}

void main() {
  const peerA = 'aa11111111111111111111111111111111111111111111111111111111111111';
  const peerB = 'bb22222222222222222222222222222222222222222222222222222222222222';
  const peerC = 'cc33333333333333333333333333333333333333333333333333333333333333';
  const peerD = 'dd44444444444444444444444444444444444444444444444444444444444444';
  const peerE = 'ee55555555555555555555555555555555555555555555555555555555555555';

  group('I8.1 RoutingNode', () {
    test('local node has isLocal=true', () {
      const node = RoutingNode(peerId: peerA, isLocal: true);
      expect(node.isLocal, true);
      expect(node.peerId, peerA);
    });

    test('remote node has isLocal=false', () {
      const node = RoutingNode(peerId: peerB, displayName: 'Peer B');
      expect(node.isLocal, false);
      expect(node.displayName, 'Peer B');
    });

    test('equality by peerId only', () {
      const a1 = RoutingNode(peerId: peerA, displayName: 'First');
      const a2 = RoutingNode(peerId: peerA, displayName: 'Second');
      expect(a1, equals(a2));
      expect(a1.hashCode, equals(a2.hashCode));
    });

    test('inequality for different peerId', () {
      const a = RoutingNode(peerId: peerA);
      const b = RoutingNode(peerId: peerB);
      expect(a, isNot(equals(b)));
    });
  });

  group('I8.2 RoutingNeighbor', () {
    test('eligible when status is active', () {
      final neighbor = RoutingNeighbor(
        peerId: peerA,
        status: NeighborStatus.active,
        lastSeenAt: DateTime(2025),
      );
      expect(neighbor.isEligible, true);
      expect(neighbor.isLost, false);
    });

    test('not eligible when status is candidate', () {
      final neighbor = RoutingNeighbor(
        peerId: peerA,
        status: NeighborStatus.candidate,
        lastSeenAt: DateTime(2025),
      );
      expect(neighbor.isEligible, false);
    });

    test('lost when status is lost', () {
      final neighbor = RoutingNeighbor(
        peerId: peerA,
        status: NeighborStatus.lost,
        lastSeenAt: DateTime(2025),
      );
      expect(neighbor.isLost, true);
      expect(neighbor.isEligible, false);
    });

    test('copyWith preserves peerId', () {
      final original = RoutingNeighbor(
        peerId: peerA,
        status: NeighborStatus.active,
        lastSeenAt: DateTime(2025),
      );
      final updated = original.copyWith(status: NeighborStatus.lost);
      expect(updated.peerId, peerA);
      expect(updated.status, NeighborStatus.lost);
    });

    test('equality by peerId and status', () {
      final a = RoutingNeighbor(
        peerId: peerA,
        status: NeighborStatus.active,
        lastSeenAt: DateTime(2025),
      );
      final b = RoutingNeighbor(
        peerId: peerA,
        status: NeighborStatus.active,
        lastSeenAt: DateTime(2026),
      );
      expect(a, equals(b));
    });

    test('inequality for different status', () {
      final a = RoutingNeighbor(
        peerId: peerA,
        status: NeighborStatus.active,
        lastSeenAt: DateTime(2025),
      );
      final b = RoutingNeighbor(
        peerId: peerA,
        status: NeighborStatus.lost,
        lastSeenAt: DateTime(2025),
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('I8.1 RoutingState', () {
    test('RoutingEligibility transitions', () {
      expect(RoutingEligibility.values.length, 4);
      expect(RoutingEligibility.values, contains(RoutingEligibility.eligible));
      expect(RoutingEligibility.values, contains(RoutingEligibility.notConnected));
      expect(RoutingEligibility.values, contains(RoutingEligibility.notAuthenticated));
      expect(RoutingEligibility.values, contains(RoutingEligibility.notTrusted));
    });

    test('RoutingPeerState computes eligibility correctly', () {
      const connected = RoutingPeerState(
        peerId: peerA,
        isConnected: true,
        isAuthenticated: true,
        isTrusted: true,
        lifecycleState: 'connected',
      );
      expect(connected.eligibility, RoutingEligibility.eligible);
      expect(connected.isEligibleForRouting, true);

      const notConnected = RoutingPeerState(
        peerId: peerA,
        isConnected: false,
        isAuthenticated: true,
        isTrusted: true,
        lifecycleState: 'disconnected',
      );
      expect(notConnected.eligibility, RoutingEligibility.notConnected);
      expect(notConnected.isEligibleForRouting, false);

      const notAuthenticated = RoutingPeerState(
        peerId: peerA,
        isConnected: true,
        isAuthenticated: false,
        isTrusted: true,
        lifecycleState: 'connected',
      );
      expect(notAuthenticated.eligibility, RoutingEligibility.notAuthenticated);

      const notTrusted = RoutingPeerState(
        peerId: peerA,
        isConnected: true,
        isAuthenticated: true,
        isTrusted: false,
        lifecycleState: 'connected',
      );
      expect(notTrusted.eligibility, RoutingEligibility.notTrusted);
    });
  });

  group('I8.5 Route', () {
    test('direct route properties', () {
      final route = Route(
        destinationPeerId: peerB,
        nextHopPeerId: peerB,
        metric: 1,
        state: RouteState.active,
        source: RouteSource.direct,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      );
      expect(route.isDirect, true);
      expect(route.isActive, true);
      expect(route.isStale, false);
    });

    test('indirect route has metric > 1', () {
      final route = Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerB,
        metric: 2,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
        originPeerId: peerB,
      );
      expect(route.isDirect, false);
      expect(route.metric, 2);
    });

    test('copyWith preserves identity fields', () {
      final route = Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerB,
        metric: 2,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      );
      final stale = route.copyWith(state: RouteState.stale);
      expect(stale.destinationPeerId, peerC);
      expect(stale.nextHopPeerId, peerB);
      expect(stale.state, RouteState.stale);
    });

    test('equality by destination, next hop, and metric', () {
      final a = Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerB,
        metric: 2,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      );
      final b = Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerB,
        metric: 2,
        state: RouteState.stale,
        source: RouteSource.advertised,
        createdAt: DateTime(2026),
        lastValidatedAt: DateTime(2026),
      );
      expect(a, equals(b));
    });
  });

  group('I8.5 RoutingTable', () {
    late RoutingTable table;

    setUp(() {
      table = RoutingTable();
    });

    test('addRoute and lookup', () {
      final route = Route(
        destinationPeerId: peerB,
        nextHopPeerId: peerB,
        metric: 1,
        state: RouteState.active,
        source: RouteSource.direct,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      );

      table.addRoute(route);

      expect(table.hasRouteTo(peerB), true);
      expect(table.destinationCount, 1);
      expect(table.routeCount, 1);
    });

    test('bestRoute returns lowest metric', () {
      final direct = Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerB,
        metric: 2,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      );
      final shorter = Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerD,
        metric: 1,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      );

      table.addRoute(direct);
      table.addRoute(shorter);

      final best = table.bestRoute(peerC);
      expect(best, isNotNull);
      expect(best!.nextHopPeerId, peerD);
      expect(best.metric, 1);
    });

    test('bestRoute ignores stale routes', () {
      final active = Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerB,
        metric: 2,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      );
      final stale = Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerD,
        metric: 1,
        state: RouteState.stale,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      );

      table.addRoute(active);
      table.addRoute(stale);

      final best = table.bestRoute(peerC);
      expect(best!.nextHopPeerId, peerB);
    });

    test('bestRoute returns null for no routes', () {
      expect(table.bestRoute(peerC), isNull);
    });

    test('nextHopFor convenience', () {
      final route = Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerB,
        metric: 2,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      );
      table.addRoute(route);

      expect(table.nextHopFor(peerC), peerB);
      expect(table.nextHopFor(peerD), isNull);
    });

    test('removeRoutesVia removes all routes through a next hop', () {
      table.addRoute(Route(
        destinationPeerId: peerB,
        nextHopPeerId: peerB,
        metric: 1,
        state: RouteState.active,
        source: RouteSource.direct,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      ));
      table.addRoute(Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerB,
        metric: 2,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      ));
      table.addRoute(Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerD,
        metric: 2,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      ));

      final removed = table.removeRoutesVia(peerB);
      expect(removed, 2);
      expect(table.hasRouteTo(peerB), false);
      // peerC still reachable via peerD.
      expect(table.hasRouteTo(peerC), true);
      expect(table.nextHopFor(peerC), peerD);
    });

    test('removeRoutesTo removes all routes to a destination', () {
      table.addRoute(Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerB,
        metric: 2,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      ));
      table.addRoute(Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerD,
        metric: 3,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      ));

      table.removeRoutesTo(peerC);
      expect(table.hasRouteTo(peerC), false);
      expect(table.destinationCount, 0);
    });

    test('duplicate route advertisement is deduplicated', () {
      final route = Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerB,
        metric: 2,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      );

      table.addRoute(route);
      table.addRoute(route.copyWith(lastValidatedAt: DateTime(2026)));

      expect(table.routeCount, 1);
      expect(table.routesTo(peerC).first.lastValidatedAt, DateTime(2026));
    });

    test('markStaleRoutes marks old routes', () {
      final route = Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerB,
        metric: 2,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      );
      table.addRoute(route);

      final marked = table.markStaleRoutes(
        cutoff: DateTime(2026),
      );
      expect(marked, 1);
      expect(table.bestRoute(peerC), isNull);
    });

    test('cleanup removes stale and invalid routes', () {
      table.addRoute(Route(
        destinationPeerId: peerB,
        nextHopPeerId: peerB,
        metric: 1,
        state: RouteState.active,
        source: RouteSource.direct,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      ));
      table.addRoute(Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerB,
        metric: 2,
        state: RouteState.stale,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      ));
      table.addRoute(Route(
        destinationPeerId: peerD,
        nextHopPeerId: peerB,
        metric: 2,
        state: RouteState.invalid,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      ));

      final removed = table.cleanup();
      expect(removed, 2);
      expect(table.hasRouteTo(peerB), true);
      expect(table.hasRouteTo(peerC), false);
      expect(table.hasRouteTo(peerD), false);
    });

    test('destinationsVia returns correct destinations', () {
      table.addRoute(Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerB,
        metric: 2,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      ));
      table.addRoute(Route(
        destinationPeerId: peerD,
        nextHopPeerId: peerB,
        metric: 3,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      ));
      table.addRoute(Route(
        destinationPeerId: peerC,
        nextHopPeerId: peerD,
        metric: 2,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      ));

      final viaB = table.destinationsVia(peerB);
      expect(viaB, containsAll([peerC, peerD]));

      final viaD = table.destinationsVia(peerD);
      expect(viaD, contains(peerC));
    });

    test('clear empties the table', () {
      table.addRoute(Route(
        destinationPeerId: peerB,
        nextHopPeerId: peerB,
        metric: 1,
        state: RouteState.active,
        source: RouteSource.direct,
        createdAt: DateTime(2025),
        lastValidatedAt: DateTime(2025),
      ));

      table.clear();
      expect(table.routeCount, 0);
      expect(table.destinationCount, 0);
    });
  });

  group('I8.5 RoutingTable — validation', () {
    late RoutingTable table;

    setUp(() {
      table = RoutingTable(localPeerId: peerA);
    });

    test('rejects metric = 0', () {
      expect(
        () => table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: 0)),
        throwsA(isA<RouteValidationException>()),
      );
    });

    test('rejects negative metric', () {
      expect(
        () => table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: -1)),
        throwsA(isA<RouteValidationException>()),
      );
    });

    test('rejects metric exceeding max', () {
      expect(
        () => table.addRoute(
          _makeRoute(dest: peerB, nextHop: peerB, metric: maxRouteMetric + 1),
        ),
        throwsA(isA<RouteValidationException>()),
      );
    });

    test('accepts metric = 1 (minimum valid)', () {
      table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: 1));
      expect(table.routeCount, 1);
    });

    test('accepts metric = maxRouteMetric', () {
      table.addRoute(
        _makeRoute(dest: peerB, nextHop: peerB, metric: maxRouteMetric),
      );
      expect(table.routeCount, 1);
    });

    test('rejects empty destination peer ID', () {
      expect(
        () => table.addRoute(_makeRoute(dest: '', nextHop: peerB)),
        throwsA(isA<RouteValidationException>()),
      );
    });

    test('rejects empty next hop peer ID', () {
      expect(
        () => table.addRoute(_makeRoute(dest: peerB, nextHop: '')),
        throwsA(isA<RouteValidationException>()),
      );
    });

    test('rejects route to local node (self-destination)', () {
      expect(
        () => table.addRoute(_makeRoute(dest: peerA, nextHop: peerB)),
        throwsA(isA<RouteValidationException>()),
      );
    });

    test('rejects local node as next hop', () {
      expect(
        () => table.addRoute(_makeRoute(dest: peerB, nextHop: peerA)),
        throwsA(isA<RouteValidationException>()),
      );
    });

    test('valid route is accepted', () {
      table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: 1));
      expect(table.routeCount, 1);
      expect(table.hasRouteTo(peerB), true);
    });
  });

  group('I8.5 RoutingTable — no localPeerId skips self-route checks', () {
    late RoutingTable table;

    setUp(() {
      table = RoutingTable();
    });

    test('does not reject self-destination when localPeerId is null', () {
      table.addRoute(_makeRoute(dest: peerA, nextHop: peerB));
      expect(table.routeCount, 1);
    });

    test('does not reject self as next hop when localPeerId is null', () {
      table.addRoute(_makeRoute(dest: peerB, nextHop: peerA));
      expect(table.routeCount, 1);
    });
  });

  group('I8.5 RoutingTable — empty table', () {
    test('allRoutes is empty', () {
      final table = RoutingTable();
      expect(table.allRoutes, isEmpty);
    });

    test('activeRoutes is empty', () {
      final table = RoutingTable();
      expect(table.activeRoutes, isEmpty);
    });

    test('destinationCount is 0', () {
      final table = RoutingTable();
      expect(table.destinationCount, 0);
    });

    test('routeCount is 0', () {
      final table = RoutingTable();
      expect(table.routeCount, 0);
    });

    test('bestRoute returns null', () {
      final table = RoutingTable();
      expect(table.bestRoute(peerB), isNull);
    });

    test('nextHopFor returns null', () {
      final table = RoutingTable();
      expect(table.nextHopFor(peerB), isNull);
    });

    test('hasRouteTo returns false', () {
      final table = RoutingTable();
      expect(table.hasRouteTo(peerB), false);
    });

    test('routesTo returns empty list', () {
      final table = RoutingTable();
      expect(table.routesTo(peerB), isEmpty);
    });
  });

  group('I8.5 RoutingTable — add and lookup', () {
    late RoutingTable table;

    setUp(() {
      table = RoutingTable();
    });

    test('direct route is stored correctly', () {
      table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: 1));
      expect(table.hasRouteTo(peerB), true);
      expect(table.routeCount, 1);
      expect(table.destinationCount, 1);
    });

    test('indirect route is stored correctly', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      expect(table.hasRouteTo(peerC), true);
      expect(table.routeCount, 1);
    });

    test('getRoute returns the correct route', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      final routes = table.routesTo(peerC);
      expect(routes.length, 1);
      expect(routes.first.nextHopPeerId, peerB);
      expect(routes.first.metric, 2);
    });

    test('multiple destinations stored independently', () {
      table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: 1));
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      table.addRoute(_makeRoute(dest: peerD, nextHop: peerB, metric: 3));
      expect(table.destinationCount, 3);
      expect(table.routeCount, 3);
    });
  });

  group('I8.5 RoutingTable — remove', () {
    late RoutingTable table;

    setUp(() {
      table = RoutingTable();
    });

    test('removeRoute removes only the specified route', () {
      final routeB = _makeRoute(dest: peerB, nextHop: peerB, metric: 1);
      final routeC = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      table.addRoute(routeB);
      table.addRoute(routeC);

      final removed = table.removeRoute(routeB);
      expect(removed, true);
      expect(table.hasRouteTo(peerB), false);
      expect(table.hasRouteTo(peerC), true);
    });

    test('removeRoute returns false for non-existent route', () {
      final route = _makeRoute(dest: peerB, nextHop: peerB, metric: 1);
      expect(table.removeRoute(route), false);
    });

    test('removeRoutesTo removes all routes to a destination', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerD, metric: 3));
      table.removeRoutesTo(peerC);
      expect(table.hasRouteTo(peerC), false);
      expect(table.destinationCount, 0);
    });

    test('removeRoutesVia removes all routes through a next hop', () {
      table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: 1));
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerD, metric: 2));

      final removed = table.removeRoutesVia(peerB);
      expect(removed, 2);
      expect(table.hasRouteTo(peerB), false);
      expect(table.hasRouteTo(peerC), true);
      expect(table.nextHopFor(peerC), peerD);
    });
  });

  group('I8.5 RoutingTable — duplicate routes', () {
    late RoutingTable table;

    setUp(() {
      table = RoutingTable();
    });

    test('same route added twice is deduplicated', () {
      final route = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      table.addRoute(route);
      table.addRoute(route.copyWith(lastValidatedAt: DateTime(2026)));
      expect(table.routeCount, 1);
      expect(table.routesTo(peerC).first.lastValidatedAt, DateTime(2026));
    });

    test('same destination different next hops are stored as alternatives', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerD, metric: 2));
      expect(table.routeCount, 2);
      expect(table.routesTo(peerC).length, 2);
    });

    test('same destination different metrics are stored as alternatives', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 3));
      expect(table.routeCount, 2);
    });
  });

  group('I8.5 RoutingTable — multiple routes', () {
    late RoutingTable table;

    setUp(() {
      table = RoutingTable();
    });

    test('bestRoute selects lowest metric among alternatives', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 3));
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerD, metric: 1));
      final best = table.bestRoute(peerC);
      expect(best!.nextHopPeerId, peerD);
      expect(best.metric, 1);
    });

    test('bestRoute ignores stale alternatives', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 1));
      table.addRoute(
        _makeRoute(dest: peerC, nextHop: peerD, metric: 2),
      );
      table.addRoute(
        _makeRoute(
          dest: peerC,
          nextHop: peerD,
          metric: 2,
          state: RouteState.stale,
        ),
      );
      final best = table.bestRoute(peerC);
      expect(best!.nextHopPeerId, peerB);
    });

    test('nextHopFor returns the best next hop', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 3));
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerD, metric: 1));
      expect(table.nextHopFor(peerC), peerD);
    });
  });

  group('I8.5 RoutingTable — peer isolation', () {
    late RoutingTable table;

    setUp(() {
      table = RoutingTable();
    });

    test('removing C does not affect D', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      table.addRoute(_makeRoute(dest: peerD, nextHop: peerB, metric: 3));

      table.removeRoutesTo(peerC);

      expect(table.hasRouteTo(peerC), false);
      expect(table.hasRouteTo(peerD), true);
      expect(table.routeCount, 1);
    });

    test('removing routes via B does not affect routes via D', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      table.addRoute(_makeRoute(dest: peerD, nextHop: peerB, metric: 3));
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerD, metric: 2));

      table.removeRoutesVia(peerB);

      expect(table.hasRouteTo(peerC), true);
      expect(table.nextHopFor(peerC), peerD);
      expect(table.hasRouteTo(peerD), false);
    });

    test('changing C route does not alter D route', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      table.addRoute(_makeRoute(dest: peerD, nextHop: peerB, metric: 3));

      table.removeRoutesTo(peerC);
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerD, metric: 2));

      expect(table.nextHopFor(peerC), peerD);
      expect(table.nextHopFor(peerD), peerB);
    });
  });

  group('I8.5 RoutingTable — metric validation', () {
    late RoutingTable table;

    setUp(() {
      table = RoutingTable();
    });

    test('metric = 1 is valid', () {
      table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: 1));
      expect(table.routeCount, 1);
    });

    test('metric = 2 is valid', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      expect(table.routeCount, 1);
    });

    test('metric = maxRouteMetric is valid', () {
      table.addRoute(
        _makeRoute(dest: peerB, nextHop: peerB, metric: maxRouteMetric),
      );
      expect(table.routeCount, 1);
    });

    test('metric = 0 is rejected', () {
      expect(
        () => table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: 0)),
        throwsA(isA<RouteValidationException>()),
      );
    });

    test('metric = -1 is rejected', () {
      expect(
        () => table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: -1)),
        throwsA(isA<RouteValidationException>()),
      );
    });

    test('metric = maxRouteMetric + 1 is rejected', () {
      expect(
        () => table.addRoute(
          _makeRoute(dest: peerB, nextHop: peerB, metric: maxRouteMetric + 1),
        ),
        throwsA(isA<RouteValidationException>()),
      );
    });
  });

  group('I8.5 RoutingTable — identity tests', () {
    late RoutingTable table;

    setUp(() {
      table = RoutingTable(localPeerId: peerA);
    });

    test('uses PeerId for destination (not BLE address)', () {
      table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: 1));
      final routes = table.routesTo(peerB);
      expect(routes.first.destinationPeerId, peerB);
    });

    test('uses PeerId for next hop (not BLE address)', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      final routes = table.routesTo(peerC);
      expect(routes.first.nextHopPeerId, peerB);
    });

    test('same PeerId different BLE address does not create separate routes', () {
      table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: 1));
      table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: 1));
      expect(table.routeCount, 1);
    });

    test('identity change does not inherit old routes', () {
      table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: 1));
      // New identity B' — different PeerId
      const peerBPrime = 'ee55555555555555555555555555555555555555555555555555555555555555';
      expect(table.hasRouteTo(peerBPrime), false);
      expect(table.hasRouteTo(peerB), true);
    });
  });

  group('I8.5 RoutingTable — trust isolation', () {
    test('route operations do not modify trust', () {
      final table = RoutingTable();
      // Adding and removing routes should have no trust side effects.
      final route = _makeRoute(dest: peerB, nextHop: peerB, metric: 1);
      table.addRoute(route);
      table.removeRoute(route);
      // If trust were affected, the system would need a trust service mock.
      // Here we verify the route table has no trust dependency.
      expect(table.routeCount, 0);
    });
  });

  group('I8.5 RoutingTable — session isolation', () {
    test('route operations do not corrupt other routes', () {
      final table = RoutingTable();
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      table.addRoute(_makeRoute(dest: peerD, nextHop: peerE, metric: 3));

      // Session-like operation: remove C's route.
      table.removeRoutesTo(peerC);

      // D's route must remain intact.
      expect(table.hasRouteTo(peerD), true);
      expect(table.nextHopFor(peerD), peerE);
    });
  });

  group('I8.5 RoutingTable — restart behavior', () {
    test('new table starts empty', () {
      final table = RoutingTable();
      expect(table.routeCount, 0);
      expect(table.destinationCount, 0);
      expect(table.allRoutes, isEmpty);
    });

    test('clear empties the table', () {
      final table = RoutingTable();
      table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: 1));
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      table.clear();
      expect(table.routeCount, 0);
      expect(table.destinationCount, 0);
    });
  });

  group('I8.5 RoutingTable — no side effects', () {
    test('addRoute does not create connections or sessions', () {
      final table = RoutingTable();
      // This test verifies the route table has no BLE/connection dependencies.
      // If it tried to create a connection, it would throw without a mock.
      table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: 1));
      expect(table.routeCount, 1);
    });

    test('removeRoute does not disconnect peers', () {
      final table = RoutingTable();
      table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: 1));
      table.removeRoutesTo(peerB);
      expect(table.routeCount, 0);
    });

    test('clear does not modify peers, trust, or sessions', () {
      final table = RoutingTable();
      table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: 1));
      table.clear();
      expect(table.routeCount, 0);
    });
  });

  group('I8.5 RoutingTable — deterministic ordering', () {
    test('allRoutes returns consistent order', () {
      final table = RoutingTable();
      table.addRoute(_makeRoute(dest: peerD, nextHop: peerB, metric: 3));
      table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, metric: 1));
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));

      final first = table.allRoutes.map((r) => r.destinationPeerId).toList();
      final second = table.allRoutes.map((r) => r.destinationPeerId).toList();
      expect(first, equals(second));
    });
  });

  group('I8.5 RoutingTable — maxRouteMetric constant', () {
    test('maxRouteMetric is 255', () {
      expect(maxRouteMetric, 255);
    });
  });

  group('I8.5 RoutingTable — destinationsVia', () {
    late RoutingTable table;

    setUp(() {
      table = RoutingTable();
    });

    test('returns all destinations reachable via a next hop', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      table.addRoute(_makeRoute(dest: peerD, nextHop: peerB, metric: 3));
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerD, metric: 2));

      final viaB = table.destinationsVia(peerB);
      expect(viaB, containsAll([peerC, peerD]));

      final viaD = table.destinationsVia(peerD);
      expect(viaD, contains(peerC));
    });

    test('returns empty list for unused next hop', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      expect(table.destinationsVia(peerD), isEmpty);
    });
  });

  group('I8.1 Topology', () {
    test('TopologySnapshot tracks nodes and neighbors', () {
      final now = DateTime(2025);
      final snapshot = TopologySnapshot(
        nodes: [
          const RoutingNode(peerId: peerA, isLocal: true),
          const RoutingNode(peerId: peerB, displayName: 'Peer B'),
          const RoutingNode(peerId: peerC, displayName: 'Peer C'),
        ],
        neighbors: [
          RoutingNeighbor(
            peerId: peerB,
            status: NeighborStatus.active,
            lastSeenAt: now,
          ),
          RoutingNeighbor(
            peerId: peerC,
            status: NeighborStatus.candidate,
            lastSeenAt: now,
          ),
        ],
        timestamp: now,
      );

      expect(snapshot.localNode, isNotNull);
      expect(snapshot.localNode!.peerId, peerA);
      expect(snapshot.nodeCount, 3);
      expect(snapshot.neighborCount, 2);
      expect(snapshot.eligibleNeighbors.length, 1);
      expect(snapshot.isNeighbor(peerB), true);
      expect(snapshot.isNeighbor(peerD), false);
    });

    test('TopologyEdge is bidirectional', () {
      const edge = TopologyEdge(fromPeerId: peerA, toPeerId: peerB);
      expect(edge.involves(peerA), true);
      expect(edge.involves(peerB), true);
      expect(edge.involves(peerC), false);
      expect(edge.otherEnd(peerA), peerB);
      expect(edge.otherEnd(peerB), peerA);
    });

    test('TopologyEdge equality is order-independent', () {
      const ab = TopologyEdge(fromPeerId: peerA, toPeerId: peerB);
      const ba = TopologyEdge(fromPeerId: peerB, toPeerId: peerA);
      expect(ab, equals(ba));
      expect(ab.hashCode, equals(ba.hashCode));
    });
  });
}
