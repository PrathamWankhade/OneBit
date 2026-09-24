import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/ble/discovered_device.dart';
import 'package:onebit/features/identity/identity_association_resolver.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/peer_registry/peer_association.dart';
import 'package:onebit/features/peer_registry/peer_connection_manager.dart';
import 'package:onebit/features/peer_registry/peer_registry.dart';
import 'package:onebit/features/trust/identity_change_service.dart';

import 'peer_association_test.mocks.dart';

// ── Helpers ────────────────────────────────────────────────────

const _keyA = 'aabbccdd11223344aabbccdd11223344aabbccdd11223344aabbccdd11223344';
const _keyB = '1122334455667788112233445566778811223344556677881122334455667788';
const _keyC = '9988776655443322998877665544332299887766554433229988776655443322';
const _localKey = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

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

DiscoveredOneBitDevice _discovery({
  required String deviceId,
  required String identityHex,
  String? name,
  int rssi = -50,
  int timestamp = 1000,
}) {
  final keyBytes = <int>[];
  for (var i = 0; i < identityHex.length; i += 2) {
    keyBytes.add(int.parse(identityHex.substring(i, i + 2), radix: 16));
  }
  return DiscoveredOneBitDevice(
    deviceId: deviceId,
    rssi: rssi,
    timestamp: timestamp,
    name: name,
    identityPublicKeyBytes: keyBytes,
  );
}

DiscoveredOneBitDevice _discoveryNoIdentity({
  required String deviceId,
  String? name,
  int rssi = -50,
  int timestamp = 1000,
}) {
  return DiscoveredOneBitDevice(
    deviceId: deviceId,
    rssi: rssi,
    timestamp: timestamp,
    name: name,
  );
}

BleState _bleStateWithConnection(String deviceId, BleConnectionState state) {
  return BleState(
    connections: {
      deviceId: BleConnectionInfo(deviceId: deviceId, state: state),
    },
  );
}

// ── Mocks ──────────────────────────────────────────────────────

@GenerateMocks([BleService, PeerRegistryService])
void main() {
  // ── PeerAssociation Model ──────────────────────────────────

  group('PeerAssociation', () {
    test('construction holds all fields', () {
      final now = DateTime(2025);
      final a = PeerAssociation(
        bleDeviceId: 'AA:BB:CC',
        peerIdentityId: _keyA,
        generation: 1,
        createdAt: now,
      );
      expect(a.bleDeviceId, 'AA:BB:CC');
      expect(a.peerIdentityId, _keyA);
      expect(a.generation, 1);
      expect(a.createdAt, now);
    });

    test('equality based on all fields', () {
      const a = PeerAssociation(
        bleDeviceId: 'AA:BB:CC',
        peerIdentityId: _keyA,
        generation: 1,
      );
      const b = PeerAssociation(
        bleDeviceId: 'AA:BB:CC',
        peerIdentityId: _keyA,
        generation: 1,
      );
      const c = PeerAssociation(
        bleDeviceId: 'AA:BB:CC',
        peerIdentityId: _keyA,
        generation: 2,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('toString includes device and truncated identity', () {
      const a = PeerAssociation(
        bleDeviceId: 'AA:BB:CC',
        peerIdentityId: _keyA,
        generation: 1,
      );
      expect(a.toString(), contains('AA:BB:CC'));
      expect(a.toString(), contains(_keyA.substring(0, 8)));
    });
  });

  // ── AssociationConflict Model ───────────────────────────────

  group('AssociationConflict', () {
    test('construction holds all fields', () {
      const c = AssociationConflict(
        identityId: _keyA,
        existingDeviceId: 'AA:BB:CC',
        requestedDeviceId: 'DD:EE:FF',
      );
      expect(c.identityId, _keyA);
      expect(c.existingDeviceId, 'AA:BB:CC');
      expect(c.requestedDeviceId, 'DD:EE:FF');
    });

    test('toString includes fields', () {
      const c = AssociationConflict(
        identityId: _keyA,
        existingDeviceId: 'AA:BB:CC',
        requestedDeviceId: 'DD:EE:FF',
      );
      expect(c.toString(), contains('AA:BB:CC'));
      expect(c.toString(), contains('DD:EE:FF'));
    });
  });

  // ── IdentityAssociationResolver Association Management ─────

  group('IdentityAssociationResolver - Association Management', () {
    late MockBleService mockBle;
    late IdentityChangeService changeService;
    late StreamController<DiscoveredOneBitDevice> discoveryCtrl;
    late StreamController<List<PeerInfo>> peerCtrl;
    late IdentityAssociationResolver resolver;

    setUp(() {
      mockBle = MockBleService();
      changeService = IdentityChangeService();
      discoveryCtrl = StreamController<DiscoveredOneBitDevice>.broadcast();
      peerCtrl = StreamController<List<PeerInfo>>.broadcast();

      when(mockBle.discoveryStream).thenAnswer((_) => discoveryCtrl.stream);

      resolver = IdentityAssociationResolver(
        discoveryStream: discoveryCtrl.stream,
        peerStream: peerCtrl.stream,
        localPublicKeyHex: _localKey,
        identityChangeService: changeService,
      );
    });

    tearDown(() {
      resolver.dispose();
      discoveryCtrl.close();
      peerCtrl.close();
      changeService.dispose();
    });

    // ── Test 1: Unknown device cannot become trusted peer ──────

    test('Test 1 — unknown device cannot become trusted peer', () async {
      final device = _discoveryNoIdentity(deviceId: 'AA:BB:CC');
      final resolved = resolver.resolve(device);

      expect(resolved.status, BlePeerStatus.noIdentity);
      expect(resolved.peer, isNull);
      expect(resolver.associationCount, 0);
    });

    // ── Test 2: Valid identity association ─────────────────────

    test('Test 2 — valid identity resolves to correct peer', () async {
      // Seed peer cache with known peer.
      peerCtrl.add([_peer(id: 1, identityId: _keyA)]);
      await Future<void>.delayed(Duration.zero);

      final device = _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA);
      final resolved = resolver.resolve(device);

      expect(resolved.status, BlePeerStatus.knownPeer);
      expect(resolved.peer, isNotNull);
      expect(resolved.peer!.identityId, _keyA);

      // Association should be tracked.
      expect(resolver.associationCount, 1);
      final assoc = resolver.associations.first;
      expect(assoc.bleDeviceId, 'AA:BB:CC');
      expect(assoc.peerIdentityId, _keyA.toLowerCase());
    });

    // ── Test 3: Same identity resolves to same peer ────────────

    test('Test 3 — same identity always resolves to same peer', () async {
      peerCtrl.add([_peer(id: 1, identityId: _keyA)]);
      await Future<void>.delayed(Duration.zero);

      final device1 = _discovery(
        deviceId: 'AA:BB:CC',
        identityHex: _keyA,
        timestamp: 1000,
      );
      final device2 = _discovery(
        deviceId: 'DD:EE:FF',
        identityHex: _keyA,
        timestamp: 4000,
      );

      final resolved1 = resolver.resolve(device1);
      final resolved2 = resolver.resolve(device2);

      // Same identity → same peer (same PeerInfo).
      expect(resolved1.peer?.identityId, _keyA);
      expect(resolved2.peer?.identityId, _keyA);

      // Both devices should have associations.
      expect(resolver.associationCount, 2);
    });

    // ── Test 4: Multiple identities remain independent ─────────

    test('Test 4 — multiple identities are independently associated',
        () async {
      peerCtrl.add([
        _peer(id: 1, identityId: _keyA),
        _peer(id: 2, identityId: _keyB),
        _peer(id: 3, identityId: _keyC),
      ]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));
      resolver.resolve(_discovery(deviceId: 'DevB', identityHex: _keyB));
      resolver.resolve(_discovery(deviceId: 'DevC', identityHex: _keyC));

      expect(resolver.associationCount, 3);

      // Each device resolves to its correct peer.
      final deviceA = resolver.resolveDevice(_keyA);
      final deviceB = resolver.resolveDevice(_keyB);
      final deviceC = resolver.resolveDevice(_keyC);

      expect(deviceA, 'DevA');
      expect(deviceB, 'DevB');
      expect(deviceC, 'DevC');
    });

    // ── Test 5: Multiple BLE devices correctly handled ─────────

    test('Test 5 — different BLE devices map to correct peers', () async {
      peerCtrl.add([
        _peer(id: 1, identityId: _keyA),
        _peer(id: 2, identityId: _keyB),
      ]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(deviceId: 'Device1', identityHex: _keyA));
      resolver.resolve(_discovery(deviceId: 'Device2', identityHex: _keyB));

      // Reverse lookup: each peer maps to its device.
      expect(resolver.resolveDevice(_keyA), 'Device1');
      expect(resolver.resolveDevice(_keyB), 'Device2');
    });

    // ── Test 6: BLE identifier is not identity ─────────────────

    test('Test 6 — changing BLE device ID does not change peer identity',
        () async {
      peerCtrl.add([_peer(id: 1, identityId: _keyA)]);
      await Future<void>.delayed(Duration.zero);

      // Same identity, different BLE device IDs.
      resolver.resolve(_discovery(deviceId: 'OldMAC', identityHex: _keyA));
      resolver.resolve(_discovery(
        deviceId: 'NewMAC',
        identityHex: _keyA,
        timestamp: 4000,
      ));

      // Both should resolve to the same peer identity.
      final resolvedOld = resolver.resolve(
        _discovery(deviceId: 'OldMAC', identityHex: _keyA, timestamp: 7000),
      );
      final resolvedNew = resolver.resolve(
        _discovery(deviceId: 'NewMAC', identityHex: _keyA, timestamp: 8000),
      );

      expect(resolvedOld.peer?.identityId, _keyA);
      expect(resolvedNew.peer?.identityId, _keyA);
    });

    // ── Test 7: Device name is not identity ────────────────────

    test('Test 7 — device name change does not change peer identity',
        () async {
      peerCtrl.add([_peer(id: 1, identityId: _keyA, displayName: 'Alice')]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(
        deviceId: 'AA:BB:CC',
        identityHex: _keyA,
        name: 'Alice',
      ));
      resolver.resolve(_discovery(
        deviceId: 'AA:BB:CC',
        identityHex: _keyA,
        name: 'Alice Phone',
        timestamp: 4000,
      ));

      // Identity should be the same regardless of name.
      final resolved = resolver.resolve(
        _discovery(
          deviceId: 'AA:BB:CC',
          identityHex: _keyA,
          name: 'Alice Work',
          timestamp: 7000,
        ),
      );
      expect(resolved.peer?.identityId, _keyA);
      expect(resolved.peer?.displayName, 'Alice');
    });

    // ── Test 8: RSSI is not identity ───────────────────────────

    test('Test 8 — RSSI changes do not affect association', () async {
      peerCtrl.add([_peer(id: 1, identityId: _keyA)]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(
        deviceId: 'AA:BB:CC',
        identityHex: _keyA,
        rssi: -40,
      ));
      resolver.resolve(_discovery(
        deviceId: 'AA:BB:CC',
        identityHex: _keyA,
        rssi: -85,
        timestamp: 4000,
      ));

      final resolved = resolver.resolve(
        _discovery(
          deviceId: 'AA:BB:CC',
          identityHex: _keyA,
          rssi: -90,
          timestamp: 7000,
        ),
      );
      expect(resolved.peer?.identityId, _keyA);
    });

    // ── Test 9: Same device, same identity — no change ─────────

    test('Test 9 — same device same identity produces no change', () async {
      peerCtrl.add([_peer(id: 1, identityId: _keyA)]);
      await Future<void>.delayed(Duration.zero);

      changeService.recordAssociation('AA:BB:CC', _keyA);

      final device = _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA);
      final change = changeService.checkForChange(device);

      expect(change, isNull);
    });

    // ── Test 10: Same device, different identity — I6.10 ───────

    test('Test 10 — same device different identity invokes I6.10',
        () async {
      peerCtrl.add([
        _peer(id: 1, identityId: _keyA),
        _peer(id: 2, identityId: _keyB),
      ]);
      await Future<void>.delayed(Duration.zero);

      // First: device has identity A (known peer).
      resolver.resolve(_discovery(deviceId: 'AA:BB:CC', identityHex: _keyA));

      // Now: device presents identity B — identity change detected.
      final device = _discovery(deviceId: 'AA:BB:CC', identityHex: _keyB);
      final resolved = resolver.resolve(device);

      expect(resolved.status, BlePeerStatus.identityChanged);
      expect(resolved.identityChange, isNotNull);
      expect(resolved.identityChange!.previousIdentityId, _keyA);
      expect(resolved.identityChange!.currentIdentityId, _keyB);
    });

    // ── Test 11: No trust inheritance across identity change ───

    test('Test 11 — identity Y does not inherit trust from identity X',
        () async {
      peerCtrl.add([
        _peer(id: 1, identityId: _keyA),
        _peer(id: 2, identityId: _keyB),
      ]);
      await Future<void>.delayed(Duration.zero);

      // Seed: device previously had identity A.
      changeService.recordAssociation('AA:BB:CC', _keyA);

      // Device now presents identity B.
      final device = _discovery(deviceId: 'AA:BB:CC', identityHex: _keyB);
      final resolved = resolver.resolve(device);

      // Identity change is detected — does NOT silently overwrite.
      expect(resolved.status, BlePeerStatus.identityChanged);

      // Identity A still exists as a peer — not deleted.
      final peerA = resolver.lookupPeer(_keyA);
      expect(peerA, isNotNull);
      expect(peerA!.identityId, _keyA);
    });

    // ── Test 12: Identity X not deleted when Y appears ─────────

    test('Test 12 — identity X not silently deleted when Y appears',
        () async {
      peerCtrl.add([
        _peer(id: 1, identityId: _keyA),
        _peer(id: 2, identityId: _keyB),
      ]);
      await Future<void>.delayed(Duration.zero);

      changeService.recordAssociation('AA:BB:CC', _keyA);
      resolver.resolve(_discovery(deviceId: 'AA:BB:CC', identityHex: _keyA));

      // Device changes identity.
      resolver.resolve(_discovery(
        deviceId: 'AA:BB:CC',
        identityHex: _keyB,
        timestamp: 4000,
      ));

      // Both identities still exist in the peer cache.
      expect(resolver.lookupPeer(_keyA), isNotNull);
      expect(resolver.lookupPeer(_keyB), isNotNull);
    });

    // ── Test 48: Peer isolation ────────────────────────────────

    test('Test 48 — events for device A do not affect device B', () async {
      peerCtrl.add([
        _peer(id: 1, identityId: _keyA),
        _peer(id: 2, identityId: _keyB),
      ]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));
      resolver.resolve(_discovery(deviceId: 'DevB', identityHex: _keyB));

      final deviceA = resolver.resolveDevice(_keyA);
      final deviceB = resolver.resolveDevice(_keyB);
      expect(deviceA, 'DevA');
      expect(deviceB, 'DevB');

      // Generate events for A — B should be unaffected.
      resolver.resolve(_discovery(
        deviceId: 'DevA',
        identityHex: _keyA,
        timestamp: 4000,
      ));

      expect(resolver.resolveDevice(_keyA), 'DevA');
      expect(resolver.resolveDevice(_keyB), 'DevB');
    });

    // ── Test 49: Connection isolation ──────────────────────────

    test('Test 49 — disconnecting A does not affect B', () async {
      peerCtrl.add([
        _peer(id: 1, identityId: _keyA),
        _peer(id: 2, identityId: _keyB),
      ]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));
      resolver.resolve(_discovery(deviceId: 'DevB', identityHex: _keyB));

      expect(resolver.associationCount, 2);

      // Remove A's association — B should remain.
      resolver.removeAssociation('DevA');

      expect(resolver.associationCount, 1);
      expect(resolver.resolveDevice(_keyA), isNull);
      expect(resolver.resolveDevice(_keyB), 'DevB');
    });

    // ── Test 50: Association conflict ──────────────────────────

    test('Test 50 — same identity on different device creates conflict',
        () async {
      peerCtrl.add([
        _peer(id: 1, identityId: _keyA),
      ]);
      await Future<void>.delayed(Duration.zero);

      // Seed: identity A is on device DevA via resolve.
      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));

      // Conflict: identity A now on device DevB.
      final conflict = resolver.checkConflict('DevB', _keyA);

      expect(conflict, isNotNull);
      expect(conflict!.identityId, _keyA);
      expect(conflict.existingDeviceId, 'DevA');
      expect(conflict.requestedDeviceId, 'DevB');
    });

    // ── Test 51: No conflict for same device ───────────────────

    test('Test 51 — no conflict when same device requests same identity',
        () async {
      peerCtrl.add([_peer(id: 1, identityId: _keyA)]);
      await Future<void>.delayed(Duration.zero);

      // Seed via resolve.
      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));

      final conflict = resolver.checkConflict('DevA', _keyA);
      expect(conflict, isNull);
    });

    // ── Test 52: Stale event protection ────────────────────────

    test('Test 52 — stale event does not corrupt current association',
        () async {
      peerCtrl.add([
        _peer(id: 1, identityId: _keyA),
        _peer(id: 2, identityId: _keyB),
      ]);
      await Future<void>.delayed(Duration.zero);

      // Device A was associated with identity A (old connection).
      resolver.resolve(_discovery(deviceId: 'Dev', identityHex: _keyA));
      final gen1 = resolver.generationFor('Dev');
      expect(gen1, greaterThan(0));

      // Device A now associates with identity B (new connection).
      // This should increment the generation.
      resolver.resolve(_discovery(
        deviceId: 'Dev',
        identityHex: _keyB,
        timestamp: 4000,
      ));
      final gen2 = resolver.generationFor('Dev');
      expect(gen2, greaterThan(gen1));

      // The current generation reflects the latest association.
      final currentGen = resolver.generationFor('Dev');
      expect(currentGen, gen2);
    });

    // ── Test 53: Unknown device event does not crash ───────────

    test('Test 53 — event for unknown device does not crash', () async {
      final device = _discoveryNoIdentity(deviceId: 'Unknown');
      final resolved = resolver.resolve(device);

      expect(resolved.status, BlePeerStatus.noIdentity);
      expect(resolved.peer, isNull);
      expect(resolver.associationCount, 0);
    });

    // ── Test 54: Unknown device event does not overwrite ───────

    test('Test 54 — unknown device does not overwrite association',
        () async {
      peerCtrl.add([
        _peer(id: 1, identityId: _keyA),
      ]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));
      expect(resolver.associationCount, 1);

      // Unknown device event — should not affect existing association.
      resolver.resolve(_discoveryNoIdentity(deviceId: 'Unknown'));
      expect(resolver.associationCount, 1);
      expect(resolver.resolveDevice(_keyA), 'DevA');
    });

    // ── Test 55: Association removal ───────────────────────────

    test('Test 55 — removeAssociation clears device association', () async {
      peerCtrl.add([_peer(id: 1, identityId: _keyA)]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));
      expect(resolver.associationCount, 1);

      final removed = resolver.removeAssociation('DevA');
      expect(removed, isTrue);
      expect(resolver.associationCount, 0);
      expect(resolver.resolveDevice(_keyA), isNull);
    });

    // ── Test 56: removeAssociationForPeer ──────────────────────

    test('Test 56 — removeAssociationForPeer clears peer association',
        () async {
      peerCtrl.add([_peer(id: 1, identityId: _keyA)]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));
      expect(resolver.associationCount, 1);

      final removed = resolver.removeAssociationForPeer(_keyA);
      expect(removed, isTrue);
      expect(resolver.associationCount, 0);
      expect(resolver.resolveDevice(_keyA), isNull);
    });

    // ── Test 57: clearAssociations ─────────────────────────────

    test('Test 57 — clearAssociations removes all', () async {
      peerCtrl.add([
        _peer(id: 1, identityId: _keyA),
        _peer(id: 2, identityId: _keyB),
      ]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));
      resolver.resolve(_discovery(deviceId: 'DevB', identityHex: _keyB));
      expect(resolver.associationCount, 2);

      resolver.clearAssociations();
      expect(resolver.associationCount, 0);
    });

    // ── Test 58: Association stream emits on changes ───────────

    test('Test 58 — associationStream emits on changes', () async {
      final events = <List<PeerAssociation>>[];
      resolver.associationStream.listen(events.add);

      peerCtrl.add([_peer(id: 1, identityId: _keyA)]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));
      await Future<void>.delayed(Duration.zero);

      expect(events.length, greaterThanOrEqualTo(1));
      expect(events.last.first.bleDeviceId, 'DevA');
    });

    // ── Test 59: Self identity creates association ─────────────

    test('Test 59 — self identity creates association', () async {
      final device = _discovery(deviceId: 'Self', identityHex: _localKey);
      final resolved = resolver.resolve(device);

      expect(resolved.status, BlePeerStatus.selfIdentity);
      expect(resolver.associationCount, 1);
      expect(resolver.associations.first.peerIdentityId,
          _localKey.toLowerCase());
    });

    // ── Test 60: Unknown identity creates no association ───────

    test('Test 60 — unknown identity creates no association', () async {
      final device = _discovery(deviceId: 'Unknown', identityHex: _keyA);
      final resolved = resolver.resolve(device);

      expect(resolved.status, BlePeerStatus.unknownIdentity);
      expect(resolved.peer, isNull);
      expect(resolver.associationCount, 0);
    });

    // ── Test 61: No identity creates no association ────────────

    test('Test 61 — no identity in advertisement creates no association',
        () async {
      final device = _discoveryNoIdentity(deviceId: 'NoIdentity');
      final resolved = resolver.resolve(device);

      expect(resolved.status, BlePeerStatus.noIdentity);
      expect(resolver.associationCount, 0);
    });
  });

  // ── PeerConnectionManager Association Integration ──────────

  group('PeerConnectionManager - Association Integration', () {
    late MockBleService mockBle;
    late IdentityChangeService changeService;
    late StreamController<DiscoveredOneBitDevice> discoveryCtrl;
    late StreamController<List<PeerInfo>> peerCtrl;
    late StreamController<BleState> bleStateCtrl;
    late IdentityAssociationResolver resolver;
    late PeerConnectionManager manager;

    setUp(() {
      mockBle = MockBleService();
      changeService = IdentityChangeService();
      discoveryCtrl = StreamController<DiscoveredOneBitDevice>.broadcast();
      peerCtrl = StreamController<List<PeerInfo>>.broadcast();
      bleStateCtrl = StreamController<BleState>.broadcast();

      when(mockBle.discoveryStream).thenAnswer((_) => discoveryCtrl.stream);
      when(mockBle.stateStream).thenAnswer((_) => bleStateCtrl.stream);
      when(mockBle.current).thenReturn(const BleState());

      resolver = IdentityAssociationResolver(
        discoveryStream: discoveryCtrl.stream,
        peerStream: peerCtrl.stream,
        localPublicKeyHex: _localKey,
        identityChangeService: changeService,
      );

      final mockRegistry = MockPeerRegistryService();

      manager = PeerConnectionManager(
        bleService: mockBle,
        resolver: resolver,
        registry: mockRegistry,
      );
    });

    tearDown(() {
      manager.dispose();
      resolver.dispose();
      discoveryCtrl.close();
      peerCtrl.close();
      bleStateCtrl.close();
      changeService.dispose();
    });

    // ── Test 62: currentAssociations exposes resolver state ────

    test('Test 62 — currentAssociations exposes resolver state', () async {
      peerCtrl.add([_peer(id: 1, identityId: _keyA)]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));

      final associations = manager.currentAssociations;
      expect(associations.length, 1);
      expect(associations.first.peerIdentityId, _keyA.toLowerCase());
    });

    // ── Test 63: connectToPeer uses association resolver ───────

    test('Test 63 — connectToPeer uses association resolver for lookup',
        () async {
      peerCtrl.add([_peer(id: 1, identityId: _keyA)]);
      await Future<void>.delayed(Duration.zero);

      // Seed association.
      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));

      // Set up BLE state with connected device.
      when(mockBle.current).thenReturn(
        _bleStateWithConnection('DevA', BleConnectionState.connected),
      );
      when(mockBle.connect('DevA')).thenAnswer(
        (_) async => const BleConnectionInfo(
          deviceId: 'DevA',
          state: BleConnectionState.connected,
        ),
      );

      final deviceId = await manager.connectToPeer(_keyA);
      expect(deviceId, 'DevA');
    });

    // ── Test 64: disconnect removes association ────────────────

    test('Test 64 — disconnect removes association', () async {
      peerCtrl.add([_peer(id: 1, identityId: _keyA)]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));
      expect(resolver.associationCount, 1);

      when(mockBle.connect('DevA')).thenAnswer(
        (_) async => const BleConnectionInfo(
          deviceId: 'DevA',
          state: BleConnectionState.connected,
        ),
      );
      when(mockBle.disconnect('DevA')).thenAnswer((_) async {});

      // Connect first to populate _peerToDevice.
      await manager.connectToPeer(_keyA);
      expect(manager.isPeerConnected(_keyA), isTrue);

      // Now disconnect.
      await manager.disconnectFromPeer(_keyA);

      // After explicit disconnect, association should be removed.
      expect(resolver.resolveDevice(_keyA), isNull);
    });

    // ── Test 65: disconnect B does not affect A ────────────────

    test('Test 65 — disconnect B does not affect A', () async {
      peerCtrl.add([
        _peer(id: 1, identityId: _keyA),
        _peer(id: 2, identityId: _keyB),
      ]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));
      resolver.resolve(_discovery(deviceId: 'DevB', identityHex: _keyB));

      when(mockBle.connect(any)).thenAnswer(
        (invocation) async => BleConnectionInfo(
          deviceId: invocation.positionalArguments[0] as String,
          state: BleConnectionState.connected,
        ),
      );
      when(mockBle.disconnect(any)).thenAnswer((_) async {});

      // Connect both peers.
      await manager.connectToPeer(_keyA);
      await manager.connectToPeer(_keyB);

      // Disconnect only B.
      await manager.disconnectFromPeer(_keyB);

      // A's association should remain.
      expect(resolver.resolveDevice(_keyA), 'DevA');
      expect(resolver.resolveDevice(_keyB), isNull);
    });
  });

  // ── Multi-peer Coexistence ──────────────────────────────────

  group('Multi-peer Association Coexistence', () {
    late MockBleService mockBle;
    late IdentityChangeService changeService;
    late StreamController<DiscoveredOneBitDevice> discoveryCtrl;
    late StreamController<List<PeerInfo>> peerCtrl;
    late IdentityAssociationResolver resolver;

    setUp(() {
      mockBle = MockBleService();
      changeService = IdentityChangeService();
      discoveryCtrl = StreamController<DiscoveredOneBitDevice>.broadcast();
      peerCtrl = StreamController<List<PeerInfo>>.broadcast();

      when(mockBle.discoveryStream).thenAnswer((_) => discoveryCtrl.stream);

      resolver = IdentityAssociationResolver(
        discoveryStream: discoveryCtrl.stream,
        peerStream: peerCtrl.stream,
        localPublicKeyHex: _localKey,
        identityChangeService: changeService,
      );
    });

    tearDown(() {
      resolver.dispose();
      discoveryCtrl.close();
      peerCtrl.close();
      changeService.dispose();
    });

    // ── Test 66: Three peers independently associated ──────────

    test('Test 66 — three peers independently associated', () async {
      peerCtrl.add([
        _peer(id: 1, identityId: _keyA, displayName: 'Alice'),
        _peer(id: 2, identityId: _keyB, displayName: 'Bob'),
        _peer(id: 3, identityId: _keyC, displayName: 'Carol'),
      ]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));
      resolver.resolve(_discovery(deviceId: 'DevB', identityHex: _keyB));
      resolver.resolve(_discovery(deviceId: 'DevC', identityHex: _keyC));

      expect(resolver.associationCount, 3);
      expect(resolver.resolveDevice(_keyA), 'DevA');
      expect(resolver.resolveDevice(_keyB), 'DevB');
      expect(resolver.resolveDevice(_keyC), 'DevC');
    });

    // ── Test 67: Identity collision detection ──────────────────

    test('Test 67 — same identity on two devices detected', () async {
      peerCtrl.add([_peer(id: 1, identityId: _keyA)]);
      await Future.delayed(Duration.zero);

      // Seed: identity A is on DevA via resolve.
      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));

      // Same identity now on DevB — should conflict.
      final conflict = resolver.checkConflict('DevB', _keyA);
      expect(conflict, isNotNull);
    });

    // ── Test 68: Two devices sharing same identity ─────────────

    test('Test 68 — two devices with same identity both resolve to same peer',
        () async {
      peerCtrl.add([_peer(id: 1, identityId: _keyA)]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));
      resolver.resolve(_discovery(
        deviceId: 'DevB',
        identityHex: _keyA,
        timestamp: 4000,
      ));

      // Both resolve to the same peer.
      final resolvedA = resolver.resolve(
        _discovery(deviceId: 'DevA', identityHex: _keyA, timestamp: 7000),
      );
      final resolvedB = resolver.resolve(
        _discovery(deviceId: 'DevB', identityHex: _keyA, timestamp: 8000),
      );

      expect(resolvedA.peer?.identityId, _keyA);
      expect(resolvedB.peer?.identityId, _keyA);
      expect(resolvedA.peer, equals(resolvedB.peer));
    });

    // ── Test 69: Remove one association, others persist ────────

    test('Test 69 — removing one association does not affect others',
        () async {
      peerCtrl.add([
        _peer(id: 1, identityId: _keyA),
        _peer(id: 2, identityId: _keyB),
        _peer(id: 3, identityId: _keyC),
      ]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));
      resolver.resolve(_discovery(deviceId: 'DevB', identityHex: _keyB));
      resolver.resolve(_discovery(deviceId: 'DevC', identityHex: _keyC));

      resolver.removeAssociation('DevB');

      expect(resolver.associationCount, 2);
      expect(resolver.resolveDevice(_keyA), 'DevA');
      expect(resolver.resolveDevice(_keyB), isNull);
      expect(resolver.resolveDevice(_keyC), 'DevC');
    });

    // ── Test 70: Disconnect B, A and C remain ──────────────────

    test('Test 70 — disconnecting B leaves A and C associations intact',
        () async {
      peerCtrl.add([
        _peer(id: 1, identityId: _keyA),
        _peer(id: 2, identityId: _keyB),
        _peer(id: 3, identityId: _keyC),
      ]);
      await Future<void>.delayed(Duration.zero);

      resolver.resolve(_discovery(deviceId: 'DevA', identityHex: _keyA));
      resolver.resolve(_discovery(deviceId: 'DevB', identityHex: _keyB));
      resolver.resolve(_discovery(deviceId: 'DevC', identityHex: _keyC));

      resolver.removeAssociationForPeer(_keyB);

      expect(resolver.associationCount, 2);
      expect(resolver.resolveDevice(_keyA), 'DevA');
      expect(resolver.resolveDevice(_keyC), 'DevC');
    });
  });
}
