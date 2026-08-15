import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/mesh/domain/mesh_clock.dart';
import 'package:onebit/features/mesh/domain/mesh_packet.dart';
import 'package:onebit/features/mesh/domain/mesh_route.dart';
import 'package:onebit/features/mesh/routing/loop_detector.dart';
import 'package:onebit/features/mesh/routing/route_optimizer.dart';
import 'package:onebit/features/mesh/routing/route_table.dart';

MeshPacket _packet({String source = 'A', List<String> path = const []}) =>
    MeshPacket(
      source: source,
      destination: 'B',
      kind: MeshPacketKind.data,
      ttl: 8,
      sequence: 1,
      path: path,
    );

void main() {
  group('LoopDetector', () {
    test('detects re-entry and would-be loops', () {
      const detector = LoopDetector();
      final packet = _packet(path: const ['A', 'C']);
      expect(detector.wouldReenter(packet, 'C'), isTrue);
      expect(detector.wouldReenter(packet, 'D'), isFalse);
      expect(detector.wouldCreateLoop(packet, 'A'), isTrue);
      expect(detector.wouldCreateLoop(packet, 'C'), isTrue);
      expect(detector.wouldCreateLoop(packet, 'D'), isFalse);
      expect(detector.pathIsValid(packet), isTrue);
      final duplicated = _packet(path: const ['A', 'C', 'A']);
      expect(detector.pathIsValid(duplicated), isFalse);
    });
  });

  group('RouteOptimizer', () {
    test('maps rssi to quality with clamping', () {
      expect(RouteOptimizer.linkQualityFromRssi(-50), 1.0);
      expect(RouteOptimizer.linkQualityFromRssi(-70), closeTo(0.5, 0.0001));
      expect(RouteOptimizer.linkQualityFromRssi(-120), 0.0);
      expect(RouteOptimizer.linkQualityFromRssi(-10), 1.0);
    });

    test('cost weights hops, quality and reliability', () {
      final optimizer = RouteOptimizer();
      expect(optimizer.cost(hopCount: 2, quality: 1, reliability: 1), 2.0);
      expect(
        optimizer.cost(hopCount: 2, quality: 0.5, reliability: 0.5),
        closeTo(2 + 1.0 + 0.75, 0.0001),
      );
    });

    test('adds a freshness penalty past a minute of disuse', () {
      final optimizer = RouteOptimizer();
      final base = optimizer.cost(hopCount: 1, quality: 1, reliability: 1);
      final stale = optimizer.cost(
        hopCount: 1,
        quality: 1,
        reliability: 1,
        unusedSince: const Duration(minutes: 6),
      );
      expect(stale, closeTo(base + 1.5, 0.0001));
    });

    test('isBetter prefers lower cost beyond epsilon, then quality', () {
      final now = DateTime.utc(2026);
      final optimizer = RouteOptimizer(epsilon: 0.15);
      final base = optimizer.candidate(
        destination: 'D',
        nextHop: 'A',
        hopCount: 2,
        quality: 0.8,
        reliability: 1.0,
        now: now,
      );
      final clearlyWorse = optimizer.candidate(
        destination: 'D',
        nextHop: 'B',
        hopCount: 3,
        quality: 0.8,
        reliability: 1.0,
        now: now,
      );
      final betterQuality = optimizer.candidate(
        destination: 'D',
        nextHop: 'C',
        hopCount: 2,
        quality: 0.9,
        reliability: 1.0,
        now: now,
      );
      expect(
        optimizer.isBetter(candidate: clearlyWorse, current: base),
        isFalse,
      );
      expect(
        optimizer.isBetter(candidate: betterQuality, current: base),
        isTrue,
      );
      expect(optimizer.isBetter(candidate: base, current: null), isTrue);
    });
  });

  group('RouteTable', () {
    MeshRoute route({
      required String destination,
      required String nextHop,
      required double cost,
      double quality = 0.8,
      DateTime? lastUsed,
    }) {
      final now = DateTime.utc(2026);
      return MeshRoute(
        destination: destination,
        nextHop: nextHop,
        hopCount: 1,
        cost: cost,
        quality: quality,
        reliability: 1.0,
        createdAt: now,
        lastUsed: lastUsed ?? now,
      );
    }

    test('installs and keeps the primary and capped alternatives', () {
      final clock = ManualMeshClock();
      final table = RouteTable(time: clock.now);
      expect(
        table.install(route(destination: 'D', nextHop: 'A', cost: 3)),
        isTrue,
      );
      expect(table.primary('D')!.nextHop, 'A');
      table.install(route(destination: 'D', nextHop: 'B', cost: 2));
      expect(table.primary('D')!.nextHop, 'B');
      expect(table.alternatives('D'), hasLength(1));
    });

    test('replaces only better routes for the same next hop', () {
      final clock = ManualMeshClock();
      final table = RouteTable(time: clock.now);
      table.install(route(destination: 'D', nextHop: 'A', cost: 3));
      expect(
        table.install(route(destination: 'D', nextHop: 'A', cost: 5)),
        isFalse,
      );
      expect(table.primary('D')!.cost, 3);
      expect(
        table.install(route(destination: 'D', nextHop: 'A', cost: 2)),
        isTrue,
      );
      expect(table.primary('D')!.cost, 2);
    });

    test('caps route count per destination', () {
      final clock = ManualMeshClock();
      final table = RouteTable(time: clock.now, maxAlternatives: 2);
      for (var i = 0; i < 6; i++) {
        table.install(route(destination: 'D', nextHop: 'h$i', cost: 5.0 + i));
      }
      expect(table.forDestination('D'), hasLength(3));
    });

    test('dissolves routes through a departed hop', () {
      final clock = ManualMeshClock();
      final now = clock.now();
      final table = RouteTable(time: clock.now);
      table.install(
        MeshRoute(
          destination: 'X',
          nextHop: 'B',
          hopCount: 1,
          cost: 1.0,
          quality: 0.8,
          reliability: 1.0,
          createdAt: now,
          lastUsed: now,
        ),
      );
      table.install(
        MeshRoute(
          destination: 'Y',
          nextHop: 'B',
          hopCount: 1,
          cost: 1.0,
          quality: 0.8,
          reliability: 1.0,
          createdAt: now,
          lastUsed: now,
        ),
      );
      table.install(
        MeshRoute(
          destination: 'Y',
          nextHop: 'C',
          hopCount: 2,
          cost: 2.0,
          quality: 0.8,
          reliability: 1.0,
          createdAt: now,
          lastUsed: now,
        ),
      );
      final affected = table.dissolveThrough('B');
      expect(affected, containsAll(['X', 'Y']));
      expect(table.primary('X'), isNull);
      expect(table.primary('Y')!.nextHop, 'C');
    });

    test('demotes the primary and rotates the queue', () {
      final clock = ManualMeshClock();
      final table = RouteTable(time: clock.now);
      table.install(route(destination: 'D', nextHop: 'A', cost: 1));
      table.install(route(destination: 'D', nextHop: 'B', cost: 2));
      expect(table.demotePrimary('D'), isTrue);
      expect(table.primary('D')!.nextHop, 'B');
      expect(table.demotePrimary('D'), isTrue);
      expect(table.primary('D')!.nextHop, 'A');
    });

    test('expires routes untouched for the ttl', () {
      final clock = ManualMeshClock();
      final table = RouteTable(time: clock.now);
      table.install(route(destination: 'D', nextHop: 'A', cost: 1));
      table.install(route(destination: 'E', nextHop: 'A', cost: 1));
      clock.advance(const Duration(minutes: 6));
      final lost = table.expire(clock.now(), const Duration(minutes: 5));
      expect(lost, contains('D'));
      expect(lost, contains('E'));
      expect(table.destinations, isEmpty);
    });

    test('touch refreshes lastUsed so expire keeps the route', () {
      final clock = ManualMeshClock();
      final table = RouteTable(time: clock.now);
      table.install(route(destination: 'D', nextHop: 'A', cost: 1));
      clock.advance(const Duration(minutes: 4));
      table.touch('D');
      clock.advance(const Duration(minutes: 2));
      final lost = table.expire(clock.now(), const Duration(minutes: 5));
      expect(lost, isEmpty);
    });
  });
}
