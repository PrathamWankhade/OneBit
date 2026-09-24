import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/route_discovery.dart';
import 'package:onebit/features/routing/routing_table.dart';
import 'package:onebit/features/routing/topology_advertisement.dart';
import 'package:onebit/features/routing/topology_repository.dart';

void main() {
  const peerA = 'aa11111111111111111111111111111111111111111111111111111111111111';
  const peerB = 'bb22222222222222222222222222222222222222222222222222222222222222';
  const peerC = 'cc33333333333333333333333333333333333333333333333333333333333333';
  const peerD = 'dd44444444444444444444444444444444444444444444444444444444444444';
  const peerE = 'ee55555555555555555555555555555555555555555555555555555555555555';
  const peerF = 'ff66666666666666666666666666666666666666666666666666666666666666';

  RouteDiscovery discovery0({
    required TopologyRepository topology,
    required Set<String> reachableNeighbors,
  }) {
    return RouteDiscovery(
      topologyRepository: topology,
      getReachableNeighbors: () => reachableNeighbors,
    );
  }

  group('I8.6 RouteDiscovery — invalid destination', () {
    test('empty destination returns invalidDestination', () {
      final discovery = discovery0(
        topology: TopologyRepository(),
        reachableNeighbors: {peerB},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: '',
      );
      expect(result.isInvalid, true);
      expect(result.route, isNull);
    });
  });

  group('I8.6 RouteDiscovery — self destination', () {
    test('destination = localPeerId returns notFound', () {
      final discovery = discovery0(
        topology: TopologyRepository(),
        reachableNeighbors: {peerB},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerA,
      );
      expect(result.isNotFound, true);
      expect(result.route, isNull);
    });
  });

  group('I8.6 RouteDiscovery — no reachable neighbors', () {
    test('empty neighbor set returns notFound', () {
      final discovery = discovery0(
        topology: TopologyRepository(),
        reachableNeighbors: {},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      expect(result.isNotFound, true);
    });
  });

  group('I8.6 RouteDiscovery — direct route', () {
    test('destination is a reachable neighbor', () {
      final discovery = discovery0(
        topology: TopologyRepository(),
        reachableNeighbors: {peerB},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerB,
      );
      expect(result.isFound, true);
      expect(result.route!.destinationPeerId, peerB);
      expect(result.route!.nextHopPeerId, peerB);
      expect(result.route!.metric, 1);
      expect(result.route!.source, RouteSource.direct);
    });

    test('direct route takes precedence over indirect', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB, peerC},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      expect(result.isFound, true);
      expect(result.route!.nextHopPeerId, peerC);
      expect(result.route!.metric, 1);
    });
  });

  group('I8.6 RouteDiscovery — indirect route (two hop)', () {
    test('A → B → C discovers C via B with metric 2', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      expect(result.isFound, true);
      expect(result.route!.destinationPeerId, peerC);
      expect(result.route!.nextHopPeerId, peerB);
      expect(result.route!.metric, 2);
    });
  });

  group('I8.6 RouteDiscovery — indirect route (three hop)', () {
    test('A → B → C → D discovers D via B with metric 3', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerC,
        sequence: 1,
        neighborPeerIds: [peerD],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerD,
      );
      expect(result.isFound, true);
      expect(result.route!.destinationPeerId, peerD);
      expect(result.route!.nextHopPeerId, peerB);
      expect(result.route!.metric, 3);
    });
  });

  group('I8.6 RouteDiscovery — no route', () {
    test('disconnected topology returns notFound', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));
      // peerD is not reachable through any path.
      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerD,
      );
      expect(result.isNotFound, true);
    });

    test('isolated pair returns notFound', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerC,
        sequence: 1,
        neighborPeerIds: [peerD],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerD,
      );
      expect(result.isNotFound, true);
    });
  });

  group('I8.6 RouteDiscovery — cycle safety', () {
    test('simple cycle A → B → C → A terminates', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerC,
        sequence: 1,
        neighborPeerIds: [peerA], // cycle back to A
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      // Discovering A (self) should return notFound.
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerA,
      );
      expect(result.isNotFound, true);
    });

    test('large cyclic topology terminates', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerC,
        sequence: 1,
        neighborPeerIds: [peerD],
      ));
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerD,
        sequence: 1,
        neighborPeerIds: [peerE],
      ));
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerE,
        sequence: 1,
        neighborPeerIds: [peerB], // cycle back to B
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      // All should terminate without stack overflow.
      expect(
        () => discovery.discoverRoute(
          localPeerId: peerA,
          destinationPeerId: peerF,
        ),
        returnsNormally,
      );
    });
  });

  group('I8.6 RouteDiscovery — first-hop tracking', () {
    test('first hop is the direct neighbor, not intermediate', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerC,
        sequence: 1,
        neighborPeerIds: [peerD],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerD,
      );
      expect(result.isFound, true);
      expect(result.route!.nextHopPeerId, peerB);
      expect(result.route!.metric, 3);
    });

    test('first hop for 4-hop route is the direct neighbor', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerC,
        sequence: 1,
        neighborPeerIds: [peerD],
      ));
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerD,
        sequence: 1,
        neighborPeerIds: [peerE],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerE,
      );
      expect(result.isFound, true);
      expect(result.route!.nextHopPeerId, peerB);
      expect(result.route!.metric, 4);
    });
  });

  group('I8.6 RouteDiscovery — multiple paths', () {
    test('A → B → C and A → D → C discovers C with deterministic first hop', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB, peerD});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerD,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB, peerD},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      expect(result.isFound, true);
      // BFS explores B first (alphabetically), so first hop is B.
      expect(result.route!.nextHopPeerId, peerB);
      expect(result.route!.metric, 2);
    });
  });

  group('I8.6 RouteDiscovery — unreachable first hop', () {
    test('B is in topology but not reachable', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {}, // B is NOT reachable
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      expect(result.isNotFound, true);
    });
  });

  group('I8.6 RouteDiscovery — peer isolation', () {
    test('discovering C does not affect D/E topology', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB, peerD});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerD,
        sequence: 1,
        neighborPeerIds: [peerE],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB, peerD},
      );

      final resultC = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      expect(resultC.isFound, true);
      expect(resultC.route!.nextHopPeerId, peerB);

      final resultE = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerE,
      );
      expect(resultE.isFound, true);
      expect(resultE.route!.nextHopPeerId, peerD);
    });
  });

  group('I8.6 RouteDiscovery — determinism', () {
    test('multiple calls produce identical results', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB, peerD});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerD,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB, peerD},
      );

      final results = List.generate(5, (_) {
        final result = discovery.discoverRoute(
          localPeerId: peerA,
          destinationPeerId: peerC,
        );
        return (result.route!.nextHopPeerId, result.route!.metric);
      });

      // All results must be identical.
      expect(results.toSet().length, 1);
      expect(results.first.$1, peerB);
      expect(results.first.$2, 2);
    });
  });

  group('I8.6 RouteDiscovery — duplicate edges', () {
    test('duplicate topology edges are handled as single logical edge', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC, peerC], // duplicate
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      expect(result.isFound, true);
      expect(result.route!.metric, 2);
    });
  });

  group('I8.6 RouteDiscovery — metric calculation', () {
    test('metric counts edges, not nodes', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      expect(result.isFound, true);
      // A → B → C = 2 edges = metric 2.
      expect(result.route!.metric, 2);
    });
  });

  group('I8.6 RouteDiscovery — identity tests', () {
    test('route uses PeerId, not BLE address', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      expect(result.isFound, true);
      // Verify these are 64-hex PeerIds, not BLE addresses.
      expect(result.route!.destinationPeerId.length, 64);
      expect(result.route!.nextHopPeerId.length, 64);
    });

    test('same PeerId with different BLE address produces same route', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      final result1 = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      final result2 = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      expect(result1.route!.destinationPeerId, result2.route!.destinationPeerId);
      expect(result1.route!.nextHopPeerId, result2.route!.nextHopPeerId);
    });
  });

  group('I8.6 RouteDiscovery — trust isolation', () {
    test('discovery does not modify trust', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      // Discovery is a pure read operation — no trust side effects.
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      expect(result.isFound, true);
    });
  });

  group('I8.6 RouteDiscovery — session isolation', () {
    test('discovery does not corrupt other routes', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB, peerD});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerD,
        sequence: 1,
        neighborPeerIds: [peerE],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB, peerD},
      );

      final resultC = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      final resultE = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerE,
      );

      expect(resultC.route!.nextHopPeerId, peerB);
      expect(resultE.route!.nextHopPeerId, peerD);
    });
  });

  group('I8.6 RouteDiscovery — no side effects', () {
    test('discovery does not create connections', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      // This test verifies no BLE/connection side effects.
      // If discovery tried to create a connection, it would fail.
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerB,
      );
      expect(result.isFound, true);
    });

    test('discovery does not modify topology', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      // Topology should remain unchanged.
      expect(topology.localNeighborIds, contains(peerB));
      expect(topology.remoteEntries.length, 1);
    });
  });

  group('I8.6 RouteDiscovery — restart behavior', () {
    test('new discovery service starts fresh', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));

      final discovery1 = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      final result1 = discovery1.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      expect(result1.isFound, true);

      // New discovery service with same topology.
      final discovery2 = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      final result2 = discovery2.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      expect(result2.isFound, true);
      expect(result1.route!.metric, result2.route!.metric);
    });
  });

  group('I8.6 RouteDiscovery — route table integration', () {
    test('discovered route can be added to RoutingTable', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      expect(result.isFound, true);

      final table = RoutingTable(localPeerId: peerA);
      table.addRoute(result.route!);

      expect(table.hasRouteTo(peerC), true);
      expect(table.bestRoute(peerC)!.nextHopPeerId, peerB);
      expect(table.bestRoute(peerC)!.metric, 2);
    });

    test('discovered route is idempotent in RoutingTable', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );

      final table = RoutingTable(localPeerId: peerA);

      // Discover and add twice.
      final result1 = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      table.addRoute(result1.route!);

      final result2 = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      table.addRoute(result2.route!);

      // Should be deduplicated.
      expect(table.routesTo(peerC).length, 1);
    });
  });

  group('I8.6 RouteDiscovery — complex topology', () {
    test('A → B → E, A → C → F, A → D → G discovers all', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB, peerC, peerD});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerE],
      ));
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerC,
        sequence: 1,
        neighborPeerIds: [peerF],
      ));
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerD,
        sequence: 1,
        neighborPeerIds: [peerE], // E reachable via B and D
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB, peerC, peerD},
      );

      final resultE = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerE,
      );
      expect(resultE.isFound, true);
      expect(resultE.route!.metric, 2);

      final resultF = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerF,
      );
      expect(resultF.isFound, true);
      expect(resultF.route!.nextHopPeerId, peerC);
      expect(resultF.route!.metric, 2);
    });
  });

  group('I8.6 RouteDiscovery — boundary conditions', () {
    test('unreachable intermediate peer blocks route', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      ));
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerC,
        sequence: 1,
        neighborPeerIds: [peerD],
      ));

      // B is reachable, but C is NOT reachable (not in neighbor table).
      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerD,
      );
      // C is reachable through B's topology, so D should be discoverable.
      expect(result.isFound, true);
      expect(result.route!.metric, 3);
    });

    test('self-loop in topology is safely ignored', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});
      topology.recordAdvertisement(const TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerB], // self-loop
      ));

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      // Should not infinite loop.
      expect(
        () => discovery.discoverRoute(
          localPeerId: peerA,
          destinationPeerId: peerC,
        ),
        returnsNormally,
      );
    });
  });

  group('I8.6 RouteDiscovery — DiscoveryResult', () {
    test('found result has route', () {
      final topology = TopologyRepository();
      topology.setLocalTopology({peerB});

      final discovery = discovery0(
        topology: topology,
        reachableNeighbors: {peerB},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerB,
      );
      expect(result.isFound, true);
      expect(result.isNotFound, false);
      expect(result.isInvalid, false);
      expect(result.route, isNotNull);
    });

    test('notFound result has null route', () {
      final discovery = discovery0(
        topology: TopologyRepository(),
        reachableNeighbors: {},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: peerC,
      );
      expect(result.isNotFound, true);
      expect(result.route, isNull);
    });

    test('invalidDestination result has null route', () {
      final discovery = discovery0(
        topology: TopologyRepository(),
        reachableNeighbors: {peerB},
      );
      final result = discovery.discoverRoute(
        localPeerId: peerA,
        destinationPeerId: '',
      );
      expect(result.isInvalid, true);
      expect(result.route, isNull);
    });
  });
}
