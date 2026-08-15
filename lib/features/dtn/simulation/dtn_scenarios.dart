import 'package:onebit/features/dtn/delivery/dtn_config.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';
import 'package:onebit/features/dtn/simulation/dtn_simulator.dart';

/// A named DTN scenario producing a set of pass/fail checks.
final class DtnScenarioRun {
  const DtnScenarioRun({required this.name, required this.checks});

  final String name;
  final Map<String, bool> checks;
}

/// Development scenarios for the DTN simulator.
///
/// Every scenario drives a fresh [DtnSimulator] cluster and asserts an
/// expected store-and-forward behaviour.
abstract final class DtnScenarios {
  DtnScenarios._();

  /// A node is purely offline: stored envelopes park, never drop.
  static Future<DtnScenarioRun> offlineNode() async {
    final sim = DtnSimulator();
    sim.addNode('a');
    sim.addNode('b');
    sim.setReachable('a', false);
    sim.setReachable('b', false);

    sim.store('a', packetId: 'p1', destination: 'b');
    sim.store('a', packetId: 'p2', destination: 'b');
    sim.advance(const Duration(minutes: 5));

    return DtnScenarioRun(
      name: 'offline node',
      checks: {
        'packets kept':
            sim.status('a', 'p1') != null && sim.status('a', 'p2') != null,
        'none delivered': sim.stats('a')['delivered'] == 0,
        'parked (deferred)':
            sim.status('a', 'p1')!.state == DtnPacketState.deferred,
        'ttl still alive': !sim.status('a', 'p1')!.isTerminal,
      },
    );
  }

  /// Connectivity lost, then restored: parked envelopes auto-resume.
  static Future<DtnScenarioRun> reconnect() async {
    final sim = DtnSimulator();
    sim.addNode('a');
    sim.addNode('b');
    sim.setReachable('a', true);
    sim.setReachable('b', true);

    sim.store('a', packetId: 'p1', destination: 'b');
    sim.advance(const Duration(seconds: 10));
    sim.setReachable('a', false);
    sim.advance(const Duration(minutes: 1));
    sim.setReachable('a', true);
    sim.advance(const Duration(seconds: 30));

    return DtnScenarioRun(
      name: 'reconnect',
      checks: {
        'resumed packet delivered':
            sim.status('a', 'p1') == null || sim.status('a', 'p1')!.isDelivered,
        'delivered count reached 1': sim.stats('a')['delivered']! >= 1,
      },
    );
  }

  /// A large queue (1000 envelopes) drains without loss.
  static Future<DtnScenarioRun> largeQueue1000() async {
    final sim = DtnSimulator(
      config: const DtnEngineConfig(
        batchLimit: 64,
        retryPolicy: DtnRetryPolicy(
          baseDelay: Duration(seconds: 2),
          factor: 1,
          maxDelay: Duration(seconds: 2),
          jitterRatio: 0,
          limit: 12,
        ),
      ),
    );
    sim.addNode('a');
    sim.addNode('b');
    sim.setReachable('a', true);
    sim.setReachable('b', true);

    for (var i = 0; i < 1000; i++) {
      sim.store(
        'a',
        packetId: 'm$i',
        destination: 'b',
        payload: List.filled(64, i % 255),
      );
    }
    var drained = false;
    for (var i = 0; i < 60 && !drained; i++) {
      sim.advance(const Duration(seconds: 2));
      drained = sim.stats('a')['delivered'] == 1000;
    }

    return DtnScenarioRun(
      name: 'large queue 1000',
      checks: {
        'accepted all 1000': sim.stats('a')['stored'] == 1000,
        'drained to 1000': sim.stats('a')['delivered'] == 1000,
        'no remainder live': sim['a']!.engine.snapshot().live == 0,
      },
    );
  }

  /// Delayed delivery across an intermittent link (short offline gaps).
  static Future<DtnScenarioRun> delayedDelivery() async {
    final sim = DtnSimulator();
    sim.addNode('a');
    sim.addNode('b');
    sim.setReachable('a', true);
    sim.setReachable('b', true);

    sim.store('a', packetId: 'p1', destination: 'b');
    for (var i = 0; i < 5; i++) {
      sim.setReachable('a', false);
      sim.advance(const Duration(minutes: 3));
      sim.setReachable('a', true);
      sim.advance(const Duration(seconds: 20));
    }

    return DtnScenarioRun(
      name: 'delayed delivery',
      checks: {
        'eventually delivered':
            sim.status('a', 'p1') == null || sim.status('a', 'p1')!.isDelivered,
      },
    );
  }

  /// A node is isolated (partition), then the network merges; deliveries
  /// resume and both sides reach their peers.
  static Future<DtnScenarioRun> networkPartitionAndMerge() async {
    final sim = DtnSimulator();
    sim.addNode('a');
    sim.addNode('b');
    sim.addNode('c');
    sim.setReachable('a', true);
    sim.setReachable('b', true);
    sim.setReachable('c', true);

    sim.store('a', packetId: 'to-c', destination: 'c');
    sim.store('b', packetId: 'to-a', destination: 'a');

    sim.setReachable('a', false);
    sim.advance(const Duration(minutes: 2));
    sim.setReachable('a', true);
    sim.advance(const Duration(seconds: 15));

    return DtnScenarioRun(
      name: 'partition/merge',
      checks: {
        'to-c delivered after merge':
            sim.status('a', 'to-c') == null ||
            sim.status('a', 'to-c')!.isDelivered,
        'to-a delivered after merge':
            sim.status('b', 'to-a') == null ||
            sim.status('b', 'to-a')!.isDelivered,
      },
    );
  }

  /// Simulation restart: seed a fresh engine from serialized envelopes and
  /// confirm delivery continues (queue recovery across reboot).
  static Future<DtnScenarioRun> queueRecovery() async {
    final sim = DtnSimulator();
    sim.addNode('a');
    sim.addNode('b');
    sim.setReachable('a', false);
    sim.store('a', packetId: 'p1', destination: 'b');
    sim.advance(const Duration(seconds: 1));

    final persisted = await sim.rawPersistence('a').loadAll();

    final sim2 = DtnSimulator();
    final nodeA = sim2.addNode('a');
    nodeA.engine.restore(persisted);
    nodeA.engine.start();
    sim2.addNode('b');
    sim2.setReachable('a', true);
    sim2.setReachable('b', true);
    sim2.advance(const Duration(seconds: 30));

    return DtnScenarioRun(
      name: 'queue recovery',
      checks: {
        'restored envelope': sim2.status('a', 'p1') != null,
        'resumed and delivered': sim2.stats('a')['delivered']! >= 1,
      },
    );
  }

  /// Retry storm: 50 envelopes on a flapping link; all retry with backoff,
  /// none are lost, and all deliver once the link is back.
  static Future<DtnScenarioRun> retryStorm() async {
    final sim = DtnSimulator();
    sim.addNode('a');
    sim.addNode('b');
    sim.setReachable('a', true);
    sim.setReachable('b', true);

    // The radio link is flaky: the first 60 transmits fail transiently.
    sim['a']!.gateway.transientFailures = 60;

    for (var i = 0; i < 50; i++) {
      sim.store('a', packetId: 'r$i', destination: 'b');
    }
    // Retry windows open and close with backoff; the storm drains. Tick in
    // slices so every backoff window is evaluated.
    for (var i = 0; i < 60 && sim.stats('a')['delivered'] != 50; i++) {
      sim.advance(const Duration(seconds: 5));
    }

    return DtnScenarioRun(
      name: 'retry storm',
      checks: {
        'some retried': sim.stats('a')['retried']! > 0,
        'all eventually delivered or offline':
            sim.stats('a')['delivered'] == 50,
        'nothing expired': sim.stats('a')['expired'] == 0,
      },
    );
  }

  /// TTL expiry removes packets even while offline.
  static Future<DtnScenarioRun> packetExpiration() async {
    final sim = DtnSimulator();
    sim.addNode('a');
    sim.addNode('b');
    sim.setReachable('a', false);
    sim.store('a', packetId: 'e1', destination: 'b', ttlSeconds: 60);
    sim.store('a', packetId: 'e2', destination: 'b', ttlSeconds: 60);
    sim.advance(const Duration(minutes: 2));

    return DtnScenarioRun(
      name: 'packet expiration',
      checks: {
        'expired removed': sim.status('a', 'e1') == null,
        'expired counted': sim.stats('a')['expired'] == 2,
        'no live remain': sim.stats('a')['live'] == 0,
      },
    );
  }
}
