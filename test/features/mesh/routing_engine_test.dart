import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/mesh/domain/mesh_clock.dart';
import 'package:onebit/features/mesh/domain/mesh_packet.dart';
import 'package:onebit/features/mesh/neighbor/neighbor_table.dart';
import 'package:onebit/features/mesh/routing/packet_factory.dart';
import 'package:onebit/features/mesh/routing/route_optimizer.dart';
import 'package:onebit/features/mesh/routing/route_table.dart';
import 'package:onebit/features/mesh/routing/routing_engine.dart';

void main() {
  group('RoutingEngine', () {
    late ManualMeshClock clock;
    late NeighborTable peers;
    late RoutingEngine routing;

    void seed({Set<String> neighborIds = const {'B'}}) {
      clock = ManualMeshClock();
      peers = NeighborTable();
      for (final id in neighborIds) {
        peers.upsertAdvertisement(id, -55, clock.now());
      }
      routing = RoutingEngine(
        localNodeId: 'A',
        now: clock.now,
        table: RouteTable(time: clock.now),
        optimizer: RouteOptimizer(),
        factory: MeshPacketFactory(localNodeId: 'A', now: clock.now),
        neighborOf: peers.byId,
      );
    }

    test('offerDirect installs a one-hop route for a live neighbor', () {
      seed();
      routing.offerDirect('B');
      final route = routing.route('B');
      expect(route, isNotNull);
      expect(route!.hopCount, 1);
      expect(route.nextHop, 'B');
    });

    test('discover returns a broadcast request targeting the target', () {
      seed();
      final request = routing.discover('Z');
      expect(request, isNotNull);
      expect(request!.isBroadcast, isTrue);
      expect(request.control, isA<RouteDiscoveryRequest>());
      expect((request.control! as RouteDiscoveryRequest).target, 'Z');
      expect(request.source, 'A');
    });

    test('a discovery request answered locally produces a reply', () {
      seed(neighborIds: {'B'});
      final request = MeshPacket(
        source: 'B',
        destination: '',
        kind: MeshPacketKind.control,
        control: const RouteDiscoveryRequest('A'),
        ttl: 8,
        sequence: 5,
        path: const ['B'],
      );
      final reply = routing.ingestControl(request, 'B');
      expect(reply, isNotNull);
      expect(reply!.control, isA<RouteDiscoveryReply>());
      final replyControl = reply.control! as RouteDiscoveryReply;
      expect(replyControl.target, 'A');
      expect(replyControl.path, contains('B'));
      expect(routing.route('B'), isNotNull);
    });

    test('a request for another node only learns the reverse route', () {
      seed(neighborIds: {'B'});
      final request = MeshPacket(
        source: 'B',
        destination: '',
        kind: MeshPacketKind.control,
        control: const RouteDiscoveryRequest('X'),
        ttl: 8,
        sequence: 5,
        path: const ['B'],
      );
      expect(routing.ingestControl(request, 'B'), isNull);
      expect(routing.route('B'), isNotNull);
    });

    test('learnRouteFromPacket builds a route to the packet source', () {
      seed(neighborIds: {'B'});
      routing.learnRouteFromPacket(
        MeshPacket(
          source: 'X',
          destination: 'Q',
          kind: MeshPacketKind.data,
          ttl: 8,
          sequence: 1,
          hopCount: 1,
          path: const ['X', 'B'],
        ),
        'B',
      );
      final route = routing.route('X');
      expect(route, isNotNull);
      expect(route!.nextHop, 'B');
      expect(route.hopCount, 2);
    });

    test('nextHopForControl follows the recorded reply path', () {
      seed(neighborIds: {'B', 'C'});
      final reply = MeshPacket(
        source: 'E',
        destination: 'Q',
        kind: MeshPacketKind.control,
        control: const RouteDiscoveryReply('E', ['Q', 'A', 'B']),
        ttl: 8,
        sequence: 7,
        path: const ['E', 'F'],
      );
      expect(routing.nextHopForControl(reply), 'Q');
    });

    test('nextHopForControl is null at the requester', () {
      seed();
      final reply = MeshPacket(
        source: 'E',
        destination: 'A',
        kind: MeshPacketKind.control,
        control: const RouteDiscoveryReply('E', ['A']),
        ttl: 8,
        sequence: 7,
      );
      expect(routing.nextHopForControl(reply), isNull);
    });

    test('neighborLost dissolves routes through the departed hop', () {
      seed(neighborIds: {'B', 'C'});
      routing.offerDirect('B');
      routing.learnRouteFromPacket(
        MeshPacket(
          source: 'X',
          destination: 'Q',
          kind: MeshPacketKind.data,
          ttl: 8,
          sequence: 1,
          hopCount: 1,
          path: const ['X', 'B'],
        ),
        'B',
      );
      expect(routing.route('X')!.nextHop, 'B');

      final affected = routing.neighborLost('B');
      expect(affected, contains('X'));
      expect(routing.route('X'), isNull);
    });

    test('relayFailed demotes and expire drops stale routes', () {
      seed(neighborIds: {'B', 'C'});
      routing.offerDirect('B');
      routing.offerDirect('C');

      // Progress-clock is manual; route freshness uses the same clock.
      expect(routing.route('B'), isNotNull);
      expect(routing.relayFailed('B'), isTrue);

      clock.advance(const Duration(minutes: 6));
      final lost = routing.expire(clock.now(), const Duration(minutes: 5));
      expect(lost, contains('B'));
      expect(routing.route('B'), isNull);
    });
  });
}
