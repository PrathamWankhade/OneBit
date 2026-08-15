import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/mesh/data/mesh_gatt_constants.dart';
import 'package:onebit/features/mesh/domain/mesh_clock.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_events.dart';
import 'package:onebit/features/mesh/domain/mesh_transport.dart';
import 'package:onebit/features/mesh/metrics/rssi_history.dart';
import 'package:onebit/features/mesh/neighbor/neighbor_discovery_engine.dart';
import 'package:onebit/features/mesh/neighbor/neighbor_table.dart';

void main() {
  group('NeighborTable', () {
    test('tracks identity, EMA smoothing and connection state', () {
      final table = NeighborTable();
      final t0 = DateTime.utc(2026);
      final first = table.upsertAdvertisement('B', -50, t0);
      expect(first.isNew, isTrue);
      expect(first.entry.smoothedRssiDb, -50.0);
      expect(first.entry.connectionState, MeshLinkState.advertising);

      final second = table.upsertAdvertisement(
        'B',
        -70,
        t0.add(const Duration(seconds: 30)),
      );
      expect(second.isNew, isFalse);
      expect(
        second.entry.smoothedRssiDb,
        closeTo(-50 * 0.7 + -70 * 0.3, 0.0001),
      );
      expect(second.entry.firstSeen, t0);
      expect(second.entry.lastSeen, t0.add(const Duration(seconds: 30)));
    });

    test('touchRssi marks a connected link', () {
      final table = NeighborTable();
      table.upsertAdvertisement('B', -60, DateTime.utc(2026));
      final updated = table.touchRssi(
        'B',
        -55,
        DateTime.utc(2026).add(const Duration(seconds: 1)),
      );
      expect(updated, isNotNull);
      expect(updated!.connectionState, MeshLinkState.connected);
    });

    test('expire removes stale entries only', () {
      final table = NeighborTable();
      final t0 = DateTime.utc(2026);
      table.upsertAdvertisement('B', -60, t0);
      table.upsertAdvertisement('C', -60, t0.add(const Duration(seconds: 1)));
      final removed = table.expire(
        t0.add(const Duration(seconds: 91)),
        const Duration(seconds: 90),
      );
      expect(removed, ['B']);
      expect(table.byId('C'), isNotNull);
    });

    test('remove returns and drops an entry', () {
      final table = NeighborTable();
      table.upsertAdvertisement('B', -60, DateTime.utc(2026));
      final removed = table.remove('B');
      expect(removed, isNotNull);
      expect(table.byId('B'), isNull);
    });
  });

  group('NeighborDiscoveryEngine', () {
    test('turns advertisements and link changes into neighbor state', () {
      final discovery = NeighborDiscoveryEngine(
        table: NeighborTable(),
        neighborTtl: const Duration(seconds: 90),
      );
      final now = DateTime.utc(2026);
      final seen = discovery.handle(
        NeighborAdvertisementSeen(nodeId: 'B', rssiDb: -55, timestamp: now),
      );
      expect(seen, isTrue);
      expect(discovery.neighbor('B'), isNotNull);
      final refreshed = discovery.handle(
        NeighborAdvertisementSeen(nodeId: 'B', rssiDb: -55, timestamp: now),
      );
      expect(refreshed, isFalse);

      discovery.handle(
        const LinkStateChanged(nodeId: 'B', state: MeshLinkState.connected),
      );
      expect(discovery.neighbor('B')!.connectionState, MeshLinkState.connected);
    });

    test('sweep expires stale neighbors and reports them as left', () {
      final clock = ManualMeshClock();
      final discovery = NeighborDiscoveryEngine(
        table: NeighborTable(),
        neighborTtl: const Duration(seconds: 90),
      );
      var leftEvent = 0;
      discovery.events
          .where((e) => e is MeshNeighborLeft)
          .listen((_) => leftEvent++);
      discovery.handle(
        NeighborAdvertisementSeen(
          nodeId: 'B',
          rssiDb: -55,
          timestamp: clock.now(),
        ),
      );
      clock.advance(const Duration(seconds: 95));
      final removed = discovery.sweep(clock.now());
      expect(removed, ['B']);
      // Async stream delivery flushes the count:
      return Future<void>.delayed(Duration.zero).then((_) {
        expect(leftEvent, 1);
      });
    });

    test('carries advertised capabilities into the neighbor table', () {
      final discovery = NeighborDiscoveryEngine(
        table: NeighborTable(),
        neighborTtl: const Duration(seconds: 90),
      );
      final now = DateTime.utc(2026);
      const storeForwardAdvert = MeshAdvertisement(
        serviceUuids: [
          MeshGattConstants.meshServiceUuid,
          MeshGattConstants.storeForwardServiceUuid,
        ],
        capabilities: {
          MeshCapability.relay,
          MeshCapability.router,
          MeshCapability.storeForward,
        },
      );
      discovery.handle(
        NeighborAdvertisementSeen(
          nodeId: 'B',
          rssiDb: -50,
          timestamp: now,
          advertisement: storeForwardAdvert,
        ),
      );
      final neighbor = discovery.neighbor('B');
      expect(neighbor, isNotNull);
      expect(neighbor!.capabilities, contains(MeshCapability.storeForward));

      // Without an advertised capability set the default applies.
      discovery.handle(
        NeighborAdvertisementSeen(nodeId: 'C', rssiDb: -55, timestamp: now),
      );
      final plain = discovery.neighbor('C');
      expect(
        plain!.capabilities,
        containsAll({MeshCapability.relay, MeshCapability.router}),
      );
      expect(plain.capabilities, isNot(contains(MeshCapability.storeForward)));
    });
  });

  group('MeshRssiHistory', () {
    test('caps per-node samples and drops stale series', () {
      final history = MeshRssiHistory(perNodeCapacity: 3);
      final t = DateTime.utc(2026);
      for (var i = 0; i < 10; i++) {
        history.record('B', -50 - i, t.add(Duration(seconds: i)));
      }
      expect(history.forNode('B'), hasLength(3));
      expect(history.average('B'), isNotNull);
      history.prune(t.add(const Duration(minutes: 1)));
      expect(history.trackedNodes, 0);
    });

    test('average returns null without samples', () {
      final history = MeshRssiHistory();
      expect(history.average('missing'), isNull);
    });
  });
}
