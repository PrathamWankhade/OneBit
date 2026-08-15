import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_repository.dart';
import 'package:onebit/features/mesh/simulation/mesh_simulator.dart';

void main() {
  group('MeshEngine lifecycle', () {
    test('start reaches running and stop returns to stopped', () async {
      final sim = MeshSimulator(seed: 1, lossRate: 0);
      sim.addNode('A');
      final engine = sim.engines['A']!;
      expect(engine.state, MeshEngineState.stopped);
      await engine.start();
      expect(engine.state, MeshEngineState.running);
      await engine.stop();
      expect(engine.state, MeshEngineState.stopped);
      expect(engine.isRunning, isFalse);
    });
  });

  group('MeshEngine e2e', () {
    test('no-route sends drop and trigger discovery', () async {
      final sim = MeshSimulator(seed: 2, lossRate: 0);
      sim.addNode('A');
      await sim.engines['A']!.start();
      final outcome = sim.send('A', destination: 'B', payload: [1]);
      expect(outcome, isA<MeshSendDiscoveryPending>());
    });

    test('multi-hop packets die when the TTL runs out', () async {
      final sim = MeshSimulator(seed: 3, lossRate: 0);
      const ids = ['A', 'B', 'C', 'D'];
      for (final id in ids) {
        sim.addNode(id);
        await sim.engines[id]!.start();
      }
      for (var i = 0; i < ids.length - 1; i++) {
        sim.link(ids[i], ids[i + 1]);
      }
      sim.beginTracking('D');
      await sim.runFor(const Duration(seconds: 6));

      // ttl 1 means exactly one relay: A->B and the packet dies at B.
      sim.send('A', destination: 'D', payload: [1], ttl: 1);
      await sim.runFor(const Duration(seconds: 10));
      expect(sim.packetsDeliveredTo('D'), 0);
    });

    test('direct neighbours exchange packets', () async {
      final sim = MeshSimulator(seed: 4, lossRate: 0);
      sim.addNode('A');
      sim.addNode('B');
      await sim.engines['A']!.start();
      await sim.engines['B']!.start();
      sim.link('A', 'B');
      sim.beginTracking('B');
      await sim.runFor(const Duration(seconds: 6));
      final outcome = sim.send('A', destination: 'B', payload: [42]);
      expect(outcome, isA<MeshSendForwarded>());
      await sim.runFor(const Duration(seconds: 5));
      expect(sim.packetsDeliveredTo('B'), 1);
    });

    test('a lost neighbour expires and its routes dissolve', () async {
      final sim = MeshSimulator(seed: 5, lossRate: 0);
      sim.addNode('A');
      sim.addNode('B');
      await sim.engines['A']!.start();
      await sim.engines['B']!.start();
      sim.link('A', 'B');
      await sim.runFor(const Duration(seconds: 6));
      expect(sim.engines['A']!.neighbors, isNotEmpty);

      sim.unlink('A', 'B');
      await sim.runFor(const Duration(seconds: 95));
      expect(sim.engines['A']!.neighbors, isEmpty);
    });
  });
}
