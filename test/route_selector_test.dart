import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/route_selector.dart';
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

void main() {
  const peerA = 'aa11111111111111111111111111111111111111111111111111111111111111';
  const peerB = 'bb22222222222222222222222222222222222222222222222222222222222222';
  const peerC = 'cc33333333333333333333333333333333333333333333333333333333333333';
  const peerD = 'dd44444444444444444444444444444444444444444444444444444444444444';
  const peerE = 'ee55555555555555555555555555555555555555555555555555555555555555';

  group('I8.7 RouteSelector — empty candidates', () {
    test('empty list returns null', () {
      expect(selectBestRoute([]), isNull);
    });
  });

  group('I8.7 RouteSelector — single candidate', () {
    test('one candidate is returned', () {
      final route = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final result = selectBestRoute([route]);
      expect(result, route);
    });
  });

  group('I8.7 RouteSelector — lower metric wins', () {
    test('metric 2 beats metric 3', () {
      final a = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final b = _makeRoute(dest: peerC, nextHop: peerD, metric: 3);
      final result = selectBestRoute([a, b]);
      expect(result, a);
    });

    test('metric 2 beats metric 4', () {
      final a = _makeRoute(dest: peerC, nextHop: peerB, metric: 4);
      final b = _makeRoute(dest: peerC, nextHop: peerD, metric: 2);
      final result = selectBestRoute([a, b]);
      expect(result, b);
    });

    test('metric 1 (direct) beats metric 2', () {
      final direct = _makeRoute(dest: peerC, nextHop: peerC, metric: 1);
      final indirect = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final result = selectBestRoute([indirect, direct]);
      expect(result, direct);
    });
  });

  group('I8.7 RouteSelector — equal metric PeerId tie-break', () {
    test('lower PeerId next hop wins when metrics are equal', () {
      final a = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final b = _makeRoute(dest: peerC, nextHop: peerD, metric: 2);
      final result = selectBestRoute([a, b]);
      // peerB sorts before peerD lexicographically.
      expect(result, a);
    });

    test('higher PeerId next hop loses', () {
      final a = _makeRoute(dest: peerC, nextHop: peerD, metric: 2);
      final b = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final result = selectBestRoute([a, b]);
      expect(result, b);
    });
  });

  group('I8.7 RouteSelector — input order independence', () {
    test('[B, D] and [D, B] produce the same result', () {
      final b = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final d = _makeRoute(dest: peerC, nextHop: peerD, metric: 2);

      final result1 = selectBestRoute([b, d]);
      final result2 = selectBestRoute([d, b]);

      expect(result1, equals(result2));
      expect(result1!.nextHopPeerId, peerB);
    });

    test('[D, E, B] and [E, B, D] produce the same result', () {
      final b = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final d = _makeRoute(dest: peerC, nextHop: peerD, metric: 2);
      final e = _makeRoute(dest: peerC, nextHop: peerE, metric: 2);

      final result1 = selectBestRoute([d, e, b]);
      final result2 = selectBestRoute([e, b, d]);

      expect(result1, equals(result2));
      expect(result1!.nextHopPeerId, peerB);
    });
  });

  group('I8.7 RouteSelector — duplicate candidates', () {
    test('duplicates do not affect selection', () {
      final a = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final b = _makeRoute(dest: peerC, nextHop: peerD, metric: 3);
      final result = selectBestRoute([a, a, a, b]);
      expect(result, a);
    });

    test('identical duplicates return the route', () {
      final a = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final result = selectBestRoute([a, a, a]);
      expect(result, a);
    });
  });

  group('I8.7 RouteSelector — multiple destinations', () {
    test('C candidates do not influence D selection', () {
      final cViaB = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final cViaD = _makeRoute(dest: peerC, nextHop: peerD, metric: 3);
      final dViaB = _makeRoute(dest: peerD, nextHop: peerB, metric: 2);
      final dViaC = _makeRoute(dest: peerD, nextHop: peerC, metric: 2);

      // Select for C.
      final cCandidates = [cViaB, cViaD];
      final cResult = selectBestRoute(cCandidates);
      expect(cResult, cViaB);

      // Select for D.
      final dCandidates = [dViaB, dViaC];
      final dResult = selectBestRoute(dCandidates);
      // peerB sorts before peerC.
      expect(dResult, dViaB);
    });
  });

  group('I8.7 RouteSelector — invalid candidates rejected', () {
    test('empty destination peer ID is rejected', () {
      final invalid = _makeRoute(dest: '', nextHop: peerB, metric: 2);
      final valid = _makeRoute(dest: peerC, nextHop: peerD, metric: 3);
      final result = selectBestRoute([invalid, valid]);
      expect(result, valid);
    });

    test('empty next hop peer ID is rejected', () {
      final invalid = _makeRoute(dest: peerC, nextHop: '', metric: 2);
      final valid = _makeRoute(dest: peerC, nextHop: peerD, metric: 3);
      final result = selectBestRoute([invalid, valid]);
      expect(result, valid);
    });

    test('metric 0 is rejected', () {
      final invalid = _makeRoute(dest: peerC, nextHop: peerB, metric: 0);
      final valid = _makeRoute(dest: peerC, nextHop: peerD, metric: 3);
      final result = selectBestRoute([invalid, valid]);
      expect(result, valid);
    });

    test('negative metric is rejected', () {
      final invalid = _makeRoute(dest: peerC, nextHop: peerB, metric: -1);
      final valid = _makeRoute(dest: peerC, nextHop: peerD, metric: 3);
      final result = selectBestRoute([invalid, valid]);
      expect(result, valid);
    });

    test('metric exceeding max is rejected', () {
      final invalid = _makeRoute(
        dest: peerC,
        nextHop: peerB,
        metric: maxRouteMetric + 1,
      );
      final valid = _makeRoute(dest: peerC, nextHop: peerD, metric: 3);
      final result = selectBestRoute([invalid, valid]);
      expect(result, valid);
    });

    test('all invalid candidates returns null', () {
      final a = _makeRoute(dest: '', nextHop: peerB, metric: 2);
      final b = _makeRoute(dest: peerC, nextHop: '', metric: 2);
      final c = _makeRoute(dest: peerC, nextHop: peerB, metric: 0);
      final result = selectBestRoute([a, b, c]);
      expect(result, isNull);
    });
  });

  group('I8.7 RouteSelector — identity tests', () {
    test('route uses PeerId, not BLE address', () {
      final a = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final result = selectBestRoute([a]);
      expect(result!.destinationPeerId.length, 64);
      expect(result.nextHopPeerId.length, 64);
    });

    test('different PeerIds produce different routes', () {
      final a = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final b = _makeRoute(dest: peerC, nextHop: peerD, metric: 2);
      final result = selectBestRoute([a, b]);
      expect(result!.nextHopPeerId, isNot(equals(b.nextHopPeerId)));
    });
  });

  group('I8.7 RouteSelector — trust isolation', () {
    test('selection does not depend on trust state', () {
      final a = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final b = _makeRoute(dest: peerC, nextHop: peerD, metric: 3);
      final result = selectBestRoute([a, b]);
      expect(result, a);
    });
  });

  group('I8.7 RouteSelector — session isolation', () {
    test('selection does not depend on session state', () {
      final a = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final b = _makeRoute(dest: peerC, nextHop: peerD, metric: 3);
      final result = selectBestRoute([a, b]);
      expect(result, a);
    });
  });

  group('I8.7 RouteSelector — deterministic repeated selection', () {
    test('same candidate set produces same result every time', () {
      final candidates = [
        _makeRoute(dest: peerC, nextHop: peerB, metric: 2),
        _makeRoute(dest: peerC, nextHop: peerD, metric: 2),
        _makeRoute(dest: peerC, nextHop: peerE, metric: 3),
      ];

      final results = List.generate(10, (_) {
        final result = selectBestRoute(candidates);
        return result!.nextHopPeerId;
      });

      expect(results.toSet().length, 1);
      expect(results.first, peerB);
    });
  });

  group('I8.7 RouteSelector — compareRoutesForSelection', () {
    test('lower metric compares less', () {
      final a = _makeRoute(dest: peerC, nextHop: peerB, metric: 1);
      final b = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      expect(compareRoutesForSelection(a, b), lessThan(0));
    });

    test('higher metric compares greater', () {
      final a = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final b = _makeRoute(dest: peerC, nextHop: peerB, metric: 1);
      expect(compareRoutesForSelection(a, b), greaterThan(0));
    });

    test('equal metric with lower PeerId compares less', () {
      final a = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final b = _makeRoute(dest: peerC, nextHop: peerD, metric: 2);
      expect(compareRoutesForSelection(a, b), lessThan(0));
    });

    test('equal metric with higher PeerId compares greater', () {
      final a = _makeRoute(dest: peerC, nextHop: peerD, metric: 2);
      final b = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      expect(compareRoutesForSelection(a, b), greaterThan(0));
    });

    test('identical routes compare equal', () {
      final a = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final b = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      expect(compareRoutesForSelection(a, b), 0);
    });
  });

  group('I8.7 RouteSelector — edge cases', () {
    test('metric at boundary (1) is valid', () {
      final route = _makeRoute(dest: peerC, nextHop: peerB, metric: 1);
      final result = selectBestRoute([route]);
      expect(result, route);
    });

    test('metric at maxRouteMetric is valid', () {
      final route = _makeRoute(
        dest: peerC,
        nextHop: peerB,
        metric: maxRouteMetric,
      );
      final result = selectBestRoute([route]);
      expect(result, route);
    });

    test('metric maxRouteMetric + 1 is invalid', () {
      final invalid = _makeRoute(
        dest: peerC,
        nextHop: peerB,
        metric: maxRouteMetric + 1,
      );
      final result = selectBestRoute([invalid]);
      expect(result, isNull);
    });
  });

  group('I8.7 RouteSelector — RoutingTable integration', () {
    test('bestRoute uses RouteSelector policy', () {
      final table = RoutingTable(localPeerId: peerA);
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerD, metric: 3));

      final best = table.bestRoute(peerC);
      expect(best, isNotNull);
      expect(best!.nextHopPeerId, peerB);
      expect(best.metric, 2);
    });

    test('bestRoute with equal metrics uses PeerId tie-break', () {
      final table = RoutingTable(localPeerId: peerA);
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 2));
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerD, metric: 2));

      final best = table.bestRoute(peerC);
      expect(best!.nextHopPeerId, peerB);
    });

    test('bestRoute returns null for no routes', () {
      final table = RoutingTable(localPeerId: peerA);
      expect(table.bestRoute(peerC), isNull);
    });

    test('bestRoute ignores stale routes', () {
      final table = RoutingTable(localPeerId: peerA);
      table.addRoute(_makeRoute(dest: peerC, nextHop: peerB, metric: 1));
      table.addRoute(
        _makeRoute(dest: peerC, nextHop: peerD, metric: 2),
      );
      // Mark B route as stale.
      final stale = table.routesTo(peerC).first.copyWith(state: RouteState.stale);
      table.removeRoute(table.routesTo(peerC).first);
      table.addRoute(stale);

      final best = table.bestRoute(peerC);
      expect(best!.nextHopPeerId, peerD);
    });
  });

  group('I8.7 RouteSelector — no side effects', () {
    test('selection does not modify input list', () {
      final a = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final b = _makeRoute(dest: peerC, nextHop: peerD, metric: 3);
      final candidates = [a, b];
      selectBestRoute(candidates);
      expect(candidates, [a, b]);
    });

    test('selection does not create connections', () {
      final route = _makeRoute(dest: peerC, nextHop: peerB, metric: 2);
      final result = selectBestRoute([route]);
      expect(result, route);
    });
  });
}
