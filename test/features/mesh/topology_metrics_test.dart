import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/mesh/domain/mesh_clock.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_neighbor.dart';
import 'package:onebit/features/mesh/domain/mesh_route.dart';
import 'package:onebit/features/mesh/metrics/network_monitor.dart';
import 'package:onebit/features/mesh/statistics/mesh_statistics_tracker.dart';
import 'package:onebit/features/mesh/topology/topology_manager.dart';

void main() {
  group('MeshStatisticsTracker', () {
    test('accumulates counters and forwards work', () {
      final clock = ManualMeshClock();
      final stats = MeshStatisticsTracker(
        now: clock.now,
        rateWindow: const Duration(minutes: 1),
      );
      stats.recordPacketSeen();
      stats.recordForward();
      stats.recordDeliverUp();
      stats.recordNeighborJoin();
      final snapshot = stats.snapshot();
      expect(snapshot.packetsSeen, 1);
      expect(snapshot.packetsForwarded, 1);
      expect(snapshot.packetsDeliveredUp, 1);
      expect(snapshot.neighborJoins, 1);
      expect(snapshot.packetsPerMinute, 1);
    });

    test('rolling windows expire outside the rate window', () {
      final clock = ManualMeshClock();
      final stats = MeshStatisticsTracker(now: clock.now);
      stats.recordForward();
      stats.recordNeighborJoin();
      clock.advance(const Duration(minutes: 2));
      final snapshot = stats.snapshot();
      expect(snapshot.packetsPerMinute, 0);
    });
  });

  group('NetworkMonitor', () {
    test('computes status from the current tables', () {
      final now = DateTime.utc(2026);
      final stats = MeshStatisticsTracker(
        now: () => now,
        rateWindow: const Duration(minutes: 1),
      );
      final neighbors = <MeshNeighbor>[
        MeshNeighbor(
          nodeId: 'B',
          firstSeen: now,
          lastSeen: now,
          latestRssiDb: -50,
          smoothedRssiDb: -50,
          connectionState: MeshLinkState.connected,
        ),
        MeshNeighbor(
          nodeId: 'C',
          firstSeen: now,
          lastSeen: now,
          latestRssiDb: -80,
          smoothedRssiDb: -80,
          connectionState: MeshLinkState.advertising,
        ),
        MeshNeighbor(
          nodeId: 'D',
          firstSeen: now,
          lastSeen: now,
          latestRssiDb: -70,
          smoothedRssiDb: -70,
          connectionState: MeshLinkState.disconnected,
        ),
      ];
      final routes = <MeshRoute>[
        MeshRoute(
          destination: 'X',
          nextHop: 'B',
          hopCount: 1,
          cost: 1,
          quality: 1,
          reliability: 1,
          createdAt: now,
          lastUsed: now,
        ),
        MeshRoute(
          destination: 'Y',
          nextHop: 'C',
          hopCount: 3,
          cost: 3,
          quality: 1,
          reliability: 1,
          createdAt: now,
          lastUsed: now,
        ),
      ];

      final monitor = NetworkMonitor(
        neighbors: () => neighbors,
        primaryRoutes: () => routes,
        engineState: () => MeshEngineState.running,
        statistics: stats.snapshot,
        partitions: () => 1,
      );
      final status = monitor.status(now);
      expect(status.activeNeighborCount, 2);
      expect(status.disconnectedNeighborCount, 1);
      expect(status.averageRssiDb, closeTo(-65, 0.0001));
      expect(status.averageHopCount, 2.0);
      expect(status.partitionCount, 1);
      expect(status.meshStability, 1.0);
      expect(status.packetSuccessRate, isNull);
    });

    test('stability degrades with churn', () {
      final now = DateTime.utc(2026);
      final stats = MeshStatisticsTracker(now: () => now);
      for (var i = 0; i < 8; i++) {
        stats.recordNeighborJoin();
      }
      final monitor = NetworkMonitor(
        neighbors: () => const [],
        primaryRoutes: () => const [],
        engineState: () => MeshEngineState.running,
        statistics: stats.snapshot,
        partitions: () => 0,
      );
      expect(monitor.status(now).meshStability, closeTo(0.5, 0.0001));
    });
  });

  group('TopologyManager', () {
    test('builds a local graph with partitions', () {
      final now = DateTime.utc(2026);
      final neighbors = <MeshNeighbor>[
        MeshNeighbor(
          nodeId: 'B',
          firstSeen: now,
          lastSeen: now,
          latestRssiDb: -50,
          smoothedRssiDb: -50,
          connectionState: MeshLinkState.connected,
        ),
        MeshNeighbor(
          nodeId: 'C',
          firstSeen: now,
          lastSeen: now,
          latestRssiDb: -50,
          smoothedRssiDb: -50,
          connectionState: MeshLinkState.connected,
        ),
      ];
      final routes = <MeshRoute>[
        MeshRoute(
          destination: 'D',
          nextHop: 'B',
          hopCount: 2,
          cost: 2,
          quality: 1,
          reliability: 1,
          createdAt: now,
          lastUsed: now,
        ),
      ];
      final topology = TopologyManager(
        localNodeId: 'A',
        neighbors: () => neighbors,
        primaryRoutes: () => routes,
        now: () => now,
      );
      final snapshot = topology.snapshot();
      expect(snapshot.nodes, hasLength(4));
      expect(snapshot.links, hasLength(3));
      expect(snapshot.partitions, 1);
    });
  });
}
