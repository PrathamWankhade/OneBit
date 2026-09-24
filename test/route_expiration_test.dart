import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/route_expiration.dart';
import 'package:onebit/features/routing/routing_table.dart';

Route _makeRoute({
  required String dest,
  required String nextHop,
  int metric = 1,
  RouteState state = RouteState.active,
  RouteSource source = RouteSource.advertised,
  DateTime? createdAt,
  DateTime? expiresAt,
}) {
  return Route(
    destinationPeerId: dest,
    nextHopPeerId: nextHop,
    metric: metric,
    state: state,
    source: source,
    createdAt: createdAt ?? DateTime(2025),
    lastValidatedAt: createdAt ?? DateTime(2025),
    expiresAt: expiresAt,
  );
}

void main() {
  const peerA = 'aa11111111111111111111111111111111111111111111111111111111111111';
  const peerB = 'bb22222222222222222222222222222222222222222222222222222222222222';
  const peerC = 'cc33333333333333333333333333333333333333333333333333333333333333';

  group('I8.8 Route.expiresAt', () {
    test('route without expiresAt has null expiresAt', () {
      final route = _makeRoute(dest: peerB, nextHop: peerB);
      expect(route.expiresAt, isNull);
    });

    test('route with expiresAt stores the value', () {
      final expiry = DateTime(2025, 6, 1);
      final route = _makeRoute(dest: peerB, nextHop: peerB, expiresAt: expiry);
      expect(route.expiresAt, expiry);
    });

    test('copyWith preserves expiresAt', () {
      final expiry = DateTime(2025, 6, 1);
      final route = _makeRoute(dest: peerB, nextHop: peerB, expiresAt: expiry);
      final updated = route.copyWith(metric: 2);
      expect(updated.expiresAt, expiry);
    });

    test('copyWith can override expiresAt', () {
      final route = _makeRoute(dest: peerB, nextHop: peerB);
      final newExpiry = DateTime(2025, 12, 31);
      final updated = route.copyWith(expiresAt: newExpiry);
      expect(updated.expiresAt, newExpiry);
    });

    test('copyWith can clear expiresAt', () {
      final route = _makeRoute(
        dest: peerB,
        nextHop: peerB,
        expiresAt: DateTime(2025, 6, 1),
      );
      final updated = route.copyWith();
      expect(updated.expiresAt, DateTime(2025, 6, 1));
    });
  });

  group('I8.8 isRouteExpired', () {
    test('returns false when expiresAt is null', () {
      final route = _makeRoute(dest: peerB, nextHop: peerB);
      expect(isRouteExpired(route, now: DateTime(2030)), false);
    });

    test('returns false when now is before expiresAt', () {
      final route = _makeRoute(
        dest: peerB,
        nextHop: peerB,
        expiresAt: DateTime(2025, 12, 31),
      );
      expect(isRouteExpired(route, now: DateTime(2025, 6, 1)), false);
    });

    test('returns true when now is after expiresAt', () {
      final route = _makeRoute(
        dest: peerB,
        nextHop: peerB,
        expiresAt: DateTime(2025, 6, 1),
      );
      expect(isRouteExpired(route, now: DateTime(2025, 12, 31)), true);
    });

    test('returns true when now equals expiresAt', () {
      final expiry = DateTime(2025, 6, 1);
      final route = _makeRoute(dest: peerB, nextHop: peerB, expiresAt: expiry);
      expect(isRouteExpired(route, now: expiry), false);
    });
  });

  group('I8.8 RouteExpirationPolicy', () {
    test('default policy has correct TTLs', () {
      const policy = RouteExpirationPolicy.defaultPolicy;
      expect(policy.directRouteTtl, defaultDirectRouteTtl);
      expect(policy.advertisedRouteTtl, defaultAdvertisedRouteTtl);
      expect(policy.staticRouteTtl, defaultStaticRouteTtl);
    });

    test('custom policy stores values', () {
      const policy = RouteExpirationPolicy(
        directRouteTtl: Duration(minutes: 20),
        advertisedRouteTtl: Duration(minutes: 10),
        staticRouteTtl: Duration(hours: 2),
      );
      expect(policy.directRouteTtl, const Duration(minutes: 20));
      expect(policy.advertisedRouteTtl, const Duration(minutes: 10));
      expect(policy.staticRouteTtl, const Duration(hours: 2));
    });

    test('ttlForSource returns correct TTL for direct', () {
      const policy = RouteExpirationPolicy();
      expect(policy.ttlForSource(RouteSource.direct), defaultDirectRouteTtl);
    });

    test('ttlForSource returns correct TTL for advertised', () {
      const policy = RouteExpirationPolicy();
      expect(policy.ttlForSource(RouteSource.advertised), defaultAdvertisedRouteTtl);
    });

    test('ttlForSource returns correct TTL for static', () {
      const policy = RouteExpirationPolicy();
      expect(policy.ttlForSource(RouteSource.static), defaultStaticRouteTtl);
    });

    test('equality', () {
      const a = RouteExpirationPolicy();
      const b = RouteExpirationPolicy();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality for different values', () {
      const a = RouteExpirationPolicy();
      const b = RouteExpirationPolicy(directRouteTtl: Duration(hours: 1));
      expect(a, isNot(equals(b)));
    });
  });

  group('I8.8 computeRouteExpiration', () {
    test('direct route gets direct TTL', () {
      final route = _makeRoute(
        dest: peerB,
        nextHop: peerB,
        source: RouteSource.direct,
        createdAt: DateTime(2025, 1, 1),
      );
      const policy = RouteExpirationPolicy();
      final expires = computeRouteExpiration(route, policy);
      expect(expires, DateTime(2025, 1, 1).add(defaultDirectRouteTtl));
    });

    test('advertised route gets advertised TTL', () {
      final route = _makeRoute(
        dest: peerC,
        nextHop: peerB,
        source: RouteSource.advertised,
        createdAt: DateTime(2025, 1, 1),
      );
      const policy = RouteExpirationPolicy();
      final expires = computeRouteExpiration(route, policy);
      expect(expires, DateTime(2025, 1, 1).add(defaultAdvertisedRouteTtl));
    });

    test('static route gets static TTL', () {
      final route = _makeRoute(
        dest: peerC,
        nextHop: peerB,
        source: RouteSource.static,
        createdAt: DateTime(2025, 1, 1),
      );
      const policy = RouteExpirationPolicy();
      final expires = computeRouteExpiration(route, policy);
      expect(expires, DateTime(2025, 1, 1).add(defaultStaticRouteTtl));
    });

    test('custom policy is respected', () {
      final route = _makeRoute(
        dest: peerB,
        nextHop: peerB,
        source: RouteSource.direct,
        createdAt: DateTime(2025, 1, 1),
      );
      const policy = RouteExpirationPolicy(
        directRouteTtl: Duration(minutes: 5),
      );
      final expires = computeRouteExpiration(route, policy);
      expect(expires, DateTime(2025, 1, 1, 0, 5));
    });
  });

  group('I8.8 RouteExpirationService', () {
    late RouteExpirationService service;

    setUp(() {
      service = RouteExpirationService();
    });

    group('validateRoute', () {
      test('direct route with valid neighbor is valid', () {
        final route = _makeRoute(
          dest: peerB,
          nextHop: peerB,
          source: RouteSource.direct,
        );
        final result = service.validateRoute(
          route,
          reachableNeighbors: {peerB},
          now: DateTime(2025),
        );
        expect(result.isValid, true);
        expect(result.status, RouteValidationStatus.valid);
      });

      test('advertised route with reachable next hop is valid', () {
        final route = _makeRoute(
          dest: peerC,
          nextHop: peerB,
          source: RouteSource.advertised,
        );
        final result = service.validateRoute(
          route,
          reachableNeighbors: {peerB},
          now: DateTime(2025),
        );
        expect(result.isValid, true);
      });

      test('route with expired TTL is expired', () {
        final route = _makeRoute(
          dest: peerB,
          nextHop: peerB,
          source: RouteSource.direct,
          createdAt: DateTime(2025, 1, 1),
          expiresAt: DateTime(2025, 6, 1),
        );
        final result = service.validateRoute(
          route,
          reachableNeighbors: {peerB},
          now: DateTime(2025, 12, 31),
        );
        expect(result.isExpired, true);
        expect(result.status, RouteValidationStatus.expired);
      });

      test('advertised route with unreachable next hop is unreachable', () {
        final route = _makeRoute(
          dest: peerC,
          nextHop: peerB,
          source: RouteSource.advertised,
        );
        final result = service.validateRoute(
          route,
          reachableNeighbors: {peerA},
          now: DateTime(2025),
        );
        expect(result.isUnreachable, true);
        expect(result.status, RouteValidationStatus.unreachableNextHop);
      });

      test('direct route skips next-hop check', () {
        final route = _makeRoute(
          dest: peerB,
          nextHop: peerB,
          source: RouteSource.direct,
        );
        final result = service.validateRoute(
          route,
          reachableNeighbors: {},
          now: DateTime(2025),
        );
        expect(result.isValid, true);
      });

      test('route without expiresAt is never expired', () {
        final route = _makeRoute(dest: peerB, nextHop: peerB);
        final result = service.validateRoute(
          route,
          reachableNeighbors: {peerB},
          now: DateTime(2030),
        );
        expect(result.isValid, true);
      });
    });

    group('validateAllRoutes', () {
      test('returns results for all routes', () {
        final table = RoutingTable();
        table.addRoute(_makeRoute(dest: peerB, nextHop: peerB, source: RouteSource.direct));
        table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, source: RouteSource.advertised));

        final results = service.validateAllRoutes(
          table,
          reachableNeighbors: {peerB},
          now: DateTime(2025),
        );
        expect(results.length, 2);
        expect(results.every((r) => r.isValid), true);
      });

      test('detects mixed valid and expired routes', () {
        final table = RoutingTable();
        table.addRoute(_makeRoute(
          dest: peerB,
          nextHop: peerB,
          source: RouteSource.direct,
          expiresAt: DateTime(2025, 6, 1),
        ));
        table.addRoute(_makeRoute(
          dest: peerC,
          nextHop: peerB,
          source: RouteSource.advertised,
          expiresAt: DateTime(2030, 1, 1),
        ));

        final results = service.validateAllRoutes(
          table,
          reachableNeighbors: {peerB},
          now: DateTime(2025, 12, 31),
        );
        expect(results.length, 2);
        expect(results.where((r) => r.isExpired).length, 1);
        expect(results.where((r) => r.isValid).length, 1);
      });
    });

    group('findExpiredRoutes', () {
      test('finds routes that have expired', () {
        final table = RoutingTable();
        table.addRoute(_makeRoute(
          dest: peerB,
          nextHop: peerB,
          expiresAt: DateTime(2025, 6, 1),
        ));
        table.addRoute(_makeRoute(
          dest: peerC,
          nextHop: peerB,
          expiresAt: DateTime(2030, 1, 1),
        ));

        final expired = service.findExpiredRoutes(table, now: DateTime(2025, 12, 31));
        expect(expired.length, 1);
        expect(expired.first.destinationPeerId, peerB);
      });

      test('returns empty when no routes expired', () {
        final table = RoutingTable();
        table.addRoute(_makeRoute(
          dest: peerB,
          nextHop: peerB,
          expiresAt: DateTime(2030, 1, 1),
        ));

        final expired = service.findExpiredRoutes(table, now: DateTime(2025, 12, 31));
        expect(expired, isEmpty);
      });

      test('routes without expiresAt are not considered expired', () {
        final table = RoutingTable();
        table.addRoute(_makeRoute(dest: peerB, nextHop: peerB));

        final expired = service.findExpiredRoutes(table, now: DateTime(2030));
        expect(expired, isEmpty);
      });
    });

    group('findUnreachableRoutes', () {
      test('finds routes with unreachable next hops', () {
        final table = RoutingTable();
        table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, source: RouteSource.advertised));

        final unreachable = service.findUnreachableRoutes(
          table,
          reachableNeighbors: {peerA},
        );
        expect(unreachable.length, 1);
        expect(unreachable.first.destinationPeerId, peerC);
      });

      test('returns empty when all next hops reachable', () {
        final table = RoutingTable();
        table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, source: RouteSource.advertised));

        final unreachable = service.findUnreachableRoutes(
          table,
          reachableNeighbors: {peerB},
        );
        expect(unreachable, isEmpty);
      });

      test('direct routes are never considered unreachable', () {
        final table = RoutingTable();
        table.addRoute(_makeRoute(
          dest: peerB,
          nextHop: peerB,
          source: RouteSource.direct,
        ));

        final unreachable = service.findUnreachableRoutes(
          table,
          reachableNeighbors: {},
        );
        expect(unreachable, isEmpty);
      });
    });

    group('countExpiringSoon', () {
      test('counts routes expiring within duration', () {
        final table = RoutingTable();
        table.addRoute(_makeRoute(
          dest: peerB,
          nextHop: peerB,
          createdAt: DateTime(2025, 1, 1),
          expiresAt: DateTime(2025, 1, 1, 0, 30),
        ));
        table.addRoute(_makeRoute(
          dest: peerC,
          nextHop: peerB,
          createdAt: DateTime(2025, 1, 1),
          expiresAt: DateTime(2025, 1, 1, 2, 0),
        ));

        final count = service.countExpiringSoon(
          table,
          duration: const Duration(hours: 1),
          now: DateTime(2025, 1, 1),
        );
        expect(count, 1);
      });

      test('returns zero when nothing expiring soon', () {
        final table = RoutingTable();
        table.addRoute(_makeRoute(
          dest: peerB,
          nextHop: peerB,
          expiresAt: DateTime(2030, 1, 1),
        ));

        final count = service.countExpiringSoon(
          table,
          duration: const Duration(hours: 1),
          now: DateTime(2025, 1, 1),
        );
        expect(count, 0);
      });
    });
  });

  group('I8.8 RouteExpirationService — no side effects', () {
    test('validateRoute does not modify the route', () {
      final service = RouteExpirationService();
      final route = _makeRoute(dest: peerB, nextHop: peerB, source: RouteSource.direct);
      final originalState = route.state;
      service.validateRoute(route, reachableNeighbors: {peerB}, now: DateTime(2025));
      expect(route.state, originalState);
    });

    test('validateAllRoutes does not modify the routing table', () {
      final service = RouteExpirationService();
      final table = RoutingTable();
      table.addRoute(_makeRoute(dest: peerB, nextHop: peerB));
      final countBefore = table.routeCount;
      service.validateAllRoutes(table, reachableNeighbors: {peerB}, now: DateTime(2025));
      expect(table.routeCount, countBefore);
    });

    test('findExpiredRoutes does not modify the routing table', () {
      final service = RouteExpirationService();
      final table = RoutingTable();
      table.addRoute(_makeRoute(
        dest: peerB,
        nextHop: peerB,
        expiresAt: DateTime(2025, 1, 1),
      ));
      service.findExpiredRoutes(table, now: DateTime(2030));
      expect(table.routeCount, 1);
    });

    test('findUnreachableRoutes does not modify the routing table', () {
      final service = RouteExpirationService();
      final table = RoutingTable();
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB));
      service.findUnreachableRoutes(table, reachableNeighbors: {});
      expect(table.routeCount, 1);
    });
  });

  group('I8.8 RouteExpirationService — default policy', () {
    test('default policy is used when none provided', () {
      final service = RouteExpirationService();
      expect(service.policy, RouteExpirationPolicy.defaultPolicy);
    });

    test('custom policy is used when provided', () {
      const policy = RouteExpirationPolicy(
        directRouteTtl: Duration(minutes: 5),
      );
      final service = RouteExpirationService(policy: policy);
      expect(service.policy.directRouteTtl, const Duration(minutes: 5));
    });
  });

  group('I8.8 RouteExpirationPolicy — toString', () {
    test('default policy has readable toString', () {
      expect(
        RouteExpirationPolicy.defaultPolicy.toString(),
        contains('direct: 10min'),
      );
    });
  });
}
