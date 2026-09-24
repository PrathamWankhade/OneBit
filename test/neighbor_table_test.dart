import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/peer_registry/peer_connection_manager.dart';
import 'package:onebit/features/peer_registry/peer_lifecycle_state.dart';
import 'package:onebit/features/routing/neighbor_entry.dart';
import 'package:onebit/features/routing/neighbor_table.dart';

import 'neighbor_table_test.mocks.dart';

@GenerateMocks([PeerConnectionManager])
void main() {
  const peerA = 'aa11111111111111111111111111111111111111111111111111111111111111';
  const peerB = 'bb22222222222222222222222222222222222222222222222222222222222222';
  const peerC = 'cc33333333333333333333333333333333333333333333333333333333333333';
  const deviceA = 'AA:BB:CC:DD:01';
  const deviceB = 'AA:BB:CC:DD:02';

  PeerConnectionRecord connected(String peerId, String deviceId) {
    return PeerConnectionRecord(
      peerIdentityId: peerId,
      deviceId: deviceId,
      lifecycleState: PeerLifecycleState.connected,
      connectionState: BleConnectionState.connected,
    );
  }

  PeerConnectionRecord disconnected(String peerId) {
    return PeerConnectionRecord(
      peerIdentityId: peerId,
      deviceId: null,
      lifecycleState: PeerLifecycleState.disconnected,
      connectionState: BleConnectionState.disconnected,
    );
  }

  group('I8.2 NeighborEntry', () {
    test('active entry properties', () {
      final entry = NeighborEntry(
        peerId: peerA,
        state: NeighborState.active,
        addedAt: DateTime(2025),
        lastUpdatedAt: DateTime(2025),
      );
      expect(entry.isActive, true);
      expect(entry.isStale, false);
    });

    test('stale entry properties', () {
      final entry = NeighborEntry(
        peerId: peerA,
        state: NeighborState.stale,
        addedAt: DateTime(2025),
        lastUpdatedAt: DateTime(2025),
      );
      expect(entry.isActive, false);
      expect(entry.isStale, true);
    });

    test('copyWith preserves peerId', () {
      final entry = NeighborEntry(
        peerId: peerA,
        state: NeighborState.active,
        addedAt: DateTime(2025),
        lastUpdatedAt: DateTime(2025),
      );
      final updated = entry.copyWith(state: NeighborState.stale);
      expect(updated.peerId, peerA);
      expect(updated.state, NeighborState.stale);
    });

    test('equality by peerId and state', () {
      final a = NeighborEntry(
        peerId: peerA,
        state: NeighborState.active,
        addedAt: DateTime(2025),
        lastUpdatedAt: DateTime(2025),
      );
      final b = NeighborEntry(
        peerId: peerA,
        state: NeighborState.active,
        addedAt: DateTime(2026),
        lastUpdatedAt: DateTime(2026),
      );
      expect(a, equals(b));
    });

    test('inequality for different state', () {
      final a = NeighborEntry(
        peerId: peerA,
        state: NeighborState.active,
        addedAt: DateTime(2025),
        lastUpdatedAt: DateTime(2025),
      );
      final b = NeighborEntry(
        peerId: peerA,
        state: NeighborState.stale,
        addedAt: DateTime(2025),
        lastUpdatedAt: DateTime(2025),
      );
      expect(a, isNot(equals(b)));
    });

    test('generation tracking', () {
      final entry = NeighborEntry(
        peerId: peerA,
        state: NeighborState.active,
        addedAt: DateTime(2025),
        lastUpdatedAt: DateTime(2025),
        generation: 3,
      );
      expect(entry.generation, 3);
    });
  });

  group('I8.2 NeighborTable — Empty State', () {
    late MockPeerConnectionManager connectionManager;
    late NeighborTable table;

    setUp(() {
      connectionManager = MockPeerConnectionManager();

      when(connectionManager.connectionStream)
          .thenAnswer((_) => const Stream.empty());
      when(connectionManager.connections).thenReturn([]);

      table = NeighborTable(
        connectionManager: connectionManager,
      );
    });

    tearDown(() {
      table.dispose();
    });

    test('starts empty', () {
      table.initialize();
      expect(table.count, 0);
      expect(table.hasNeighbors, false);
      expect(table.neighbors, isEmpty);
      expect(table.allEntries, isEmpty);
    });

    test('isNeighbor returns false for unknown peer', () {
      table.initialize();
      expect(table.isNeighbor(peerA), false);
    });

    test('getNeighbor returns null for unknown peer', () {
      table.initialize();
      expect(table.getNeighbor(peerA), isNull);
    });

    test('neighborPeerIds is empty', () {
      table.initialize();
      expect(table.neighborPeerIds, isEmpty);
    });
  });

  group('I8.2 NeighborTable — Manual Add/Remove', () {
    late MockPeerConnectionManager connectionManager;
    late NeighborTable table;

    setUp(() {
      connectionManager = MockPeerConnectionManager();

      when(connectionManager.connectionStream)
          .thenAnswer((_) => const Stream.empty());
      when(connectionManager.connections).thenReturn([]);

      table = NeighborTable(
        connectionManager: connectionManager,
      );
      table.initialize();
    });

    tearDown(() {
      table.dispose();
    });

    test('addNeighbor adds a neighbor', () {
      table.addNeighbor(peerA);
      expect(table.count, 1);
      expect(table.isNeighbor(peerA), true);
      expect(table.neighborPeerIds, contains(peerA));
    });

    test('addNeighbor prevents duplicates', () {
      table.addNeighbor(peerA);
      table.addNeighbor(peerA);
      table.addNeighbor(peerA);
      expect(table.count, 1);
    });

    test('addNeighbor supports multiple peers', () {
      table.addNeighbor(peerA);
      table.addNeighbor(peerB);
      table.addNeighbor(peerC);
      expect(table.count, 3);
      expect(table.neighborPeerIds, containsAll([peerA, peerB, peerC]));
    });

    test('removeNeighbor removes an active neighbor', () {
      table.addNeighbor(peerA);
      table.addNeighbor(peerB);

      table.removeNeighbor(peerA);

      expect(table.count, 1);
      expect(table.isNeighbor(peerA), false);
      expect(table.isNeighbor(peerB), true);
    });

    test('removeNeighbor is idempotent for unknown peer', () {
      table.removeNeighbor(peerA); // should not throw
      expect(table.count, 0);
    });

    test('removeNeighbor marks as stale, not immediately removed', () {
      table.addNeighbor(peerA);
      table.removeNeighbor(peerA);

      // Entry exists as stale.
      expect(table.isNeighbor(peerA), false);
      expect(table.allEntries.length, 1);
      expect(table.allEntries.first.isStale, true);
    });

    test('forceRemoveNeighbor completely removes entry', () {
      table.addNeighbor(peerA);
      table.forceRemoveNeighbor(peerA);

      expect(table.count, 0);
      expect(table.allEntries, isEmpty);
      expect(table.getNeighbor(peerA), isNull);
    });
  });

  group('I8.2 NeighborTable — Peer Isolation', () {
    late MockPeerConnectionManager connectionManager;
    late NeighborTable table;

    setUp(() {
      connectionManager = MockPeerConnectionManager();

      when(connectionManager.connectionStream)
          .thenAnswer((_) => const Stream.empty());
      when(connectionManager.connections).thenReturn([]);

      table = NeighborTable(
        connectionManager: connectionManager,
      );
      table.initialize();
    });

    tearDown(() {
      table.dispose();
    });

    test('adding C does not modify A or B', () {
      table.addNeighbor(peerA);
      table.addNeighbor(peerB);

      table.addNeighbor(peerC);

      expect(table.isNeighbor(peerA), true);
      expect(table.isNeighbor(peerB), true);
      expect(table.isNeighbor(peerC), true);
    });

    test('removing A does not modify B or C', () {
      table.addNeighbor(peerA);
      table.addNeighbor(peerB);
      table.addNeighbor(peerC);

      table.removeNeighbor(peerA);

      expect(table.isNeighbor(peerA), false);
      expect(table.isNeighbor(peerB), true);
      expect(table.isNeighbor(peerC), true);
    });

    test('clear removes all neighbors', () {
      table.addNeighbor(peerA);
      table.addNeighbor(peerB);

      table.clear();

      expect(table.count, 0);
      expect(table.hasNeighbors, false);
    });
  });

  group('I8.2 NeighborTable — Reconnection', () {
    late MockPeerConnectionManager connectionManager;
    late NeighborTable table;

    setUp(() {
      connectionManager = MockPeerConnectionManager();

      when(connectionManager.connectionStream)
          .thenAnswer((_) => const Stream.empty());
      when(connectionManager.connections).thenReturn([]);

      table = NeighborTable(
        connectionManager: connectionManager,
      );
      table.initialize();
    });

    tearDown(() {
      table.dispose();
    });

    test('connect → disconnect → reconnect produces one entry', () {
      // Connect.
      table.addNeighbor(peerA);
      expect(table.count, 1);

      // Disconnect.
      table.removeNeighbor(peerA);
      expect(table.isNeighbor(peerA), false);

      // Reconnect.
      table.addNeighbor(peerA);
      expect(table.count, 1);
      expect(table.isNeighbor(peerA), true);

      // Verify exactly one entry.
      final entries = table.allEntries.where((e) => e.peerId == peerA);
      expect(entries.length, 1);
    });

    test('stale callback cannot remove active neighbor', () {
      // Add with generation 2.
      table.addNeighbor(peerA, generation: 2);

      // Try to remove with older generation.
      final removed = table.removeNeighborIfCurrentGeneration(peerA, 1);
      expect(removed, false);
      expect(table.isNeighbor(peerA), true);
    });

    test('current generation callback can remove neighbor', () {
      table.addNeighbor(peerA, generation: 2);

      final removed = table.removeNeighborIfCurrentGeneration(peerA, 2);
      expect(removed, true);
      expect(table.isNeighbor(peerA), false);
    });

    test('newer generation callback can remove neighbor', () {
      table.addNeighbor(peerA, generation: 2);

      final removed = table.removeNeighborIfCurrentGeneration(peerA, 3);
      expect(removed, true);
      expect(table.isNeighbor(peerA), false);
    });
  });

  group('I8.2 NeighborTable — Connection State Sync', () {
    late MockPeerConnectionManager connectionManager;
    late NeighborTable table;
    late StreamController<List<PeerConnectionRecord>> connectionController;

    setUp(() {
      connectionManager = MockPeerConnectionManager();
      connectionController =
          StreamController<List<PeerConnectionRecord>>.broadcast();

      when(connectionManager.connectionStream)
          .thenAnswer((_) => connectionController.stream);
      when(connectionManager.connections).thenReturn([]);

      table = NeighborTable(
        connectionManager: connectionManager,
      );
    });

    tearDown(() async {
      await connectionController.close();
      table.dispose();
    });

    test('syncs neighbors from initial connections', () {
      when(connectionManager.connections).thenReturn([
        connected(peerA, deviceA),
        connected(peerB, deviceB),
      ]);

      table.initialize();

      expect(table.count, 2);
      expect(table.isNeighbor(peerA), true);
      expect(table.isNeighbor(peerB), true);
    });

    test('adds neighbor when connection stream emits connected', () async {
      table.initialize();
      expect(table.count, 0);

      connectionController.add([
        connected(peerA, deviceA),
      ]);

      await Future<void>.delayed(Duration.zero);

      expect(table.count, 1);
      expect(table.isNeighbor(peerA), true);
    });

    test('removes neighbor when connection stream emits disconnected', () async {
      when(connectionManager.connections).thenReturn([
        connected(peerA, deviceA),
      ]);

      table.initialize();
      expect(table.count, 1);

      connectionController.add([
        disconnected(peerA),
      ]);

      await Future<void>.delayed(Duration.zero);

      expect(table.isNeighbor(peerA), false);
      expect(table.count, 0);
    });

    test('multiple peers tracked independently', () async {
      table.initialize();

      connectionController.add([
        connected(peerA, deviceA),
        connected(peerB, deviceB),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(table.count, 2);

      connectionController.add([
        connected(peerA, deviceA),
        disconnected(peerB),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(table.count, 1);
      expect(table.isNeighbor(peerA), true);
      expect(table.isNeighbor(peerB), false);
    });

    test('reconnection from stream produces single entry', () async {
      table.initialize();

      // Connect.
      connectionController.add([connected(peerA, deviceA)]);
      await Future<void>.delayed(Duration.zero);
      expect(table.count, 1);

      // Disconnect.
      connectionController.add([disconnected(peerA)]);
      await Future<void>.delayed(Duration.zero);
      expect(table.count, 0);

      // Reconnect.
      connectionController.add([connected(peerA, deviceA)]);
      await Future<void>.delayed(Duration.zero);
      expect(table.count, 1);
      expect(table.isNeighbor(peerA), true);
    });
  });

  group('I8.2 NeighborTable — Topology Integration', () {
    late MockPeerConnectionManager connectionManager;
    late NeighborTable table;

    setUp(() {
      connectionManager = MockPeerConnectionManager();

      when(connectionManager.connectionStream)
          .thenAnswer((_) => const Stream.empty());
      when(connectionManager.connections).thenReturn([]);

      table = NeighborTable(
        connectionManager: connectionManager,
      );
      table.initialize();
    });

    tearDown(() {
      table.dispose();
    });

    test('buildTopologySnapshot includes local node', () {
      final snapshot = table.buildTopologySnapshot(
        localPeerId: peerA,
        localDisplayName: 'Local A',
      );

      expect(snapshot.localNode, isNotNull);
      expect(snapshot.localNode!.peerId, peerA);
      expect(snapshot.localNode!.isLocal, true);
      expect(snapshot.localNode!.displayName, 'Local A');
    });

    test('buildTopologySnapshot includes active neighbors', () {
      table.addNeighbor(peerB);
      table.addNeighbor(peerC);

      final snapshot = table.buildTopologySnapshot(
        localPeerId: peerA,
      );

      expect(snapshot.neighborCount, 2);
      expect(snapshot.isNeighbor(peerB), true);
      expect(snapshot.isNeighbor(peerC), true);
    });

    test('buildTopologySnapshot excludes stale neighbors', () {
      table.addNeighbor(peerB);
      table.removeNeighbor(peerB);

      final snapshot = table.buildTopologySnapshot(
        localPeerId: peerA,
      );

      expect(snapshot.neighborCount, 0);
    });

    test('buildTopologySnapshot nodes include local and neighbors', () {
      table.addNeighbor(peerB);

      final snapshot = table.buildTopologySnapshot(
        localPeerId: peerA,
      );

      expect(snapshot.nodeCount, 2); // local + B
      expect(snapshot.allPeerIds, containsAll([peerA, peerB]));
    });
  });

  group('I8.2 NeighborTable — Stream Notifications', () {
    late MockPeerConnectionManager connectionManager;
    late NeighborTable table;

    setUp(() {
      connectionManager = MockPeerConnectionManager();

      when(connectionManager.connectionStream)
          .thenAnswer((_) => const Stream.empty());
      when(connectionManager.connections).thenReturn([]);

      table = NeighborTable(
        connectionManager: connectionManager,
      );
      table.initialize();
    });

    tearDown(() {
      table.dispose();
    });

    test('emits on addNeighbor', () async {
      final emissions = <List<NeighborEntry>>[];
      table.neighborStream.listen(emissions.add);

      table.addNeighbor(peerA);
      // Allow stream to emit.
      await Future<void>.delayed(Duration.zero);

      expect(emissions.length, 1);
      expect(emissions.first.length, 1);
      expect(emissions.first.first.peerId, peerA);
    });

    test('emits on removeNeighbor', () async {
      table.addNeighbor(peerA);

      final emissions = <List<NeighborEntry>>[];
      table.neighborStream.listen(emissions.add);

      table.removeNeighbor(peerA);
      await Future<void>.delayed(Duration.zero);

      expect(emissions.length, 1);
      expect(emissions.first, isEmpty);
    });
  });
}
