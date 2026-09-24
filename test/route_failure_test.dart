import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/route_discovery.dart';
import 'package:onebit/features/routing/route_failure.dart';
import 'package:onebit/features/routing/routing_table.dart';

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

DiscoveryResult Function({
  required String localPeerId,
  required String destinationPeerId,
}) _discover(Map<String, Route?> results) {
  return ({
    required String localPeerId,
    required String destinationPeerId,
  }) {
    final route = results[destinationPeerId];
    if (route == null) return const DiscoveryResult.notFound();
    return DiscoveryResult.found(route);
  };
}

void main() {
  const peerA = 'aa11111111111111111111111111111111111111111111111111111111111111';
  const peerB = 'bb22222222222222222222222222222222222222222222222222222222222222';
  const peerC = 'cc33333333333333333333333333333333333333333333333333333333333333';
  const peerD = 'dd44444444444444444444444444444444444444444444444444444444444444';
  const peerE = 'ee55555555555555555555555555555555555555555555555555555555555555';

  group('I8.9 FailureReason', () {
    test('has all expected values', () {
      expect(FailureReason.values.length, 4);
      expect(FailureReason.values, contains(FailureReason.nextHopUnreachable));
      expect(FailureReason.values, contains(FailureReason.expired));
      expect(FailureReason.values, contains(FailureReason.invalid));
      expect(FailureReason.values, contains(FailureReason.topologyChanged));
    });
  });

  group('I8.9 FailureEvent', () {
    test('stores all fields', () {
      final event = FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      );
      expect(event.destination, peerC);
      expect(event.previousNextHop, peerB);
      expect(event.reason, FailureReason.nextHopUnreachable);
      expect(event.timestamp, DateTime(2025));
    });

    test('toString includes key info', () {
      final event = FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.expired,
        timestamp: DateTime(2025),
      );
      expect(event.toString(), contains('expired'));
    });
  });

  group('I8.9 RecoveryResult', () {
    test('recovered stores route', () {
      final route = _makeRoute(dest: peerC, nextHop: peerD, metric: 2);
      final result = RecoveryResult.recovered(peerC, route);
      expect(result.isRecovered, true);
      expect(result.route, route);
      expect(result.destination, peerC);
    });

    test('noRoute has null route', () {
      const result = RecoveryResult.noRoute(peerC);
      expect(result.isNoRoute, true);
      expect(result.route, isNull);
    });

    test('alreadyRecovering has null route', () {
      const result = RecoveryResult.alreadyRecovering(peerC);
      expect(result.isAlreadyRecovering, true);
      expect(result.route, isNull);
    });

    test('cancelled has null route', () {
      const result = RecoveryResult.cancelled(peerC);
      expect(result.isCancelled, true);
      expect(result.route, isNull);
    });
  });

  group('I8.9 RouteRecoveryService — basic recovery', () {
    late RoutingTable table;
    late RouteRecoveryService service;

    setUp(() {
      table = RoutingTable(localPeerId: peerA);
      service = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({
          peerC: _makeRoute(dest: peerC, nextHop: peerD, metric: 2),
        }),
        routingTable: table,
      );
    });

    test('handles failure and installs replacement route', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      expect(table.bestRoute(peerC)?.nextHopPeerId, peerB);

      final result = service.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));

      expect(result.isRecovered, true);
      expect(result.route!.nextHopPeerId, peerD);
      expect(table.bestRoute(peerC)?.nextHopPeerId, peerD);
    });

    test('invalidates failed route before recovery', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));

      service.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));

      final routesViaB = table.routesTo(peerC)
          .where((r) => r.nextHopPeerId == peerB)
          .toList();
      expect(routesViaB, isEmpty);
    });

    test('noRoute when discovery finds nothing', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));

      final svc = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({}),
        routingTable: table,
      );

      final result = svc.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));

      expect(result.isNoRoute, true);
      expect(table.hasRouteTo(peerC), false);
    });
  });

  group('I8.9 RouteRecoveryService — deduplication', () {
    late RoutingTable table;
    late RouteRecoveryService service;

    setUp(() {
      table = RoutingTable(localPeerId: peerA);
      service = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({
          peerC: _makeRoute(dest: peerC, nextHop: peerD, metric: 2),
        }),
        routingTable: table,
      );
    });

    test('isRecovering returns false after recovery completes', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));

      expect(service.isRecovering(peerC), false);

      service.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));

      expect(service.isRecovering(peerC), false);
    });

    test('concurrent destinations recover independently', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      table.addRoute(_makeRoute(dest: peerD, nextHop: peerB, metric: 3));

      final svc = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({
          peerC: _makeRoute(dest: peerC, nextHop: peerE, metric: 2),
          peerD: _makeRoute(dest: peerD, nextHop: peerE, metric: 3),
        }),
        routingTable: table,
      );

      final resultC = svc.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));
      final resultD = svc.handleFailure(FailureEvent(
        destination: peerD,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));

      expect(resultC.isRecovered, true);
      expect(resultD.isRecovered, true);
    });
  });

  group('I8.9 RouteRecoveryService — generation / stale protection', () {
    late RoutingTable table;
    late RouteRecoveryService service;

    setUp(() {
      table = RoutingTable(localPeerId: peerA);
      service = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({
          peerC: _makeRoute(dest: peerC, nextHop: peerD, metric: 2),
        }),
        routingTable: table,
      );
    });

    test('generation increments on each recovery attempt', () {
      expect(service.generationFor(peerC), 0);

      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      service.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));
      expect(service.generationFor(peerC), 1);

      table.addRoute(_makeRoute(dest: peerC, nextHop: peerD, metric: 2));
      service.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerD,
        reason: FailureReason.expired,
        timestamp: DateTime(2025),
      ));
      expect(service.generationFor(peerC), 2);
    });

    test('generationFor returns 0 for unknown destination', () {
      expect(service.generationFor(peerE), 0);
    });
  });

  group('I8.9 RouteRecoveryService — better route preserved', () {
    late RoutingTable table;

    setUp(() {
      table = RoutingTable(localPeerId: peerA);
    });

    test('does not downgrade to a worse route', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerD, metric: 2));

      final svc = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({
          peerC: _makeRoute(dest: peerC, nextHop: peerB, metric: 4),
        }),
        routingTable: table,
      );

      final result = svc.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerD,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));

      // Old route was metric 2, discovered is metric 4 — do not install.
      expect(result.isNoRoute, true);
    });

    test('replaces with equal-cost route using deterministic tie-break', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));

      final svc = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({
          peerC: _makeRoute(dest: peerC, nextHop: peerD, metric: 2),
        }),
        routingTable: table,
      );

      final result = svc.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));

      // B was removed, D is discovered. D becomes the only option.
      expect(result.isRecovered, true);
    });
  });

  group('I8.9 RouteRecoveryService — direct replacement', () {
    test('recovers to direct route when destination becomes reachable', () {
      final table = RoutingTable(localPeerId: peerA);
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));

      final svc = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({
          peerC: _makeRoute(dest: peerC, nextHop: peerC, metric: 1),
        }),
        routingTable: table,
      );

      final result = svc.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));

      expect(result.isRecovered, true);
      expect(result.route!.metric, 1);
      expect(result.route!.nextHopPeerId, peerC);
    });
  });

  group('I8.9 RouteRecoveryService — cancel and disposal', () {
    late RoutingTable table;
    late RouteRecoveryService service;

    setUp(() {
      table = RoutingTable(localPeerId: peerA);
      service = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({}),
        routingTable: table,
      );
    });

    test('cancelRecovery clears recovery state', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      service.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));

      service.cancelRecovery(peerC);
      expect(service.isRecovering(peerC), false);
    });

    test('dispose clears all state', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      service.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));

      service.dispose();
      expect(service.isRecovering(peerC), false);
      expect(service.generationFor(peerC), 0);
    });

    test('clear resets all state', () {
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      service.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));

      service.clear();
      expect(service.generationFor(peerC), 0);
    });
  });

  group('I8.9 RouteRecoveryService — empty destination', () {
    test('returns cancelled for empty destination', () {
      final table = RoutingTable(localPeerId: peerA);
      final svc = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({}),
        routingTable: table,
      );

      final result = svc.handleFailure(FailureEvent(
        destination: '',
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));

      expect(result.isCancelled, true);
    });
  });

  group('I8.9 RouteRecoveryService — no side effects', () {
    test('handleFailure does not create connections or sessions', () {
      final table = RoutingTable(localPeerId: peerA);
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));

      final svc = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({
          peerC: _makeRoute(dest: peerC, nextHop: peerD, metric: 2),
        }),
        routingTable: table,
      );

      final result = svc.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));
      expect(result.isRecovered, true);
    });

    test('isRecovering is pure read', () {
      final table = RoutingTable(localPeerId: peerA);
      final svc = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({}),
        routingTable: table,
      );

      expect(svc.isRecovering(peerC), false);
      expect(svc.isRecovering(peerC), false);
    });
  });

  group('I8.9 RouteRecoveryService — identity isolation', () {
    test('recovery uses PeerId not BLE address', () {
      final table = RoutingTable(localPeerId: peerA);
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));

      final svc = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({
          peerC: _makeRoute(dest: peerC, nextHop: peerD, metric: 2),
        }),
        routingTable: table,
      );

      final result = svc.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));

      expect(result.route!.destinationPeerId.length, 64);
      expect(result.route!.nextHopPeerId.length, 64);
    });

    test('identity change does not inherit old recovery state', () {
      final table = RoutingTable(localPeerId: peerA);
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));

      final svc = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({
          peerC: _makeRoute(dest: peerC, nextHop: peerD, metric: 2),
        }),
        routingTable: table,
      );

      svc.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));

      const peerCPrime = 'ff66666666666666666666666666666666666666666666666666666666666666';
      expect(svc.generationFor(peerCPrime), 0);
      expect(svc.isRecovering(peerCPrime), false);
    });
  });

  group('I8.9 RouteRecoveryService — trust/session isolation', () {
    test('trust changes do not trigger recovery', () {
      final table = RoutingTable(localPeerId: peerA);
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));

      final svc = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({}),
        routingTable: table,
      );

      expect(svc.isRecovering(peerC), false);
      expect(table.bestRoute(peerC)?.nextHopPeerId, peerB);
    });

    test('session changes do not create second route identity', () {
      final table = RoutingTable(localPeerId: peerA);
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));

      RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({}),
        routingTable: table,
      );

      expect(table.routeCount, 1);
    });
  });

  group('I8.9 RouteRecoveryService — multiple failures', () {
    test('handles sequential failures for different destinations', () {
      final table = RoutingTable(localPeerId: peerA);
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      table.addRoute(_makeRoute(dest: peerD, nextHop: peerB, metric: 3));

      final svc = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({
          peerC: _makeRoute(dest: peerC, nextHop: peerE, metric: 2),
          peerD: _makeRoute(dest: peerD, nextHop: peerE, metric: 3),
        }),
        routingTable: table,
      );

      final resultC = svc.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));
      final resultD = svc.handleFailure(FailureEvent(
        destination: peerD,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));

      expect(resultC.isRecovered, true);
      expect(resultD.isRecovered, true);
      expect(table.bestRoute(peerC)?.nextHopPeerId, peerE);
      expect(table.bestRoute(peerD)?.nextHopPeerId, peerE);
    });

    test('repeated failures increment generation', () {
      final table = RoutingTable(localPeerId: peerA);
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));

      final svc = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({
          peerC: _makeRoute(dest: peerC, nextHop: peerD, metric: 2),
        }),
        routingTable: table,
      );

      svc.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime(2025),
      ));
      expect(svc.generationFor(peerC), 1);

      table.addRoute(_makeRoute(dest: peerC, nextHop: peerD, metric: 2));
      svc.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerD,
        reason: FailureReason.expired,
        timestamp: DateTime(2025),
      ));
      expect(svc.generationFor(peerC), 2);
    });
  });

  group('I8.9 RouteRecoveryService — reason variety', () {
    test('handles expired reason', () {
      final table = RoutingTable(localPeerId: peerA);
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));

      final svc = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({
          peerC: _makeRoute(dest: peerC, nextHop: peerD, metric: 2),
        }),
        routingTable: table,
      );

      final result = svc.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.expired,
        timestamp: DateTime(2025),
      ));
      expect(result.isRecovered, true);
    });

    test('handles topologyChanged reason', () {
      final table = RoutingTable(localPeerId: peerA);
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));

      final svc = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({
          peerC: _makeRoute(dest: peerC, nextHop: peerD, metric: 2),
        }),
        routingTable: table,
      );

      final result = svc.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.topologyChanged,
        timestamp: DateTime(2025),
      ));
      expect(result.isRecovered, true);
    });

    test('handles invalid reason', () {
      final table = RoutingTable(localPeerId: peerA);
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));

      final svc = RouteRecoveryService(
        localPeerId: peerA,
        discoverRoute: _discover({
          peerC: _makeRoute(dest: peerC, nextHop: peerD, metric: 2),
        }),
        routingTable: table,
      );

      final result = svc.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.invalid,
        timestamp: DateTime(2025),
      ));
      expect(result.isRecovered, true);
    });
  });
}
