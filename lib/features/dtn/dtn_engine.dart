import 'dart:async';

import 'data/network_recovery_manager.dart';
import 'delivery/delivery_scheduler.dart';
import 'delivery/dtn_config.dart';
import 'delivery/dtn_gateway.dart';
import 'delivery/store_forward_engine.dart';
import 'domain/dtn_connectivity.dart';
import 'domain/dtn_diagnostics.dart';
import 'domain/dtn_envelope.dart';
import 'domain/dtn_queue_snapshot.dart';
import 'domain/dtn_repository.dart';
import 'domain/dtn_statistics.dart';

/// The DTN engine facade: the only object callers touch.
///
/// Owns the store-and-forward machine, wires recovery and the scheduler, and
/// implements [DTNRepository]. Persistence is provided by the engine's
/// [StoreForwardEngine.persistence] (Sqlite in production, memory in tests).
final class DtnEngine implements DTNRepository {
  DtnEngine({required this._engine, required this._scheduler});

  /// Engine wired for memory storage — convenience for tooling and tests;
  /// production wiring goes through [start]-with-sqlite persistence.
  factory DtnEngine.inMemory({
    DtnEngineConfig config = const DtnEngineConfig(),
    DtnGateway gateway = const NoopDtnGateway(),
  }) {
    final engine = StoreForwardEngine(
      config: config,
      persistence: MemoryDtnPersistence(),
      now: DateTime.now,
      gateway: gateway,
    );
    final scheduler = DeliveryScheduler(engine: engine, gateway: gateway);
    return DtnEngine(engine: engine, scheduler: scheduler);
  }

  final StoreForwardEngine _engine;
  final DeliveryScheduler _scheduler;

  /// The underlying store-and-forward machine (dev tools, managers).
  StoreForwardEngine get storeForward => _engine;

  bool _running = false;

  /// Restore persisted envelopes (via the engine's persistence facade) and
  /// start the scheduler. Idempotent.
  Future<void> start() async {
    if (_running) {
      return;
    }
    final restored = await _engine.persistence.loadAll();
    const NetworkRecoveryManager().restore(_engine, restored);
    _engine.start();
    _running = true;
    _scheduler.start();
  }

  Future<void> stop() async {
    if (!_running) {
      return;
    }
    _running = false;
    await _scheduler.stop();
    _engine.dispose();
  }

  /// The connectivity perception changed (caller: gateway stream).
  void setConnectivity(DtnConnectivitySnapshot snapshot) {
    _engine.setConnectivity(snapshot);
    _scheduler.arm();
  }

  /// A new relay opportunity exists (topology change).
  void topologyChanged() => _scheduler.arm();

  // ---- DTNRepository -----------------------------------------------------------

  @override
  Future<DtnPacket> store(DtnPacket packet) async {
    final stored = _engine.store(packet);
    _scheduler.arm();
    return stored;
  }

  @override
  Future<bool> cancel(String packetId) async {
    _engine.cancel(packetId);
    _scheduler.arm();
    return true;
  }

  @override
  Future<DtnPacket?> statusOf(String packetId) async =>
      _engine.envelopes.where((p) => p.packetId == packetId).firstOrNull;

  @override
  Future<DtnPacket> observeDelivered() => _engine.inboundDeliveries.first;

  /// Live stream of inbound deliveries (shared, broadcast) — the DTN
  /// pump and the media/transfer gateways subscribe to the same stream.
  Stream<DtnPacket> get inboundDeliveries => _engine.inboundDeliveries;

  @override
  Stream<DtnQueueSnapshot> queueSnapshots() => _engine.queueSnapshots;

  @override
  Stream<DtnStatisticsSnapshot> statisticsSnapshots() =>
      _engine.statistics.stream;

  @override
  DtnStatisticsSnapshot get latestStatistics => _engine.statistics.snapshot();

  /// An inbound envelope reached this node as final destination.
  void deliverInbound(DtnPacket packet) => _engine.deliverLocally(packet);

  /// The remote node confirmed delivery (logical ack).
  void acknowledge(String packetId, {String? by}) =>
      _engine.acknowledge(packetId, by: by);

  /// Developer diagnostics ring.
  DtnDiagnosticsRing get diagnostics => _engine.diagnostics;

  /// Current queue snapshot (dev screens).
  DtnQueueSnapshot get queueSnapshot => _engine.snapshot();

  /// Current connectivity perception.
  DtnConnectivitySnapshot get connectivity => _engine.connectivity;
}
