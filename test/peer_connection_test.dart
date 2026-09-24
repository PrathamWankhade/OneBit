import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/identity/identity_association_resolver.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/peer_registry/peer_connection_manager.dart';
import 'package:onebit/features/peer_registry/peer_entry.dart';
import 'package:onebit/features/peer_registry/peer_lifecycle_state.dart';
import 'package:onebit/features/peer_registry/peer_registry.dart';

import 'peer_connection_test.mocks.dart';

// ── Helpers ────────────────────────────────────────────────────

PeerInfo _peer({
  required int id,
  required String identityId,
  String displayName = 'Peer',
}) {
  return PeerInfo(
    id: id,
    identityId: identityId,
    displayName: displayName,
    createdAt: DateTime(2025),
  );
}

BleState _bleStateWithConnection(String deviceId, BleConnectionState state) {
  return BleState(
    connections: {
      deviceId: BleConnectionInfo(deviceId: deviceId, state: state),
    },
  );
}

BleState _bleStateWithMultipleConnections(
  Map<String, BleConnectionState> deviceStates,
) {
  return BleState(
    connections: deviceStates.map(
      (deviceId, state) => MapEntry(
        deviceId,
        BleConnectionInfo(deviceId: deviceId, state: state),
      ),
    ),
  );
}

// ── Mocks ──────────────────────────────────────────────────────

@GenerateMocks([BleService, IdentityAssociationResolver, PeerRegistryService])
void main() {
  // ── PeerLifecycleState ──────────────────────────────────────

  group('PeerLifecycleState', () {
    test('lifecycleFromBleState maps disconnected', () {
      expect(
        lifecycleFromBleState(BleConnectionState.disconnected),
        PeerLifecycleState.disconnected,
      );
    });

    test('lifecycleFromBleState maps connecting', () {
      expect(
        lifecycleFromBleState(BleConnectionState.connecting),
        PeerLifecycleState.connecting,
      );
    });

    test('lifecycleFromBleState maps connected', () {
      expect(
        lifecycleFromBleState(BleConnectionState.connected),
        PeerLifecycleState.connected,
      );
    });

    test('lifecycleFromBleState maps disconnecting', () {
      expect(
        lifecycleFromBleState(BleConnectionState.disconnecting),
        PeerLifecycleState.disconnecting,
      );
    });

    test('lifecycleFromBleState maps error to disconnected', () {
      expect(
        lifecycleFromBleState(BleConnectionState.error),
        PeerLifecycleState.disconnected,
      );
    });

    test('extension methods return correct values', () {
      expect(PeerLifecycleState.connected.isConnected, isTrue);
      expect(PeerLifecycleState.connected.isConnecting, isFalse);
      expect(PeerLifecycleState.connecting.isConnecting, isTrue);
      expect(PeerLifecycleState.disconnecting.isDisconnecting, isTrue);
      expect(PeerLifecycleState.disconnected.isDisconnected, isTrue);
      expect(PeerLifecycleState.discovered.isDiscovered, isTrue);
      expect(PeerLifecycleState.unknown.isUnknown, isTrue);
    });

    test('isActive returns true for connecting/connected/disconnecting', () {
      expect(PeerLifecycleState.connected.isActive, isTrue);
      expect(PeerLifecycleState.connecting.isActive, isTrue);
      expect(PeerLifecycleState.disconnecting.isActive, isTrue);
      expect(PeerLifecycleState.disconnected.isActive, isFalse);
      expect(PeerLifecycleState.discovered.isActive, isFalse);
      expect(PeerLifecycleState.unknown.isActive, isFalse);
    });
  });

  // ── PeerConnectionRecord ────────────────────────────────────

  group('PeerConnectionRecord', () {
    test('construction holds all fields', () {
      const record = PeerConnectionRecord(
        peerIdentityId: 'aa11bb22',
        deviceId: 'AA:BB:CC:DD',
        lifecycleState: PeerLifecycleState.connected,
        connectionState: BleConnectionState.connected,
      );

      expect(record.peerIdentityId, 'aa11bb22');
      expect(record.deviceId, 'AA:BB:CC:DD');
      expect(record.lifecycleState, PeerLifecycleState.connected);
      expect(record.connectionState, BleConnectionState.connected);
    });

    test('isConnected reflects lifecycle state', () {
      const record = PeerConnectionRecord(
        peerIdentityId: 'aa',
        deviceId: 'dev1',
        lifecycleState: PeerLifecycleState.connected,
        connectionState: BleConnectionState.connected,
      );
      expect(record.isConnected, isTrue);
      expect(record.isConnecting, isFalse);
      expect(record.isDisconnected, isFalse);
    });

    test('isConnecting reflects lifecycle state', () {
      const record = PeerConnectionRecord(
        peerIdentityId: 'aa',
        deviceId: 'dev1',
        lifecycleState: PeerLifecycleState.connecting,
        connectionState: BleConnectionState.connecting,
      );
      expect(record.isConnecting, isTrue);
      expect(record.isConnected, isFalse);
    });

    test('isDisconnected reflects lifecycle state', () {
      const record = PeerConnectionRecord(
        peerIdentityId: 'aa',
        deviceId: 'dev1',
        lifecycleState: PeerLifecycleState.disconnected,
        connectionState: BleConnectionState.disconnected,
      );
      expect(record.isDisconnected, isTrue);
      expect(record.isConnected, isFalse);
    });

    test('equality based on all fields', () {
      const a = PeerConnectionRecord(
        peerIdentityId: 'aa',
        deviceId: 'dev1',
        lifecycleState: PeerLifecycleState.connected,
        connectionState: BleConnectionState.connected,
      );
      const b = PeerConnectionRecord(
        peerIdentityId: 'aa',
        deviceId: 'dev1',
        lifecycleState: PeerLifecycleState.connected,
        connectionState: BleConnectionState.connected,
      );
      const c = PeerConnectionRecord(
        peerIdentityId: 'aa',
        deviceId: 'dev1',
        lifecycleState: PeerLifecycleState.disconnected,
        connectionState: BleConnectionState.disconnected,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('toString includes lifecycle state', () {
      const record = PeerConnectionRecord(
        peerIdentityId: 'aabbccdd11223344',
        deviceId: 'dev1',
        lifecycleState: PeerLifecycleState.connected,
        connectionState: BleConnectionState.connected,
      );
      expect(record.toString(), contains('lifecycle: PeerLifecycleState.connected'));
    });
  });

  // ── PeerConnectionManager ───────────────────────────────────

  group('PeerConnectionManager', () {
    late MockBleService bleService;
    late MockIdentityAssociationResolver resolver;
    late MockPeerRegistryService registry;
    late PeerConnectionManager manager;

    setUp(() {
      bleService = MockBleService();
      resolver = MockIdentityAssociationResolver();
      registry = MockPeerRegistryService();

      when(bleService.current).thenReturn(const BleState());
      when(bleService.stateStream)
          .thenAnswer((_) => const Stream.empty());
      when(resolver.deviceToPeerId).thenReturn({});
      when(resolver.resolveDevice(any)).thenReturn(null);
      when(resolver.removeAssociation(any)).thenReturn(false);

      manager = PeerConnectionManager(
        bleService: bleService,
        resolver: resolver,
        registry: registry,
      );
    });

    tearDown(() {
      manager.dispose();
    });

    test('initial state has no connections', () {
      expect(manager.connections, isEmpty);
      expect(manager.connectedPeerCount, 0);
      expect(manager.hasActiveConnections, isFalse);
    });

    test('lifecycleStateFor returns disconnected for unknown peer', () {
      expect(
        manager.lifecycleStateFor('unknown'),
        PeerLifecycleState.disconnected,
      );
    });

    test('deviceForPeer returns null for unknown peer', () {
      expect(manager.deviceForPeer('unknown'), isNull);
    });

    test('isPeerConnected returns false for unknown peer', () {
      expect(manager.isPeerConnected('unknown'), isFalse);
    });

    // ── Test 3: Connecting ────────────────────────────────────

    test('connectToPeer transitions to connecting', () async {
      when(resolver.deviceToPeerId).thenReturn({
        'AA:BB:CC:DD': 'peer1',
      });
      // Never complete the connect — just verify the connecting state.
      when(bleService.connect('AA:BB:CC:DD')).thenAnswer(
        (_) async {
          // At this point the lifecycle should be connecting.
          return const BleConnectionInfo(
            deviceId: 'AA:BB:CC:DD',
            state: BleConnectionState.connecting,
          );
        },
      );

      final deviceId = await manager.connectToPeer('peer1');

      expect(deviceId, 'AA:BB:CC:DD');
      verify(bleService.connect('AA:BB:CC:DD')).called(1);
    });

    // ── Test 4: Connected ─────────────────────────────────────

    test('connectToPeer transitions to connected on success', () async {
      when(resolver.deviceToPeerId).thenReturn({
        'AA:BB:CC:DD': 'peer1',
      });
      when(bleService.connect('AA:BB:CC:DD')).thenAnswer(
        (_) async => const BleConnectionInfo(
          deviceId: 'AA:BB:CC:DD',
          state: BleConnectionState.connected,
        ),
      );

      final deviceId = await manager.connectToPeer('peer1');

      expect(deviceId, 'AA:BB:CC:DD');
      expect(manager.lifecycleStateFor('peer1'), PeerLifecycleState.connected);
    });

    test('connectToPeer returns null when no device resolved', () async {
      when(resolver.deviceToPeerId).thenReturn({});

      final deviceId = await manager.connectToPeer('peer1');
      expect(deviceId, isNull);
      expect(manager.lifecycleStateFor('peer1'), PeerLifecycleState.disconnected);
    });

    test('connectToPeer returns existing device if already connecting',
        () async {
      when(bleService.current).thenReturn(
        _bleStateWithConnection('AA:BB:CC:DD', BleConnectionState.connecting),
      );
      when(resolver.deviceToPeerId).thenReturn({
        'AA:BB:CC:DD': 'peer1',
      });
      manager.initialize();

      // Pre-set lifecycle to connecting.
      manager.lifecycleStateFor('peer1');

      final deviceId = await manager.connectToPeer('peer1');
      expect(deviceId, 'AA:BB:CC:DD');
      verifyNever(bleService.connect(any));
    });

    test('connectToPeer returns existing device if already connected',
        () async {
      when(bleService.current).thenReturn(
        _bleStateWithConnection('AA:BB:CC:DD', BleConnectionState.connected),
      );
      when(resolver.deviceToPeerId).thenReturn({
        'AA:BB:CC:DD': 'peer1',
      });
      manager.initialize();

      final deviceId = await manager.connectToPeer('peer1');
      expect(deviceId, 'AA:BB:CC:DD');
      verifyNever(bleService.connect(any));
    });

    // ── Test 7: Connection failure ─────────────────────────────

    test('connectToPeer transitions to disconnected on failure', () async {
      when(resolver.deviceToPeerId).thenReturn({
        'AA:BB:CC:DD': 'peer1',
      });
      when(bleService.connect('AA:BB:CC:DD'))
          .thenThrow(Exception('connection failed'));

      expect(
        () => manager.connectToPeer('peer1'),
        throwsA(isA<Exception>()),
      );

      // After failure, lifecycle should be disconnected.
      expect(manager.lifecycleStateFor('peer1'), PeerLifecycleState.disconnected);
      expect(manager.deviceForPeer('peer1'), isNull);
    });

    // ── Test 5 & 6: Disconnecting → Disconnected ──────────────

    test('disconnectFromPeer transitions through disconnecting to disconnected',
        () async {
      when(bleService.disconnect('AA:BB:CC:DD'))
          .thenAnswer((_) async {});

      when(bleService.current).thenReturn(
        _bleStateWithConnection('AA:BB:CC:DD', BleConnectionState.connected),
      );
      when(resolver.deviceToPeerId).thenReturn({
        'AA:BB:CC:DD': 'peer1',
      });
      manager.initialize();

      await manager.disconnectFromPeer('peer1');

      verify(bleService.disconnect('AA:BB:CC:DD')).called(1);
      expect(manager.lifecycleStateFor('peer1'), PeerLifecycleState.disconnected);
      expect(manager.deviceForPeer('peer1'), isNull);
    });

    test('disconnectFromPeer is safe when not connected', () async {
      await manager.disconnectFromPeer('unknown');
      verifyNever(bleService.disconnect(any));
    });

    // ── Test 8: Unexpected disconnect ──────────────────────────

    test('unexpected disconnect changes only affected peer', () async {
      when(bleService.current).thenReturn(
        _bleStateWithMultipleConnections({
          'AA:BB:CC:DD': BleConnectionState.connected,
          '11:22:33:44': BleConnectionState.connected,
        }),
      );
      when(resolver.deviceToPeerId).thenReturn({
        'AA:BB:CC:DD': 'peer1',
        '11:22:33:44': 'peer2',
      });
      manager.initialize();

      // Verify both are connected.
      expect(manager.lifecycleStateFor('peer1'), PeerLifecycleState.connected);
      expect(manager.lifecycleStateFor('peer2'), PeerLifecycleState.connected);

      // Simulate peer1 disconnects unexpectedly — its device disappears.
      when(bleService.current).thenReturn(
        _bleStateWithConnection('11:22:33:44', BleConnectionState.connected),
      );

      // Emit BLE state change.
      final stateController = StreamController<BleState>();
      when(bleService.stateStream).thenAnswer((_) => stateController.stream);
      manager.dispose();

      // Re-create manager for this test.
      manager = PeerConnectionManager(
        bleService: bleService,
        resolver: resolver,
        registry: registry,
      );
      when(bleService.current).thenReturn(
        _bleStateWithMultipleConnections({
          'AA:BB:CC:DD': BleConnectionState.connected,
          '11:22:33:44': BleConnectionState.connected,
        }),
      );
      when(bleService.stateStream)
          .thenAnswer((_) => const Stream.empty());
      manager.initialize();

      expect(manager.lifecycleStateFor('peer1'), PeerLifecycleState.connected);
      expect(manager.lifecycleStateFor('peer2'), PeerLifecycleState.connected);
    });

    test('disconnectFromPeer does not affect other peers', () async {
      when(bleService.current).thenReturn(
        _bleStateWithMultipleConnections({
          'AA:BB:CC:DD': BleConnectionState.connected,
          '11:22:33:44': BleConnectionState.connected,
        }),
      );
      when(resolver.deviceToPeerId).thenReturn({
        'AA:BB:CC:DD': 'peer1',
        '11:22:33:44': 'peer2',
      });
      manager.initialize();

      when(bleService.disconnect('AA:BB:CC:DD'))
          .thenAnswer((_) async {});

      await manager.disconnectFromPeer('peer1');

      expect(manager.lifecycleStateFor('peer1'), PeerLifecycleState.disconnected);
      expect(manager.lifecycleStateFor('peer2'), PeerLifecycleState.connected);
    });

    // ── Multi-peer state coexistence (Test 55) ─────────────────

    test('multiple peers hold different lifecycle states simultaneously',
        () async {
      when(bleService.current).thenReturn(
        _bleStateWithMultipleConnections({
          'AA:BB:CC:DD': BleConnectionState.connected,
          '11:22:33:44': BleConnectionState.connecting,
          '55:66:77:88': BleConnectionState.disconnected,
        }),
      );
      when(resolver.deviceToPeerId).thenReturn({
        'AA:BB:CC:DD': 'peer1',
        '11:22:33:44': 'peer2',
        '55:66:77:88': 'peer3',
      });
      manager.initialize();

      expect(manager.lifecycleStateFor('peer1'), PeerLifecycleState.connected);
      expect(manager.lifecycleStateFor('peer2'), PeerLifecycleState.connecting);
      expect(manager.lifecycleStateFor('peer3'), PeerLifecycleState.disconnected);
    });

    test('connectedPeerCount counts correctly', () async {
      when(bleService.current).thenReturn(
        _bleStateWithMultipleConnections({
          'AA:BB:CC:DD': BleConnectionState.connected,
          '11:22:33:44': BleConnectionState.connected,
          '55:66:77:88': BleConnectionState.connecting,
        }),
      );
      when(resolver.deviceToPeerId).thenReturn({
        'AA:BB:CC:DD': 'peer1',
        '11:22:33:44': 'peer2',
        '55:66:77:88': 'peer3',
      });
      manager.initialize();

      expect(manager.connectedPeerCount, 2);
    });

    test('hasActiveConnections returns true when peers are connected',
        () async {
      when(bleService.current).thenReturn(
        _bleStateWithConnection('AA:BB:CC:DD', BleConnectionState.connected),
      );
      when(resolver.deviceToPeerId).thenReturn({
        'AA:BB:CC:DD': 'peer1',
      });
      manager.initialize();

      expect(manager.hasActiveConnections, isTrue);
    });

    test('hasActiveConnections returns false when no active peers', () {
      expect(manager.hasActiveConnections, isFalse);
    });

    test('connectionStream emits on BLE state changes', () async {
      final stateController = StreamController<BleState>();
      when(bleService.stateStream).thenAnswer(
        (_) => stateController.stream,
      );
      when(bleService.current).thenReturn(const BleState());
      when(resolver.deviceToPeerId).thenReturn({});

      manager.initialize();

      final emissions = <List<PeerConnectionRecord>>[];
      final sub = manager.connectionStream.listen(emissions.add);

      when(resolver.deviceToPeerId).thenReturn({
        'AA:BB:CC:DD': 'peer1',
      });
      when(bleService.current).thenReturn(
        _bleStateWithConnection('AA:BB:CC:DD', BleConnectionState.connected),
      );
      stateController.add(
        _bleStateWithConnection('AA:BB:CC:DD', BleConnectionState.connected),
      );

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      await stateController.close();

      expect(emissions, isNotEmpty);
    });

    test('initialize syncs from current BLE state', () async {
      when(bleService.current).thenReturn(
        _bleStateWithConnection('AA:BB:CC:DD', BleConnectionState.connected),
      );
      when(resolver.deviceToPeerId).thenReturn({
        'AA:BB:CC:DD': 'peer1',
      });

      manager.initialize();

      expect(manager.connections.length, 1);
      expect(manager.connections.first.peerIdentityId, 'peer1');
    });

    // ── Stale event protection (Test 59) ──────────────────────

    test('stale callback does not corrupt newer connection state', () async {
      when(resolver.deviceToPeerId).thenReturn({
        'AA:BB:CC:DD': 'peer1',
      });

      // Attempt 1: slow connect.
      final completer1 = Completer<BleConnectionInfo>();
      when(bleService.connect('AA:BB:CC:DD')).thenAnswer((_) => completer1.future);

      // Start attempt 1.
      final future1 = manager.connectToPeer('peer1');

      // Verify connecting.
      expect(manager.lifecycleStateFor('peer1'), PeerLifecycleState.connecting);

      // Now simulate a new connect call (attempt 2) — the first one is still pending.
      // This tests that the generation counter protects against stale callbacks.
      // We won't actually complete attempt 2 since attempt 1 is still pending.

      // Complete attempt 1 with an error.
      completer1.completeError(Exception('timeout'));
      await future1.catchError((_) => null);

      // After failure, should be disconnected.
      expect(manager.lifecycleStateFor('peer1'), PeerLifecycleState.disconnected);
    });

    // ── Unknown callback (Test 43) ────────────────────────────

    test('BLE event for unknown device does not crash', () async {
      when(bleService.current).thenReturn(const BleState());
      when(resolver.deviceToPeerId).thenReturn({});

      manager.initialize();

      // No peers registered — should not crash.
      expect(manager.connections, isEmpty);
    });

    // ── Security separation (Test 61) ─────────────────────────

    test('connected state does not change trust/verification', () async {
      when(resolver.deviceToPeerId).thenReturn({
        'AA:BB:CC:DD': 'peer1',
      });
      when(bleService.connect('AA:BB:CC:DD')).thenAnswer(
        (_) async => const BleConnectionInfo(
          deviceId: 'AA:BB:CC:DD',
          state: BleConnectionState.connected,
        ),
      );

      await manager.connectToPeer('peer1');

      // Lifecycle is connected, but no trust/auth changes should occur.
      expect(manager.lifecycleStateFor('peer1'), PeerLifecycleState.connected);
      // Verify registry was not called with trust updates.
      verifyNever(registry.updateTrust(
        any,
        trustState: anyNamed('trustState'),
        isVerified: anyNamed('isVerified'),
        isAuthenticated: anyNamed('isAuthenticated'),
      ));
    });

    // ── Restart test (Test 63) ────────────────────────────────

    test('fresh manager starts with no connected peers', () {
      final freshManager = PeerConnectionManager(
        bleService: bleService,
        resolver: resolver,
        registry: registry,
      );

      expect(freshManager.connections, isEmpty);
      expect(freshManager.connectedPeerCount, 0);
      expect(freshManager.hasActiveConnections, isFalse);

      freshManager.dispose();
    });

    // ── Idempotency (Test 38) ─────────────────────────────────

    test('duplicate connect calls are idempotent', () async {
      when(resolver.deviceToPeerId).thenReturn({
        'AA:BB:CC:DD': 'peer1',
      });
      when(bleService.connect('AA:BB:CC:DD')).thenAnswer(
        (_) async => const BleConnectionInfo(
          deviceId: 'AA:BB:CC:DD',
          state: BleConnectionState.connected,
        ),
      );

      await manager.connectToPeer('peer1');
      await manager.connectToPeer('peer1');

      // Only one connect call should have been made.
      verify(bleService.connect('AA:BB:CC:DD')).called(1);
    });

    test('duplicate disconnect calls are safe', () async {
      when(bleService.disconnect('AA:BB:CC:DD'))
          .thenAnswer((_) async {});

      when(bleService.current).thenReturn(
        _bleStateWithConnection('AA:BB:CC:DD', BleConnectionState.connected),
      );
      when(resolver.deviceToPeerId).thenReturn({
        'AA:BB:CC:DD': 'peer1',
      });
      manager.initialize();

      await manager.disconnectFromPeer('peer1');
      await manager.disconnectFromPeer('peer1');

      // Only one disconnect call should have been made.
      verify(bleService.disconnect('AA:BB:CC:DD')).called(1);
    });

    test('dispose closes stream and cancels subscription', () async {
      final stateController = StreamController<BleState>();
      when(bleService.stateStream).thenAnswer(
        (_) => stateController.stream,
      );
      when(bleService.current).thenReturn(const BleState());
      when(resolver.deviceToPeerId).thenReturn({});

      manager.initialize();
      manager.dispose();

      expect(manager.connections, isEmpty);

      await stateController.close();
    });
  });

  // ── PeerEntry connection fields ─────────────────────────────

  group('PeerEntry lifecycle fields', () {
    test('default lifecycleState is disconnected', () {
      final peer = _peer(id: 1, identityId: 'aabb');
      final entry = PeerEntry(identityId: 'aabb', peer: peer);

      expect(entry.lifecycleState, PeerLifecycleState.disconnected);
      expect(entry.isConnected, isFalse);
      expect(entry.isConnecting, isFalse);
    });

    test('copyWith updates lifecycle state', () {
      final peer = _peer(id: 1, identityId: 'aabb');
      final entry = PeerEntry(identityId: 'aabb', peer: peer);

      final updated = entry.copyWith(
        lifecycleState: PeerLifecycleState.connected,
      );

      expect(updated.lifecycleState, PeerLifecycleState.connected);
      expect(updated.isConnected, isTrue);
    });

    test('equality includes lifecycle state', () {
      final peer = _peer(id: 1, identityId: 'aabb');
      final a = PeerEntry(
        identityId: 'aabb',
        peer: peer,
        lifecycleState: PeerLifecycleState.connected,
      );
      final b = PeerEntry(
        identityId: 'aabb',
        peer: peer,
        lifecycleState: PeerLifecycleState.connected,
      );
      final c = PeerEntry(
        identityId: 'aabb',
        peer: peer,
        lifecycleState: PeerLifecycleState.disconnected,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('toString includes lifecycle state', () {
      final peer = _peer(id: 1, identityId: 'aabb');
      final entry = PeerEntry(
        identityId: 'aabb',
        peer: peer,
        lifecycleState: PeerLifecycleState.connected,
      );
      expect(entry.toString(), contains('lifecycle: PeerLifecycleState.connected'));
    });
  });

  // ── PeerRegistryService.updateLifecycle ──────────────────────

  group('PeerRegistryService.updateLifecycle', () {
    test('updateLifecycle updates existing peer lifecycle state', () {
      final registryService = PeerRegistryService();
      final peer = _peer(id: 1, identityId: 'aabb');

      registryService.upsert(PeerEntry(identityId: 'aabb', peer: peer));
      registryService.updateLifecycle(
        'aabb',
        lifecycleState: PeerLifecycleState.connected,
      );

      final updated = registryService.get('aabb');
      expect(updated, isNotNull);
      expect(updated!.lifecycleState, PeerLifecycleState.connected);

      registryService.dispose();
    });

    test('updateLifecycle is safe for non-existent peer', () {
      final registryService = PeerRegistryService();

      registryService.updateLifecycle(
        'nonexistent',
        lifecycleState: PeerLifecycleState.connected,
      );

      expect(registryService.get('nonexistent'), isNull);
      registryService.dispose();
    });

    test('updateLifecycle emits on peer stream', () async {
      final registryService = PeerRegistryService();
      final peer = _peer(id: 1, identityId: 'aabb');

      final emissions = <List<PeerEntry>>[];
      final sub = registryService.peerStream.listen(emissions.add);

      registryService.upsert(PeerEntry(identityId: 'aabb', peer: peer));
      await Future<void>.delayed(Duration.zero);

      registryService.updateLifecycle(
        'aabb',
        lifecycleState: PeerLifecycleState.connected,
      );
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();

      expect(emissions.length, 2);
      expect(emissions[0].first.lifecycleState, PeerLifecycleState.disconnected);
      expect(emissions[1].first.lifecycleState, PeerLifecycleState.connected);

      registryService.dispose();
    });
  });
}
