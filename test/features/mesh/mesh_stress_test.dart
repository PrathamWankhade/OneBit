import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/mesh/cache/duplicate_packet_detector.dart';
import 'package:onebit/features/mesh/domain/mesh_clock.dart';
import 'package:onebit/features/mesh/domain/mesh_packet.dart';
import 'package:onebit/features/mesh/simulation/mesh_simulator.dart';
import 'package:onebit/features/mesh/simulation/simulation_scenarios.dart';

void main() {
  group('Mesh stress', () {
    test('fifty-node churn keeps every engine bounded and alive', () async {
      final run = await MeshScenarios.fiftyNodeChurn();
      for (final check in run.checks.entries) {
        expect(check.value, isTrue, reason: 'fifty-node churn: ${check.key}');
      }
    });

    test('twenty-node lattice delivers a 6-hop packet under load', () async {
      final run = await MeshScenarios.twentyNodeLattice();
      for (final check in run.checks.entries) {
        expect(
          check.value,
          isTrue,
          reason: 'twenty-node lattice: ${check.key}',
        );
      }
    });

    test('rapid join/leave cycles leave no table leaks behind', () async {
      final sim = MeshSimulator(seed: 31, lossRate: 0);
      const hubs = ['A', 'B', 'C', 'D'];
      for (final hub in hubs) {
        sim.addNode(hub);
        await sim.engines[hub]!.start();
      }
      for (var i = 0; i < hubs.length - 1; i++) {
        sim.link(hubs[i], hubs[i + 1]);
      }
      await sim.runFor(const Duration(seconds: 6));

      // Five joiners cycle through the hub ring, each seen once then gone.
      for (var round = 0; round < 5; round++) {
        final joiner = 'J$round';
        sim.addNode(joiner);
        await sim.engines[joiner]!.start();
        for (final hub in hubs) {
          sim.link(joiner, hub);
        }
        await sim.runFor(const Duration(seconds: 30));

        for (final hub in hubs) {
          sim.unlink(joiner, hub);
        }
        await sim.engines[joiner]!.stop();
        // Long enough to expire neighbour entries on the hubs.
        await sim.runFor(const Duration(seconds: 95));
      }

      for (final hub in hubs) {
        final engine = sim.engines[hub]!;
        // Every transient joiner aged out of the neighbour and route tables.
        for (var round = 0; round < 5; round++) {
          final joiner = 'J$round';
          expect(
            engine.neighbors.any((n) => n.nodeId == joiner),
            isFalse,
            reason: '$hub still tracks departed $joiner',
          );
          expect(
            engine.routes.any((r) => r.destination == joiner),
            isFalse,
            reason: '$hub still routes to departed $joiner',
          );
        }
        expect(engine.neighbors.length, lessThanOrEqualTo(4));
        expect(engine.isRunning, isTrue);
      }
    });

    test('dedup cache survives a 10k-packet burst without growth', () {
      final clock = ManualMeshClock();
      final detector = DuplicatePacketDetector(
        capacity: 2048,
        window: const Duration(seconds: 10),
        now: clock.now,
      );
      for (var source = 0; source < 10; source++) {
        for (var i = 0; i < 1000; i++) {
          final packet = MeshPacket(
            source: 'n$source',
            destination: 'n${source + 1}',
            kind: MeshPacketKind.data,
            ttl: 8,
            sequence: i,
          );
          detector.markSeen(packet);
        }
      }
      expect(detector.size, lessThanOrEqualTo(2048));
      expect(detector.evictions, greaterThan(0));
      // The same stream replayed is fully deduplicated and still bounded.
      final replay = DuplicatePacketDetector(
        capacity: 4096,
        window: const Duration(seconds: 10),
        now: clock.now,
      );
      for (var source = 0; source < 10; source++) {
        for (var i = 0; i < 1000; i++) {
          final packet = MeshPacket(
            source: 'n$source',
            destination: 'B${source + 1}',
            kind: MeshPacketKind.data,
            ttl: 8,
            sequence: i,
          );
          replay.markSeen(packet);
          replay.markSeen(packet);
        }
      }
      expect(replay.hits, 10000);
      expect(replay.size, lessThanOrEqualTo(4096));
    });
  });
}
