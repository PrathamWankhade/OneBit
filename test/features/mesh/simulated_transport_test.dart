import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_packet.dart';
import 'package:onebit/features/mesh/domain/mesh_transport.dart';
import 'package:onebit/features/mesh/simulation/simulated_transport.dart';

MeshPacket _packet() => MeshPacket(
  source: 'A',
  destination: 'B',
  kind: MeshPacketKind.data,
  ttl: 8,
  sequence: 1,
);

void main() {
  group('SimMeshWorld', () {
    test('pulses advertisements between linked transports', () async {
      final world = SimMeshWorld(lossRate: 0, random: Random(1));
      SimulatedTransport(nodeId: 'A', world: world);
      SimulatedTransport(nodeId: 'B', world: world);
      world.link('A', 'B');

      final seenByA = <MeshTransportEvent>[];
      world.transportOf('A')!.events.listen(seenByA.add);
      world.pulse(DateTime.utc(2026, 1, 1));

      await Future<void>.delayed(Duration.zero);
      final ad = seenByA.whereType<NeighborAdvertisementSeen>();
      expect(ad, isNotEmpty);
      expect(ad.single.nodeId, 'B');
      expect(ad.single.rssiDb, inInclusiveRange(-80, -55));
    });

    test('unlink removes neighbours from both sides', () {
      final world = SimMeshWorld(lossRate: 0, random: Random(2));
      SimulatedTransport(nodeId: 'A', world: world);
      SimulatedTransport(nodeId: 'B', world: world);
      world.link('A', 'B');
      expect(world.neighborsOf('A'), ['B']);
      world.unlink('A', 'B');
      expect(world.neighborsOf('A'), isEmpty);
      expect(world.areLinked('A', 'B'), isFalse);
    });

    test('deliver drops every packet at 100% loss', () {
      final world = SimMeshWorld(lossRate: 1, random: Random(3));
      SimulatedTransport(nodeId: 'A', world: world);
      final b = SimulatedTransport(nodeId: 'B', world: world);
      world.link('A', 'B');
      final signal = <MeshTransportEvent>[];
      b.events.listen(signal.add);
      final delivered = world.deliver('A', 'B', _packet());
      expect(delivered, isFalse);
      expect(signal, isEmpty);
    });

    test('connect and disconnect report link state', () async {
      final world = SimMeshWorld(lossRate: 0, random: Random(4));
      final a = SimulatedTransport(nodeId: 'A', world: world);
      SimulatedTransport(nodeId: 'B', world: world);
      final events = <MeshTransportEvent>[];
      a.events.listen(events.add);
      world.connect('A', 'B');
      await Future<void>.delayed(Duration.zero);
      expect(
        events.whereType<LinkStateChanged>().single.state,
        MeshLinkState.connected,
      );
    });
  });

  group('SimulatedTransport', () {
    test('follows the MeshTransport contract', () async {
      final world = SimMeshWorld(lossRate: 0, random: Random(5));
      final transport = SimulatedTransport(nodeId: 'N', world: world);
      final scanId = await transport.startScan();
      expect(scanId.isOk, isTrue);
      final scanStopped = await transport.stopScan(scanId.value!);
      expect(scanStopped.isOk, isTrue);
      final advId = await transport.startAdvertising();
      expect(advId.isOk, isTrue);
      final advStopped = await transport.stopAdvertising(advId.value!);
      expect(advStopped.isOk, isTrue);
      transport.dispose();
    });
  });
}
