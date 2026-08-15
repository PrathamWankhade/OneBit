import 'package:onebit/features/mesh/domain/mesh_repository.dart';
import 'package:onebit/features/mesh/simulation/mesh_simulator.dart';

final class ScenarioRun {
  const ScenarioRun({required this.name, required this.checks});

  final String name;
  final Map<String, bool> checks;

  int get passed => checks.values.where((v) => v).length;
  int get failed => checks.length - passed;
}

/// Deterministic multi-node scenarios. Every scenario builds its own
/// simulator, runs a fixed amount of simulated time, and returns pass/fail
/// assertions that the tool and the test suite both consume.
final class MeshScenarios {
  static Future<void> _startAll(MeshSimulator sim, Iterable<String> ids) async {
    for (final id in ids) {
      await sim.engines[id]!.start();
    }
  }

  /// Two devices rendezvous and a local packet is delivered.
  static Future<ScenarioRun> twoNodeDeliver() async {
    final sim = MeshSimulator(seed: 7, lossRate: 0);
    sim.addNode('A');
    sim.addNode('B');
    await _startAll(sim, const ['A', 'B']);
    sim.link('A', 'B');
    sim.beginTracking('B');

    // Let the first advertisement pulse reach both sides first.
    await sim.runFor(const Duration(seconds: 6));
    final outcome = sim.send('A', destination: 'B', payload: 'hello'.codeUnits);
    await sim.runFor(const Duration(seconds: 10));

    return ScenarioRun(
      name: 'two-node deliver',
      checks: {
        'accepted by A relay': outcome is MeshSendForwarded,
        'B received the packet': sim.packetsDeliveredTo('B') >= 1,
        "A learned B's route": sim.engines['A']!.routes.any(
          (r) => r.destination == 'B',
        ),
      },
    );
  }

  /// A packet crosses a five-node line after route discovery.
  static Future<ScenarioRun> fiveNodeChain() async {
    final sim = MeshSimulator(seed: 11, lossRate: 0);
    const ids = ['A', 'B', 'C', 'D', 'E'];
    for (final id in ids) {
      sim.addNode(id);
    }
    await _startAll(sim, ids);
    for (var i = 0; i < ids.length - 1; i++) {
      sim.link(ids[i], ids[i + 1]);
    }
    sim.beginTracking('E');

    // Let every node see its direct neighbours first.
    await sim.runFor(const Duration(seconds: 6));
    // First send has no route: it fires the discovery broadcast.
    sim.send('A', destination: 'E', payload: [1, 2, 3]);
    await sim.runFor(const Duration(seconds: 15));

    final outcome = sim.send('A', destination: 'E', payload: [4, 5, 6]);
    await sim.flush();
    final route = sim.engines['A']!.routes
        .where((r) => r.destination == 'E')
        .firstOrNull;

    return ScenarioRun(
      name: 'five-node chain',
      checks: {
        'A relayed packet': outcome is MeshSendForwarded,
        'discovery learned a multi-hop route': route?.nextHop == 'B',
        'E received the payload': sim.packetsDeliveredTo('E') >= 1,
      },
    );
  }

  /// Ten-node ring: multi-hop neighbours reach each other across the ring.
  static Future<ScenarioRun> tenNodeRing() async {
    final sim = MeshSimulator(seed: 3, lossRate: 0);
    final ids = List.generate(10, (i) => 'n$i');
    for (var i = 0; i < 10; i++) {
      sim.addNode(ids[i]);
    }
    await _startAll(sim, ids);
    for (var i = 0; i < 10; i++) {
      sim.link(ids[i], ids[(i + 1) % 10]);
    }
    for (var i = 0; i < 10; i++) {
      sim.beginTracking(ids[i]);
    }
    await sim.runFor(const Duration(seconds: 6));
    // Discovery probe across the far side of the ring.
    sim.send('n2', destination: 'n7', payload: 'ping'.codeUnits);
    await sim.runFor(const Duration(seconds: 20));
    final outcome = sim.send(
      'n2',
      destination: 'n7',
      payload: 'pong'.codeUnits,
    );
    await sim.flush();

    return ScenarioRun(
      name: 'ten-node ring',
      checks: {
        'far endpoint reached': sim.packetsDeliveredTo('n7') >= 1,
        'relayed around the ring': outcome is MeshSendForwarded,
        'every node still running': sim.engines.values.every(
          (e) => e.isRunning,
        ),
      },
    );
  }

  /// A relay node dies; traffic pauses, then recovers via a new link.
  static Future<ScenarioRun> relayFailureSurvives() async {
    final sim = MeshSimulator(seed: 9, lossRate: 0);
    sim.addNode('A');
    sim.addNode('B');
    sim.addNode('hub');
    await _startAll(sim, const ['A', 'B', 'hub']);
    sim.link('A', 'hub');
    sim.link('hub', 'B');
    sim.beginTracking('B');

    // Learn A→B through the hub.
    await sim.runFor(const Duration(seconds: 6));
    sim.send('A', destination: 'B', payload: 'discover'.codeUnits);
    await sim.runFor(const Duration(seconds: 20));
    final viaHub = sim.send('A', destination: 'B', payload: 'hop'.codeUnits);
    await sim.flush();
    final deliveredWithHub = sim.packetsDeliveredTo('B');

    // The hub disappears; neighbours and routes stale out within 5 minutes.
    sim.unlink('A', 'hub');
    sim.unlink('hub', 'B');
    await sim.runFor(const Duration(minutes: 6));
    final duringOutage = sim.send(
      'A',
      destination: 'B',
      payload: 'lost'.codeUnits,
    );

    // A rescue link reconnects the pair.
    sim.link('A', 'B', intensityDb: -72);
    await sim.runFor(const Duration(seconds: 60));
    final recovered = sim.send(
      'A',
      destination: 'B',
      payload: 'saved'.codeUnits,
    );
    await sim.flush();
    final deliveredAfter = sim.packetsDeliveredTo('B');

    return ScenarioRun(
      name: 'relay failure survives',
      checks: {
        'hub carried traffic before failure':
            viaHub is MeshSendForwarded && deliveredWithHub >= 1,
        'outage was detected': duringOutage is MeshSendDiscoveryPending,
        'recovered after new link':
            recovered is MeshSendForwarded && deliveredAfter > deliveredWithHub,
      },
    );
  }

  /// Twenty nodes on a 5×4 lattice: a diagonal packet crosses six relays
  /// and every engine stays within its bounded state.
  static Future<ScenarioRun> twentyNodeLattice() async {
    final sim = MeshSimulator(seed: 17, lossRate: 0);
    const rows = 4, cols = 5, total = rows * cols;
    final ids = List.generate(total, (i) => 'n$i');
    for (final id in ids) {
      sim.addNode(id);
    }
    await _startAll(sim, ids);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (c + 1 < cols) {
          sim.link('n${r * cols + c}', 'n${r * cols + c + 1}');
        }
        if (r + 1 < rows) {
          sim.link('n${r * cols + c}', 'n${(r + 1) * cols + c}');
        }
      }
    }
    sim.beginTracking('n18');
    await sim.runFor(const Duration(seconds: 6));

    sim.engines['n0']!.discoverRoute('n18');
    await sim.runFor(const Duration(seconds: 20));
    final route = sim.engines['n0']!.routes
        .where((r) => r.destination == 'n18')
        .firstOrNull;
    final outcome = sim.send('n0', destination: 'n18', payload: [1]);
    await sim.runFor(const Duration(seconds: 20));

    return ScenarioRun(
      name: 'twenty-node lattice',
      checks: {
        'diagonal send accepted': outcome is MeshSendForwarded,
        '6-hop destination reached': sim.packetsDeliveredTo('n18') >= 1,
        'discovery learned a bounded route':
            route != null && route.hopCount <= 7,
        'all twenty engines still running': sim.engines.values.every(
          (e) => e.isRunning,
        ),
      },
    );
  }

  /// Fifty nodes on a two-rail ladder. Link cuts mid-run partition the
  /// rails, restoration reunites them; state stays bounded throughout.
  static Future<ScenarioRun> fiftyNodeChurn() async {
    final sim = MeshSimulator(seed: 23, lossRate: 0);
    final ids = List.generate(50, (i) => 'n$i');
    for (final id in ids) {
      sim.addNode(id);
    }
    await _startAll(sim, ids);
    for (var i = 0; i < 25; i++) {
      if (i + 1 < 25) {
        sim.link('n$i', 'n${i + 1}');
        sim.link('n${i + 25}', 'n${i + 26}');
      }
      if (i % 3 == 0) {
        sim.link('n$i', 'n${i + 25}');
      }
    }
    for (var i = 0; i < 50; i += 7) {
      sim.beginTracking('n$i');
    }
    sim.beginTracking('n29');
    sim.beginTracking('n4');
    await sim.runFor(const Duration(seconds: 6));

    // Churn: two rail segments and one rung are cut, then restored.
    sim.unlink('n20', 'n21');
    sim.unlink('n45', 'n46');
    sim.unlink('n12', 'n37');
    await sim.runFor(const Duration(minutes: 2));
    sim.link('n20', 'n21');
    sim.link('n45', 'n46');
    sim.link('n12', 'n37');
    await sim.runFor(const Duration(minutes: 4));

    // Short cross-rail journeys, both within the default TTL.
    sim.engines['n0']!.discoverRoute('n29');
    sim.engines['n25']!.discoverRoute('n4');
    await sim.runFor(const Duration(seconds: 30));
    sim.send('n0', destination: 'n29', payload: [1]);
    sim.send('n25', destination: 'n4', payload: [2]);
    await sim.runFor(const Duration(seconds: 30));

    return ScenarioRun(
      name: 'fifty-node churn',
      checks: {
        'cross-rail traffic delivered after churn':
            sim.packetsDeliveredTo('n29') >= 1 &&
            sim.packetsDeliveredTo('n4') >= 1,
        'duplicate caches stayed within capacity': sim.engines.values.every(
          (e) =>
              e.diagnosticsSnapshot.duplicateCache.entries <=
              e.diagnosticsSnapshot.duplicateCache.capacity,
        ),
        'neighbor tables stayed bounded (degree + slack)': sim.engines.values
            .every((e) => e.neighbors.length <= 8),
        'no route table explosion': sim.engines.values.every(
          (e) => e.routes.length <= 49,
        ),
        'every engine survived the churn': sim.engines.values.every(
          (e) => e.isRunning,
        ),
      },
    );
  }

  /// A third node appears next to an existing pair; routes to it converge
  /// within one discovery round.
  static Future<ScenarioRun> nodeJoinLearned() async {
    final sim = MeshSimulator(seed: 8, lossRate: 0);
    sim.addNode('A');
    sim.addNode('B');
    await _startAll(sim, const ['A', 'B']);
    sim.link('A', 'B');
    await sim.runFor(const Duration(seconds: 6));

    sim.addNode('C');
    await sim.engines['C']!.start();
    sim.beginTracking('C');
    sim.link('B', 'C');
    await sim.runFor(const Duration(seconds: 30));

    sim.engines['A']!.discoverRoute('C');
    await sim.runFor(const Duration(seconds: 20));
    final route = sim.engines['A']!.routes
        .where((r) => r.destination == 'C')
        .firstOrNull;
    final outcome = sim.send('A', destination: 'C', payload: [7]);
    await sim.runFor(const Duration(seconds: 15));

    return ScenarioRun(
      name: 'node join discovered',
      checks: {
        'A learned a two-hop route to the newcomer':
            route != null && route.hopCount == 2,
        'A accepted the outgoing send': outcome is MeshSendForwarded,
        'packet delivered to the newcomer': sim.packetsDeliveredTo('C') >= 1,
        'the newcomer discovered its neighbours': sim.engines['C']!.neighbors
            .any((n) => n.nodeId == 'B'),
      },
    );
  }

  /// A node leaves the mesh: its neighbour entry expires, routes through
  /// it dissolve, and sends against it re-arm route discovery.
  static Future<ScenarioRun> nodeLeaveDissolves() async {
    final sim = MeshSimulator(seed: 15, lossRate: 0);
    const ids = ['A', 'B', 'C'];
    for (final id in ids) {
      sim.addNode(id);
      await sim.engines[id]!.start();
    }
    sim.link('A', 'B');
    sim.link('B', 'C');
    sim.beginTracking('C');
    await sim.runFor(const Duration(seconds: 6));

    sim.engines['A']!.discoverRoute('C');
    await sim.runFor(const Duration(seconds: 20));
    final before = sim.send('A', destination: 'C', payload: [1]);
    await sim.runFor(const Duration(seconds: 5));
    final deliveredBefore = sim.packetsDeliveredTo('C');

    // C leaves: links cut and the engine stopped.
    sim.unlink('B', 'C');
    await sim.engines['C']!.stop();
    await sim.runFor(const Duration(minutes: 6));
    final duringLeave = sim.send('A', destination: 'C', payload: [2]);

    return ScenarioRun(
      name: 'node leave dissolves routes',
      checks: {
        'traffic flowed before the leave':
            before is MeshSendForwarded && deliveredBefore >= 1,
        'C expired from B': sim.engines['B']!.neighbors.every(
          (n) => n.nodeId != 'C',
        ),
        'B dropped its route to the leaver': sim.engines['B']!.routes
            .where((r) => r.destination == 'C')
            .isEmpty,
        'A no longer routes to the leaver': sim.engines['A']!.routes
            .where((r) => r.destination == 'C')
            .isEmpty,
        'post-leave sends trigger discovery re-arm':
            duringLeave is MeshSendDiscoveryPending,
      },
    );
  }

  /// A primary relay dies on a diamond; the surviving parallel relay is
  /// promoted without any new links.
  static Future<ScenarioRun> routeFailureRepairs() async {
    final sim = MeshSimulator(seed: 21, lossRate: 0);
    const ids = ['A', 'B', 'C', 'D'];
    for (final id in ids) {
      sim.addNode(id);
      await sim.engines[id]!.start();
    }
    sim.beginTracking('D');
    sim.link('A', 'B');
    sim.link('B', 'D');
    sim.link('A', 'C');
    sim.link('C', 'D');
    await sim.runFor(const Duration(seconds: 6));

    // A ghost-target discovery floods both paths, teaching A the reverse
    // routes to D through B and through C (both copies learn pre-dedup).
    sim.engines['D']!.discoverRoute('GHOST');
    await sim.runFor(const Duration(seconds: 10));

    // The primary relay dies.
    sim.unlink('A', 'B');
    sim.unlink('B', 'D');
    await sim.engines['B']!.stop();
    await sim.runFor(const Duration(seconds: 95));

    final primary = sim.engines['A']!.routes
        .where((r) => r.destination == 'D')
        .firstOrNull;
    final outcome = sim.send('A', destination: 'D', payload: [9]);
    await sim.runFor(const Duration(seconds: 15));

    return ScenarioRun(
      name: 'route failure repairs',
      checks: {
        'surviving relay promoted after failure':
            primary != null && primary.nextHop == 'C',
        'traffic rerouted through the survivor':
            outcome is MeshSendForwarded && sim.packetsDeliveredTo('D') >= 1,
      },
    );
  }

  /// The single bridge of a five-node line is cut: the far cluster
  /// vanishes from the hub's view and cross traffic stops cleanly.
  static Future<ScenarioRun> networkPartitionIsolates() async {
    final sim = MeshSimulator(seed: 22, lossRate: 0);
    const ids = ['A', 'B', 'H', 'D', 'E'];
    for (final id in ids) {
      sim.addNode(id);
      await sim.engines[id]!.start();
    }
    for (var i = 0; i < ids.length - 1; i++) {
      sim.link(ids[i], ids[i + 1]);
    }
    sim.beginTracking('E');
    await sim.runFor(const Duration(seconds: 6));

    sim.engines['A']!.discoverRoute('E');
    await sim.runFor(const Duration(seconds: 20));
    final before = sim.send('A', destination: 'E', payload: [1]);
    await sim.runFor(const Duration(seconds: 5));
    final deliveredBefore = sim.packetsDeliveredTo('E');

    // Cut the bridge between the clusters.
    sim.unlink('B', 'H');
    await sim.runFor(const Duration(minutes: 2));
    final duringCut = sim.send('A', destination: 'E', payload: [2]);
    await sim.runFor(const Duration(seconds: 5));
    final deliveredDuring = sim.packetsDeliveredTo('E');

    return ScenarioRun(
      name: 'network partition isolates',
      checks: {
        'traffic crossed the bridge before the cut':
            before is MeshSendForwarded && deliveredBefore >= 1,
        'B expired from the hub': sim.engines['H']!.neighbors.every(
          (n) => n.nodeId != 'B',
        ),
        'hub lost its far-side routes': sim.engines['H']!.routes
            .where((r) => r.destination == 'B' || r.destination == 'A')
            .isEmpty,
        'far-side nodes left the hub topology': sim
            .engines['H']!
            .topologySnapshot
            .nodes
            .where((n) => n.nodeId == 'A' || n.nodeId == 'B')
            .isEmpty,
        'far-side routes dissolved at the gateway': sim.engines['B']!.routes
            .where((r) => r.destination == 'H' || r.destination == 'E')
            .isEmpty,
        'cross-cut sends stopped delivering':
            duringCut is MeshSendForwarded &&
            deliveredDuring == deliveredBefore,
      },
    );
  }

  /// The bridge returns: the hub re-observes the far cluster, routes
  /// reconverge and traffic flows again.
  static Future<ScenarioRun> topologyRecoveryReconnects() async {
    final sim = MeshSimulator(seed: 22, lossRate: 0);
    const ids = ['A', 'B', 'H', 'D', 'E'];
    for (final id in ids) {
      sim.addNode(id);
      await sim.engines[id]!.start();
    }
    for (var i = 0; i < ids.length - 1; i++) {
      sim.link(ids[i], ids[i + 1]);
    }
    sim.beginTracking('E');
    await sim.runFor(const Duration(seconds: 6));

    sim.engines['A']!.discoverRoute('E');
    await sim.runFor(const Duration(seconds: 20));
    sim.send('A', destination: 'E', payload: [1]);
    await sim.runFor(const Duration(seconds: 5));

    // Cut, let the far side age out of the hub, then restore the bridge.
    sim.unlink('B', 'H');
    await sim.runFor(const Duration(minutes: 2));
    sim.link('B', 'H');
    await sim.runFor(const Duration(seconds: 30));

    sim.engines['A']!.discoverRoute('E');
    await sim.runFor(const Duration(seconds: 20));
    final recovered = sim.send('A', destination: 'E', payload: [3]);
    await sim.runFor(const Duration(seconds: 15));

    return ScenarioRun(
      name: 'topology recovery reconnects',
      checks: {
        'hub re-observed the far cluster':
            sim.engines['H']!.neighbors.any((n) => n.nodeId == 'B') &&
            sim.engines['H']!.topologySnapshot.nodes.any(
              (n) => n.nodeId == 'A',
            ),
        'routes reconverged after the bridge returned': sim.engines['A']!.routes
            .where((r) => r.destination == 'E')
            .isNotEmpty,
        'traffic flows again across the healed mesh':
            recovered is MeshSendForwarded && sim.packetsDeliveredTo('E') >= 2,
      },
    );
  }
}
