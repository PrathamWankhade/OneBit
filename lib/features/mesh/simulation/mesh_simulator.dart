import 'dart:async';
import 'dart:math';

import 'package:onebit/features/mesh/domain/mesh_clock.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_packet.dart';
import 'package:onebit/features/mesh/domain/mesh_repository.dart';
import 'package:onebit/features/mesh/engine/mesh_engine.dart';
import 'package:onebit/features/mesh/simulation/simulated_transport.dart';

/// Headless multi-node mesh harness.
///
/// Creates [MeshEngine]s, one per node, all attached to the same
/// in-memory radio world and driven by a single [ManualMeshClock]. Every
/// overlay tick pulses advertisements so neighbor tables stay fresh; callers
/// then advance the clock and inspect per-node state.
final class MeshSimulator {
  MeshSimulator({
    this.advertisementInterval = const Duration(seconds: 5),
    double lossRate = 0.05,
    int? seed,
  }) : world = SimMeshWorld(lossRate: lossRate, random: Random(seed ?? 41)),
       clock = ManualMeshClock() {
    _advTask = clock.schedule(advertisementInterval, _onAdvertisementTick);
  }

  final SimMeshWorld world;
  final ManualMeshClock clock;
  final Duration advertisementInterval;

  final Map<String, MeshEngine> engines = {};
  final Map<String, SimulatedTransport> transports = {};

  late MeshScheduledTask _advTask;

  void _onAdvertisementTick() {
    world.pulse(clock.now());
    _advTask = clock.schedule(advertisementInterval, _onAdvertisementTick);
  }

  /// Creates and registers a node engine.
  MeshEngine addNode(String nodeId) {
    if (engines.containsKey(nodeId)) {
      throw ArgumentError('Node "$nodeId" already exists');
    }
    final transport = SimulatedTransport(nodeId: nodeId, world: world);
    final engine = MeshEngine(
      localNodeId: nodeId,
      transport: transport,
      clock: clock,
    );
    transports[nodeId] = transport;
    engines[nodeId] = engine;
    return engine;
  }

  /// Creates and starts a node engine without awaiting.
  void addAndStart(String nodeId) {
    unawaited(addNode(nodeId).start());
  }

  /// Radio link between two nodes, with a received-signal intensity.
  void link(String a, String b, {int intensityDb = -60}) {
    world.link(a, b, intensityDb: intensityDb);
  }

  /// Removes the radio link between two nodes.
  void unlink(String a, String b) {
    world.unlink(a, b);
  }

  /// Moves the shared clock forward by [delta], firing advertisement ticks
  /// and engine sweeps in order.
  void advance(Duration delta) => clock.advance(delta);

  /// Yields to the event loop and drains the queued stream deliveries the
  /// overlay engines produced (one microtask pass is enough: every relayed
  /// hop re-enters the microtask queue in order).
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  /// Runs the simulation for [total], advancing in [step] slices and
  /// flushing stream deliveries between each slice.
  Future<void> runFor(
    Duration total, {
    Duration step = const Duration(seconds: 1),
  }) async {
    var elapsed = Duration.zero;
    while (elapsed < total) {
      clock.advance(step);
      await flush();
      elapsed = elapsed + step;
    }
  }

  /// Synchronous convenience wrapper around [MeshEngine.send].
  MeshSendResult send(
    String from, {
    required String destination,
    required List<int> payload,
    int ttl = 8,
  }) {
    return engines[from]!.send(
      destination: destination,
      payload: payload,
      ttl: ttl,
    );
  }

  Map<String, MeshEngineState> states() => {
    for (final entry in engines.entries) entry.key: entry.value.state,
  };

  Map<String, List<String>> neighbors() => {
    for (final entry in engines.entries)
      entry.key: entry.value.neighbors.map((n) => n.nodeId).toList(),
  };

  int packetsDeliveredTo(String nodeId) => _deliveredPacketCount[nodeId] ?? 0;

  final Map<String, int> _deliveredPacketCount = {};

  void beginTracking(String nodeId) {
    _deliveredPacketCount.putIfAbsent(nodeId, () => 0);
    engines[nodeId]!.deliveredUpStream.listen((packet) {
      if (packet.kind != MeshPacketKind.data) return;
      _deliveredPacketCount[nodeId] = _deliveredPacketCount[nodeId]! + 1;
    });
  }

  void dispose() {
    _advTask.cancel();
    for (final t in transports.values) {
      t.dispose();
    }
  }
}
