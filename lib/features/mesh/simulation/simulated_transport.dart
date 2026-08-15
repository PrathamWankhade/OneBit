import 'dart:async';
import 'dart:math';

import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_packet.dart';
import 'package:onebit/features/mesh/domain/mesh_transport.dart';

/// Shared radio medium for [SimulatedTransport]s.
///
/// Every transport connected to the same world sees neighbors as
/// advertisements and receives unicast packets with a configurable loss
/// rate — enough to exercise discovery, routing repair and partition
/// perception without a Bluetooth stack.
final class SimMeshWorld {
  SimMeshWorld({this.lossRate = 0.05, Random? random})
    : _random = random ?? Random(41);

  /// Fraction of unicast sends that vanish silently.
  double lossRate;
  final Random _random;

  final Map<String, SimulatedTransport> _transports = {};
  final Map<String, Map<String, int>> _intensityDb = {};

  void register(SimulatedTransport transport) {
    _transports[transport.nodeId] = transport;
  }

  void link(String a, String b, {int intensityDb = -60}) {
    _intensityDb.putIfAbsent(a, () => {})[b] = intensityDb;
    _intensityDb.putIfAbsent(b, () => {})[a] = intensityDb;
  }

  void unlink(String a, String b) {
    _intensityDb[a]?.remove(b);
    _intensityDb[b]?.remove(a);
  }

  List<String> neighborsOf(String nodeId) =>
      (_intensityDb[nodeId]?.keys ?? const <String>[]).toList();

  SimulatedTransport? transportOf(String nodeId) => _transports[nodeId];

  bool areLinked(String a, String b) =>
      _intensityDb[a]?.containsKey(b) ?? false;

  /// Broadcasts an advertisement from every node to each of its neighbors.
  void pulse(DateTime now) {
    for (final entry in _intensityDb.entries) {
      for (final neighborId in entry.value.keys) {
        final from = _transports[entry.key];
        if (from == null) continue;
        final to = _transports[neighborId];
        if (to == null) continue;
        final intensity = entry.value[neighborId] ?? -50;
        final rssiDb = intensity + _random.nextInt(7) - 3;
        from.emitAll(
          NeighborAdvertisementSeen(
            nodeId: to.nodeId,
            rssiDb: rssiDb,
            timestamp: now,
          ),
        );
      }
    }
  }

  /// Delivers [packet] from [sourceId] toward [targetId].
  ///
  /// A frame only crosses a live link: over a cut (or at random loss) it
  /// vanishes silently, exactly like a lost radio packet. Returns `false`
  /// when the frame never reached the peer.
  bool deliver(String sourceId, String targetId, MeshPacket packet) {
    if (!areLinked(sourceId, targetId)) return false;
    if (_random.nextDouble() < lossRate) return false;
    final target = _transports[targetId];
    if (target == null) return false;
    target.emitAll(
      PacketReceived(
        packet: packet,
        rssiDb: _intensityDb[targetId]?[sourceId] ?? -70,
      ),
    );
    return true;
  }

  /// Opens a connected link between [a] and [b].
  void connect(String a, String b) {
    _transports[a]?.emitAll(
      LinkStateChanged(nodeId: b, state: MeshLinkState.connected),
    );
    _transports[b]?.emitAll(
      LinkStateChanged(nodeId: a, state: MeshLinkState.connected),
    );
  }

  /// Closes the link between [a] and [b].
  void disconnect(String a, String b) {
    _transports[a]?.emitAll(
      LinkStateChanged(nodeId: b, state: MeshLinkState.disconnected),
    );
    _transports[b]?.emitAll(
      LinkStateChanged(nodeId: a, state: MeshLinkState.disconnected),
    );
  }
}

/// Adapter from in-memory world into the [MeshTransport] contract.
final class SimulatedTransport implements MeshTransport {
  SimulatedTransport({required this.nodeId, required SimMeshWorld world})
    : _world = world {
    world.register(this);
  }

  final String nodeId;
  final SimMeshWorld _world;

  final StreamController<MeshTransportEvent> _events =
      StreamController<MeshTransportEvent>.broadcast();

  @override
  Stream<MeshTransportEvent> get events => _events.stream;

  /// Injects [event] as if received from the radio.
  void emitAll(MeshTransportEvent event) => _events.add(event);

  @override
  Future<Result<String>> startScan() async => Ok('scan-$nodeId');

  @override
  Future<Result<void>> stopScan(String scanId) async => const Ok(null);

  @override
  Future<Result<String>> startAdvertising() async => Ok('adv-$nodeId');

  @override
  Future<Result<void>> stopAdvertising(String advertisingId) async =>
      const Ok(null);

  @override
  Future<Result<void>> connect(String nodeId) async {
    _world.connect(this.nodeId, nodeId);
    return const Ok(null);
  }

  @override
  Future<Result<void>> disconnect(String nodeId) async {
    _world.disconnect(this.nodeId, nodeId);
    return const Ok(null);
  }

  @override
  Future<Result<void>> send(String nodeId, MeshPacket packet) async {
    _world.deliver(this.nodeId, nodeId, packet);
    return const Ok(null);
  }

  @override
  Future<Result<void>> requestMtu(String nodeId, int mtu) async =>
      const Ok(null);

  void dispose() {
    _events.close();
  }
}
