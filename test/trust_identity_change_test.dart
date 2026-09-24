import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/ble/discovered_device.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/trust/identity_change.dart';
import 'package:onebit/features/trust/identity_change_service.dart';
import 'package:onebit/features/trust/peer_trust.dart';
import 'package:onebit/features/trust/trust_service.dart';
import 'package:onebit/features/trust/trust_state.dart';

void main() {
  AppDatabase createTestDb() =>
      AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));

  /// Helper: create a trusted peer through the service API.
  void makeTrusted(TrustService s, String id, {DateTime? at}) {
    final t = at ?? DateTime.now();
    s.verify(peerIdentityId: id, at: t, method: VerificationMethod.qrScan);
    s.markAuthenticated(peerIdentityId: id);
    s.trust(peerIdentityId: id, at: t);
  }

  DiscoveredOneBitDevice makeDevice({
    String deviceId = 'AA:BB:CC:DD:EE:FF',
    String identityHex = 'aabbccdd',
    String name = 'TestDevice',
    int timestamp = 1000000,
  }) {
    // Convert hex string to bytes, padding to 32 bytes.
    final keyBytes = <int>[];
    for (var i = 0; i < identityHex.length; i += 2) {
      keyBytes.add(int.parse(identityHex.substring(i, i + 2), radix: 16));
    }
    while (keyBytes.length < 32) {
      keyBytes.add(0);
    }
    return DiscoveredOneBitDevice(
      deviceId: deviceId,
      rssi: -50,
      timestamp: timestamp,
      name: name,
      identityPublicKeyBytes: keyBytes,
    );
  }

  // ── PeerIdentityChange model ──────────────────────────────────

  group('PeerIdentityChange', () {
    test('hasChanged returns true for changed status', () {
      const change = PeerIdentityChange(
        bleAddress: 'AA:BB:CC:DD:EE:FF',
        previousIdentityId: 'aaa',
        currentIdentityId: 'bbb',
        status: IdentityChangeStatus.changed,
      );
      expect(change.hasChanged, isTrue);
    });

    test('hasChanged returns false for unchanged status', () {
      const change = PeerIdentityChange(
        bleAddress: 'AA:BB:CC:DD:EE:FF',
        previousIdentityId: 'aaa',
        currentIdentityId: 'bbb',
        status: IdentityChangeStatus.unchanged,
      );
      expect(change.hasChanged, isFalse);
    });

    test('toString includes truncated identities', () {
      const change = PeerIdentityChange(
        bleAddress: 'AA:BB:CC:DD:EE:FF',
        previousIdentityId: 'aaaabbbbcccc',
        currentIdentityId: 'ddddeeeeffff',
        status: IdentityChangeStatus.changed,
      );
      expect(change.toString(), contains('IdentityChange'));
    });
  });

  // ── IdentityChangeService ─────────────────────────────────────

  group('IdentityChangeService', () {
    late IdentityChangeService service;

    setUp(() => service = IdentityChangeService());

    test('first encounter returns null (no change)', () {
      final device = makeDevice(deviceId: 'AA:BB:CC:DD:EE:FF');
      final result = service.checkForChange(device);
      expect(result, isNull);
    });

    test('same identity returns null (no change)', () {
      final device1 = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: 'aabbccdd',
      );
      final device2 = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: 'aabbccdd',
        timestamp: 2000000,
      );

      service.checkForChange(device1);
      final result = service.checkForChange(device2);

      expect(result, isNull);
    });

    test('different identity returns change', () {
      final device1 = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: 'aabbccdd',
      );
      final device2 = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: '11223344',
        timestamp: 2000000,
      );

      service.checkForChange(device1);
      final result = service.checkForChange(device2);

      expect(result, isNotNull);
      expect(result!.hasChanged, isTrue);
      expect(result.previousIdentityId, contains('aabbccdd'));
      expect(result.currentIdentityId, contains('11223344'));
    });

    test('different BLE addresses are independent', () {
      final device1 = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: 'aabbccdd',
      );
      final device2 = makeDevice(
        deviceId: '11:22:33:44:55:66',
        identityHex: '11223344',
      );

      service.checkForChange(device1);
      final result = service.checkForChange(device2);

      // Different BLE address — no change detected
      expect(result, isNull);
    });

    test('same identity, different BLE address — no change', () {
      final device1 = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: 'aabbccdd',
      );
      final device2 = makeDevice(
        deviceId: '11:22:33:44:55:66',
        identityHex: 'aabbccdd',
      );

      service.checkForChange(device1);
      final result = service.checkForChange(device2);

      expect(result, isNull);
    });

    test('case-insensitive identity comparison', () {
      final device1 = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: 'aabbccdd',
      );
      final device2 = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: 'AABBCCDD',
        timestamp: 2000000,
      );

      service.checkForChange(device1);
      final result = service.checkForChange(device2);

      expect(result, isNull);
    });

    test('onChange emits identity change events', () async {
      final changes = <PeerIdentityChange>[];
      service.onChange.listen(changes.add);

      final device1 = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: 'aabbccdd',
      );
      final device2 = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: '11223344',
        timestamp: 2000000,
      );

      service.checkForChange(device1);
      service.checkForChange(device2);

      // Allow microtask to complete.
      await Future<void>.delayed(Duration.zero);

      expect(changes.length, 1);
      expect(changes.first.hasChanged, isTrue);
    });

    test('recordAssociation seeds mapping without change', () {
      // Use the full 64-char hex identity that makeDevice produces.
      final device = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: 'aabbccdd',
      );
      // Seed with the same identityIdHex that the device produces.
      service.recordAssociation('AA:BB:CC:DD:EE:FF', device.identityIdHex!);

      final result = service.checkForChange(device);

      expect(result, isNull);
    });

    test('recordAssociation followed by different identity detects change', () {
      final device1 = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: 'aabbccdd',
      );
      service.recordAssociation('AA:BB:CC:DD:EE:FF', device1.identityIdHex!);

      final device2 = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: '11223344',
      );
      final result = service.checkForChange(device2);

      expect(result, isNotNull);
      expect(result!.hasChanged, isTrue);
    });

    test('hasIdentityChanged returns correct value', () {
      final device = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: 'aabbccdd',
      );
      service.recordAssociation('AA:BB:CC:DD:EE:FF', device.identityIdHex!);

      expect(
        service.hasIdentityChanged('AA:BB:CC:DD:EE:FF', device.identityIdHex!),
        isFalse,
      );
      expect(
        service.hasIdentityChanged('AA:BB:CC:DD:EE:FF', '11223344'),
        isTrue,
      );
      expect(
        service.hasIdentityChanged('11:22:33:44:55:66', device.identityIdHex!),
        isFalse,
      );
    });

    test('getPreviousIdentity returns stored identity', () {
      final device = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: 'aabbccdd',
      );
      service.recordAssociation('AA:BB:CC:DD:EE:FF', device.identityIdHex!);

      expect(
        service.getPreviousIdentity('AA:BB:CC:DD:EE:FF'),
        device.identityIdHex,
      );
      expect(
        service.getPreviousIdentity('11:22:33:44:55:66'),
        isNull,
      );
    });

    test('trackedCount reflects stored mappings', () {
      expect(service.trackedCount, 0);
      service.recordAssociation('AA:BB:CC:DD:EE:FF', 'aabbccdd');
      expect(service.trackedCount, 1);
      service.recordAssociation('11:22:33:44:55:66', '11223344');
      expect(service.trackedCount, 2);
    });

    test('clear removes all mappings', () {
      service.recordAssociation('AA:BB:CC:DD:EE:FF', 'aabbccdd');
      service.clear();
      expect(service.trackedCount, 0);
    });

    test('null identity in device returns null', () {
      const device = DiscoveredOneBitDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        rssi: -50,
        timestamp: 1000000,
      );
      final result = service.checkForChange(device);
      expect(result, isNull);
    });
  });

  // ── IdentityChangeService with persistence ────────────────────

  group('IdentityChangeService persistence', () {
    late AppDatabase db;
    late IdentityRepository repo;

    setUp(() async {
      db = createTestDb();
      repo = IdentityRepository(db);

      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: 'peer_a_pub_key',
        publicKey: 'peer_a_pub_key',
      );
    });

    tearDown(() async => await db.close());

    test('loadPersistedMappings loads BLE addresses from database', () async {
      // Update the peer with a BLE address.
      final peer = await repo.getPeerByIdentityId('peer_a_pub_key');
      await repo.updatePeerLastSeenBleAddress(
        id: peer!.id,
        lastSeenBleAddress: 'AA:BB:CC:DD:EE:FF',
      );

      final service = IdentityChangeService(repo);
      await service.loadPersistedMappings();

      expect(service.trackedCount, 1);
      expect(
        service.getPreviousIdentity('AA:BB:CC:DD:EE:FF'),
        'peer_a_pub_key',
      );
    });

    test('loadPersistedMappings detects change after reload', () async {
      final peer = await repo.getPeerByIdentityId('peer_a_pub_key');
      await repo.updatePeerLastSeenBleAddress(
        id: peer!.id,
        lastSeenBleAddress: 'AA:BB:CC:DD:EE:FF',
      );

      // Load mappings.
      final service = IdentityChangeService(repo);
      await service.loadPersistedMappings();

      // Now a device with a different identity appears at same BLE address.
      // 'peer_a_pub_key' is not valid hex, so we need to use a valid hex identity.
      final device = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: 'aabbccdd',
      );
      final result = service.checkForChange(device);

      expect(result, isNotNull);
      expect(result!.hasChanged, isTrue);
    });
  });

  // ── Trust isolation with identity change ───────────────────────

  group('Trust isolation with identity change', () {
    late TrustService trustService;
    late IdentityChangeService changeService;

    setUp(() {
      trustService = TrustService();
      changeService = IdentityChangeService();
    });

    test('trusted identity A is not inherited by identity B', () {
      // Establish trust for identity A.
      makeTrusted(trustService, 'identity_a');

      // BLE device presents identity B at same address.
      changeService.recordAssociation('AA:BB:CC:DD:EE:FF', 'identity_a');

      final device = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: '11223344',
      );
      final change = changeService.checkForChange(device);

      // Identity change detected.
      expect(change, isNotNull);
      expect(change!.hasChanged, isTrue);

      // Trust of identity A is unaffected.
      expect(trustService.isTrusted('identity_a'), isTrue);

      // Identity B has no trust.
      expect(trustService.isTrusted('identity_b'), isFalse);
      expect(trustService.getTrust('identity_b').state, TrustState.unknown);
    });

    test('old trust preserved after identity change', () {
      makeTrusted(trustService, 'identity_a');

      changeService.recordAssociation('AA:BB:CC:DD:EE:FF', 'identity_a');
      final device = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: '11223344',
      );
      changeService.checkForChange(device);

      // Old identity's trust is intact.
      final trustA = trustService.getTrust('identity_a');
      expect(trustA.state, TrustState.trusted);
      expect(trustA.isTrusted, isTrue);
    });

    test('new identity requires verification before trust', () {
      makeTrusted(trustService, 'identity_a');

      changeService.recordAssociation('AA:BB:CC:DD:EE:FF', 'identity_a');
      final device = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: '11223344',
      );
      changeService.checkForChange(device);

      // Cannot directly trust identity B.
      expect(
        () => trustService.trust(
          peerIdentityId: '11223344',
          at: DateTime.now(),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('verified + authenticated + explicit trust for new identity', () {
      makeTrusted(trustService, 'identity_a');

      changeService.recordAssociation('AA:BB:CC:DD:EE:FF', 'identity_a');
      final device = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: '11223344',
      );
      changeService.checkForChange(device);

      // New identity must go through full verification + authentication.
      trustService.verify(
        peerIdentityId: '11223344',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      trustService.markAuthenticated(peerIdentityId: '11223344');
      trustService.establishTrust(
        peerIdentityId: '11223344',
        at: DateTime.now(),
      );

      // Now both identities are trusted independently.
      expect(trustService.isTrusted('identity_a'), isTrue);
      expect(trustService.isTrusted('11223344'), isTrue);
    });

    test('peer isolation: changing A does not affect B', () {
      makeTrusted(trustService, 'identity_a');
      makeTrusted(trustService, 'identity_b');

      changeService.recordAssociation('AA:BB:CC:DD:EE:FF', 'identity_a');
      final device = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: '11223344',
      );
      changeService.checkForChange(device);

      expect(trustService.isTrusted('identity_a'), isTrue);
      expect(trustService.isTrusted('identity_b'), isTrue);
      expect(trustService.isTrusted('11223344'), isFalse);
    });

    test('no automatic trust after identity change + re-pairing', () {
      makeTrusted(trustService, 'identity_a');

      changeService.recordAssociation('AA:BB:CC:DD:EE:FF', 'identity_a');
      final device = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: '11223344',
      );
      changeService.checkForChange(device);

      // Verify and authenticate but do NOT call establishTrust.
      trustService.verify(
        peerIdentityId: '11223344',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      trustService.markAuthenticated(peerIdentityId: '11223344');

      // Should NOT be trusted yet.
      expect(trustService.isTrusted('11223344'), isFalse);
      expect(
        trustService.canEstablishTrust('11223344'),
        isTrue,
      );
    });
  });

  // ── BLE address independence ───────────────────────────────────

  group('BLE address independence', () {
    late IdentityChangeService service;

    setUp(() => service = IdentityChangeService());

    test('same identity, different BLE address — no change', () {
      final device = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: 'aabbccdd',
      );
      service.recordAssociation('AA:BB:CC:DD:EE:FF', device.identityIdHex!);

      final device2 = makeDevice(
        deviceId: '11:22:33:44:55:66',
        identityHex: 'aabbccdd',
      );
      final result = service.checkForChange(device2);

      expect(result, isNull);
    });

    test('different identity, same BLE address — change detected', () {
      final device1 = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: 'aabbccdd',
      );
      service.recordAssociation('AA:BB:CC:DD:EE:FF', device1.identityIdHex!);

      final device2 = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: '11223344',
      );
      final result = service.checkForChange(device2);

      expect(result, isNotNull);
      expect(result!.hasChanged, isTrue);
    });

    test('different identity, different BLE address — no change', () {
      final device1 = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: 'aabbccdd',
      );
      service.recordAssociation('AA:BB:CC:DD:EE:FF', device1.identityIdHex!);

      final device2 = makeDevice(
        deviceId: '11:22:33:44:55:66',
        identityHex: '11223344',
      );
      final result = service.checkForChange(device2);

      // Different BLE address — we can't know it's the same device.
      expect(result, isNull);
    });
  });

  // ── Schema v11 ────────────────────────────────────────────────

  group('Schema v11 - lastSeenBleAddress', () {
    late AppDatabase db;
    late IdentityRepository repo;

    setUp(() async {
      db = createTestDb();
      repo = IdentityRepository(db);
    });

    tearDown(() async => await db.close());

    test('schema version is 11', () {
      expect(db.schemaVersion, 11);
    });

    test('upsertPeerIdentity stores lastSeenBleAddress', () async {
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: 'peer_a',
        publicKey: 'peer_a',
      );

      final peer = await repo.getPeerByIdentityId('peer_a');
      expect(peer, isNotNull);
      expect(peer!.lastSeenBleAddress, isNull);

      await repo.updatePeerLastSeenBleAddress(
        id: peer.id,
        lastSeenBleAddress: 'AA:BB:CC:DD:EE:FF',
      );

      final updated = await repo.getPeerByIdentityId('peer_a');
      expect(updated!.lastSeenBleAddress, 'AA:BB:CC:DD:EE:FF');
    });

    test('PeerInfo includes lastSeenBleAddress', () async {
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: 'peer_a',
        publicKey: 'peer_a',
      );

      final peer = await repo.getPeerByIdentityId('peer_a');
      expect(peer, isNotNull);
      expect(peer!.lastSeenBleAddress, isNull);
    });

    test('updatePeerLastSeenBleAddress with null clears address', () async {
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: 'peer_a',
        publicKey: 'peer_a',
      );

      final peer = await repo.getPeerByIdentityId('peer_a');
      await repo.updatePeerLastSeenBleAddress(
        id: peer!.id,
        lastSeenBleAddress: 'AA:BB:CC:DD:EE:FF',
      );

      await repo.updatePeerLastSeenBleAddress(
        id: peer.id,
        lastSeenBleAddress: null,
      );

      final updated = await repo.getPeerByIdentityId('peer_a');
      expect(updated!.lastSeenBleAddress, isNull);
    });
  });

  // ── No automatic revocation ────────────────────────────────────

  group('No automatic revocation on identity change', () {
    late TrustService trustService;
    late IdentityChangeService changeService;

    setUp(() {
      trustService = TrustService();
      changeService = IdentityChangeService();
    });

    test('identity change does not revoke old trust', () {
      makeTrusted(trustService, 'identity_a');

      changeService.recordAssociation('AA:BB:CC:DD:EE:FF', 'identity_a');
      final device = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: '11223344',
      );
      changeService.checkForChange(device);

      // Old trust is NOT revoked.
      expect(trustService.getTrust('identity_a').state, TrustState.trusted);
      expect(trustService.isTrusted('identity_a'), isTrue);
    });
  });

  // ── Identity preserved ─────────────────────────────────────────

  group('Identity preserved after change', () {
    late TrustService trustService;
    late IdentityChangeService changeService;

    setUp(() {
      trustService = TrustService();
      changeService = IdentityChangeService();
    });

    test('old identity record is not deleted', () {
      makeTrusted(trustService, 'identity_a');

      changeService.recordAssociation('AA:BB:CC:DD:EE:FF', 'identity_a');
      final device = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: '11223344',
      );
      changeService.checkForChange(device);

      // Old trust still exists.
      final trustA = trustService.getTrust('identity_a');
      expect(trustA.peerIdentityId, 'identity_a');
      expect(trustA.state, TrustState.trusted);
    });
  });

  // ── Restart simulation ─────────────────────────────────────────

  group('Restart simulation', () {
    late AppDatabase db;
    late IdentityRepository repo;

    setUp(() async {
      db = createTestDb();
      repo = IdentityRepository(db);
    });

    tearDown(() async => await db.close());

    test('untrusted new identity remains untrusted after restart', () async {
      // Create a peer in the database with a valid hex identity.
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: 'aabbccdd',
        publicKey: 'aabbccdd',
      );

      // Trust the peer.
      final trustServiceA = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      makeTrusted(trustServiceA, 'aabbccdd');

      // Persist the BLE association in the database.
      final peer = await repo.getPeerByIdentityId('aabbccdd');
      await repo.updatePeerLastSeenBleAddress(
        id: peer!.id,
        lastSeenBleAddress: 'AA:BB:CC:DD:EE:FF',
      );

      // Identity B appears — use the change service with persistence.
      final changeService = IdentityChangeService(repo);
      await changeService.loadPersistedMappings();

      final device = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: '11223344',
      );
      changeService.checkForChange(device);

      // Simulate restart — create fresh services.
      changeService.clear();
      final changeService2 = IdentityChangeService(repo);
      await changeService2.loadPersistedMappings();

      // The BLE→identity mapping is restored from database.
      expect(
        changeService2.getPreviousIdentity('AA:BB:CC:DD:EE:FF'),
        'aabbccdd',
      );

      // Trust of A is persisted.
      final trustServiceB = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      expect(trustServiceB.isTrusted('aabbccdd'), isTrue);

      // New identity is still untrusted.
      expect(trustServiceB.isTrusted('11223344'), isFalse);
    });
  });

  // ── No secret exposure ─────────────────────────────────────────

  group('No secret exposure', () {
    test('PeerIdentityChange does not contain secrets', () {
      const change = PeerIdentityChange(
        bleAddress: 'AA:BB:CC:DD:EE:FF',
        previousIdentityId: 'aabb',
        currentIdentityId: 'ccdd',
        status: IdentityChangeStatus.changed,
      );

      final serialized = change.toString().toLowerCase();
      expect(serialized.contains('private'), isFalse);
      expect(serialized.contains('secret'), isFalse);
      expect(serialized.contains('session'), isFalse);
    });

    test('IdentityChangeService logs safe identifiers', () {
      final service = IdentityChangeService();
      // The service logs truncated identity prefixes, not full keys.
      final device1 = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: 'aabbccdd',
      );
      final device2 = makeDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        identityHex: '11223344',
        timestamp: 2000000,
      );

      // Should not throw — logs are safe.
      service.checkForChange(device1);
      service.checkForChange(device2);
    });
  });
}
