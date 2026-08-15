import 'package:onebit/features/dtn/delivery/dtn_config.dart';
import 'package:onebit/features/dtn/delivery/simulated_mesh_gateway.dart';
import 'package:onebit/features/dtn/delivery/store_forward_engine.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';
import 'package:onebit/features/dtn/domain/dtn_priority.dart';

/// One simulated node: an engine + its own controllable gateway.
final class DtnSimNode {
  DtnSimNode({
    required this.nodeId,
    required DtnEngineConfig config,
    required DateTime Function() now,
  }) : gateway = SimulatedMeshGateway(reachable: false) {
    engine = StoreForwardEngine(
      config: config,
      persistence: MemoryDtnPersistence(),
      now: now,
      gateway: gateway,
    );
  }

  final String nodeId;
  final SimulatedMeshGateway gateway;
  late final StoreForwardEngine engine;
}

/// Headless multi-node DTN harness for scenario simulation.
///
/// Every node owns a [StoreForwardEngine] over an in-memory store and its own
/// controllable [SimulatedMeshGateway]. Scenarios drive reachability, step the
/// wall clock, and run the scheduler pass on each node.
final class DtnSimulator {
  DtnSimulator({
    this.config = const DtnEngineConfig(
      batchLimit: 64,
      retryPolicy: DtnRetryPolicy(
        baseDelay: Duration(seconds: 10),
        factor: 2,
        maxDelay: Duration(minutes: 2),
        jitterRatio: 0.1,
        limit: 12,
      ),
    ),
    DateTime? base,
  }) : _now = base ?? DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);

  final DtnEngineConfig config;
  DateTime _now;
  final Map<String, DtnSimNode> _nodes = {};

  DateTime get now => _now;

  Iterable<DtnSimNode> get nodes => _nodes.values;

  DtnSimNode? operator [](String nodeId) => _nodes[nodeId];

  /// Add a node with an isolated engine.
  DtnSimNode addNode(String nodeId) {
    final node = DtnSimNode(nodeId: nodeId, config: config, now: () => _now);
    _nodes[nodeId] = node;
    return node;
  }

  /// Bring a node online (mesh reachable) or offline.
  void setReachable(String nodeId, bool reachable) {
    final node = _nodes[nodeId]!;
    node.gateway.reachable = reachable;
    node.engine.setConnectivity(node.gateway.connectivity());
  }

  /// Step the wall clock and run a scheduling pass on every node.
  void advance(Duration by) {
    _now = _now.add(by);
    for (final node in _nodes.values) {
      tick(node, at: _now);
    }
  }

  /// One scheduling pass for [node] (mirrors DeliveryScheduler.tick).
  void tick(DtnSimNode node, {DateTime? at}) {
    final now = at ?? _now;
    final engine = node.engine;

    final due = engine.expiredDue(now);
    if (due.isNotEmpty) {
      engine.expireAll(due, at: now);
    }

    final connectivity = node.gateway.connectivity();
    engine.setConnectivity(connectivity);
    if (!connectivity.reachable) {
      engine.parkAll(at: now);
      return;
    }

    engine.rearmRetries(engine.retriesDue(now));
    engine.rearmRelaying();
    engine.unparkAll(at: now);

    for (final packet in engine.outgoingCandidates()) {
      final outcome = node.gateway.transmit(packet);
      engine.noteAttempt(
        packet.packetId,
        outcome.ok,
        error: outcome.errorMessage,
        permanent: outcome.permanent,
        willAck: outcome.willAck,
        at: now,
      );
    }

    final timeouts = engine.ackTimeouts(now);
    if (timeouts.isNotEmpty) {
      engine.rearmAckTimeouts(timeouts);
    }
  }

  /// Store an outbound envelope on [nodeId].
  DtnPacket store(
    String nodeId, {
    required String packetId,
    required String destination,
    List<int> payload = const [1, 2, 3],
    int priority = 2,
    int ttlSeconds = 3600,
  }) {
    final node = _nodes[nodeId]!;
    final now = _now;
    return node.engine.store(
      DtnPacket(
        packetId: packetId,
        source: nodeId,
        destination: destination,
        payload: payload,
        priority: DtnPriority.values[priority.clamp(0, 4)],
        direction: DtnDirection.outbound,
        ttlSeconds: ttlSeconds,
        createdAt: now,
        expiresAt: now.add(Duration(seconds: ttlSeconds)),
      ),
    );
  }

  /// Envelope state on a node (null when unknown).
  DtnPacket? status(String nodeId, String packetId) =>
      _nodes[nodeId]?.engine.statusOf(packetId);

  /// The persistence behind a node's engine (reboot simulations).
  DtnPersistence rawPersistence(String nodeId) =>
      _nodes[nodeId]!.engine.persistence;

  /// Counter summary for a node.
  Map<String, int> stats(String nodeId) {
    final s = _nodes[nodeId]!.engine.statistics.snapshot();
    return {
      'live': s.liveEnvelopes,
      'stored': s.stored,
      'delivered': s.delivered,
      'expired': s.expired,
      'retried': s.retried,
      'parked': s.parked,
      'relayed': s.relayed,
    };
  }
}
