import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/mesh/cache/duplicate_packet_detector.dart';
import 'package:onebit/features/mesh/domain/mesh_clock.dart';
import 'package:onebit/features/mesh/domain/mesh_packet.dart';
import 'package:onebit/features/mesh/neighbor/neighbor_table.dart';
import 'package:onebit/features/mesh/relay/relay_decision.dart';
import 'package:onebit/features/mesh/relay/relay_engine.dart';
import 'package:onebit/features/mesh/relay/relay_queue.dart';
import 'package:onebit/features/mesh/relay/ttl_manager.dart';
import 'package:onebit/features/mesh/routing/loop_detector.dart';
import 'package:onebit/features/mesh/routing/packet_factory.dart';
import 'package:onebit/features/mesh/routing/route_optimizer.dart';
import 'package:onebit/features/mesh/routing/route_table.dart';
import 'package:onebit/features/mesh/routing/routing_engine.dart';

final class RelayHarness {
  RelayHarness({required this.localNodeId, required this.liveNeighbors}) {
    clock = ManualMeshClock();
    peers = NeighborTable();
    for (final id in liveNeighbors) {
      peers.upsertAdvertisement(id, -55, clock.now());
    }
    routing = RoutingEngine(
      localNodeId: localNodeId,
      now: clock.now,
      table: RouteTable(time: clock.now),
      optimizer: RouteOptimizer(),
      factory: MeshPacketFactory(localNodeId: localNodeId, now: clock.now),
      neighborOf: peers.byId,
    );
    relay = RelayEngine(
      localNodeId: localNodeId,
      routing: routing,
      ttl: const TTLManager(),
      loopDetector: const LoopDetector(),
      duplicateDetector: DuplicatePacketDetector(now: clock.now),
      queue: InMemoryRelayQueue(capacity: 16),
      liveNeighborIds: () => List.of(liveNeighbors),
      now: clock.now,
    );
  }

  final String localNodeId;
  final List<String> liveNeighbors;
  late final ManualMeshClock clock;
  late final NeighborTable peers;
  late final RoutingEngine routing;
  late final RelayEngine relay;
}

MeshPacket _packet({
  String source = 'X',
  String destination = 'Z',
  int sequence = 1,
  int ttl = 8,
  List<String> path = const [],
  MeshControl? control,
}) => MeshPacket(
  source: source,
  destination: destination,
  kind: control == null ? MeshPacketKind.data : MeshPacketKind.control,
  control: control,
  ttl: ttl,
  sequence: sequence,
  path: path,
);

void main() {
  group('RelayEngine', () {
    test('delivers packets addressed to the local node', () {
      final h = RelayHarness(localNodeId: 'A', liveNeighbors: const []);
      final packet = _packet(source: 'X', destination: 'A');
      final outcome = h.relay.decide(packet);
      expect(outcome, isA<RelayDeliverUp>());
      expect((outcome as RelayDeliverUp).packet, same(packet));
    });

    test('drops packets it originated', () {
      final h = RelayHarness(localNodeId: 'A', liveNeighbors: const []);
      final packet = _packet(source: 'A');
      final outcome = h.relay.decide(packet);
      expect(outcome, isA<RelayDropped>());
      expect((outcome as RelayDropped).reason, RelayDropReason.ownPacket);
    });

    test('origin bypasses the own-packet drop', () {
      final h = RelayHarness(localNodeId: 'A', liveNeighbors: const []);
      final packet = _packet(source: 'A');
      final outcome = h.relay.decide(packet, origin: true);
      expect(outcome, isA<RelayDropped>());
      expect((outcome as RelayDropped).reason, RelayDropReason.noRoute);
    });

    test('drops packets past their TTL', () {
      final h = RelayHarness(localNodeId: 'A', liveNeighbors: const []);
      final packet = _packet(ttl: 0);
      final outcome = h.relay.decide(packet);
      expect(outcome, isA<RelayDropped>());
      expect((outcome as RelayDropped).reason, RelayDropReason.ttlExpired);
    });

    test('drops duplicates re-entering the pipeline', () {
      final h = RelayHarness(localNodeId: 'A', liveNeighbors: const []);
      final packet = _packet(sequence: 99);
      h.relay.decide(packet, origin: true);
      final second = h.relay.decide(packet, origin: true);
      expect(second, isA<RelayDropped>());
      expect((second as RelayDropped).reason, RelayDropReason.duplicate);
    });

    test('drops packets re-entering a node already on the path', () {
      final h = RelayHarness(localNodeId: 'C', liveNeighbors: const []);
      final packet = _packet(path: const ['B', 'A', 'C']);
      final outcome = h.relay.decide(packet);
      expect(outcome, isA<RelayDropped>());
      expect((outcome as RelayDropped).reason, RelayDropReason.loop);
    });

    test('broadcasts to every live neighbor safely', () {
      final h = RelayHarness(localNodeId: 'A', liveNeighbors: const ['B', 'C']);
      final packet = _packet(destination: '', sequence: 1);
      final outcome = h.relay.decide(packet);
      expect(outcome, isA<RelayQueued>());
      final forwards = (outcome as RelayQueued).forwards;
      expect(forwards, hasLength(2));
      expect(forwards.map((t) => t.to), containsAll(['B', 'C']));
      expect(forwards.every((t) => t.packet.ttl == 7), isTrue);
      expect(forwards.every((t) => t.packet.path.contains('A')), isTrue);
    });

    test('forwards unicast along a learned route', () {
      final h = RelayHarness(localNodeId: 'A', liveNeighbors: const ['B']);
      h.routing.offerDirect('B');
      final packet = _packet(destination: 'B', sequence: 2);
      final outcome = h.relay.decide(packet);
      expect(outcome, isA<RelayQueued>());
      final forwards = (outcome as RelayQueued).forwards;
      expect(forwards.single.to, 'B');
      expect(forwards.single.packet.ttl, 7);
    });

    test('follows a discovery reply along its recorded path', () {
      final h = RelayHarness(localNodeId: 'C', liveNeighbors: const ['B']);
      final reply = _packet(
        source: 'E',
        destination: 'R',
        sequence: 7,
        control: const RouteDiscoveryReply('A', ['R', 'B', 'C']),
        path: const ['E'],
      );
      final outcome = h.relay.decide(reply);
      expect(outcome, isA<RelayQueued>());
      expect((outcome as RelayQueued).forwards.single.to, 'B');
    });

    test('drops unicast without a route', () {
      final h = RelayHarness(localNodeId: 'A', liveNeighbors: const []);
      final packet = _packet();
      final outcome = h.relay.decide(packet, origin: true);
      expect(outcome, isA<RelayDropped>());
      expect((outcome as RelayDropped).reason, RelayDropReason.noRoute);
    });
  });
}
