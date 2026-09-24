import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/ble/ble_uuids.dart';
import 'package:onebit/features/ble/discovered_device.dart';
import 'package:onebit/features/identity/identity_association_resolver.dart';
import 'package:onebit/features/identity/identity_export.dart';
import 'package:onebit/features/identity/identity_fingerprint.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/identity/identity_service.dart';
import 'package:onebit/features/identity/private_key_store.dart';

/// Simulated in-memory private key store for integration tests.
class InMemoryPrivateKeyStore extends PrivateKeyStore {
  InMemoryPrivateKeyStore() : super();

  final Map<String, Uint8List> _store = {};

  @override
  Future<Uint8List?> read() async => _store['onebit.identity.private_key'];

  @override
  Future<void> write(Uint8List keyBytes) async {
    _store['onebit.identity.private_key'] = keyBytes;
  }

  @override
  Future<void> delete() async {
    _store.remove('onebit.identity.private_key');
  }
}

/// Build a fake BLE scan result.
Map<String, dynamic> fakeScanResult({
  String deviceId = 'AA:BB:CC:DD:EE:FF',
  String? name,
  int rssi = -60,
  List<int>? identityKey,
}) {
  final manufacturerData = <String, dynamic>{};
  if (identityKey != null) {
    final payload = <int>[BleIdentityProtocol.protocolVersion, ...identityKey];
    final companyIdHex =
        '0x${BleIdentityProtocol.companyId.toRadixString(16)}';
    manufacturerData[companyIdHex] = payload;
  }

  return {
    'device': {
      'id': deviceId,
      'name': name,
      'addressType': 'public',
    },
    'rssiDb': rssi,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'connectable': true,
    'advertisement': {
      'localName': name,
      'txPowerLevel': 0,
      'serviceUuids': [BleUuids.oneBitService],
      'manufacturerData': manufacturerData,
      'serviceData': <String, dynamic>{},
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('I4.12 — Full identity lifecycle integration', () {
    test('create → export → import → associate → BLE resolve', () async {
      // ── Device A: Create identity ──
      final dbA = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      final repoA = IdentityRepository(dbA);
      final keyStoreA = InMemoryPrivateKeyStore();
      final serviceA = IdentityService(repoA, keyStoreA);

      final identityA = await serviceA.createIdentity('Device A');
      expect(identityA.identityId, isNotNull);
      expect(identityA.publicKeyBytes, isNotNull);

      // ── Device A: Export identity ──
      final qrPayload = await exportPublicIdentity(identityA);
      expect(qrPayload, isNotEmpty);
      final decodedPayload = jsonDecode(qrPayload) as Map<String, dynamic>;
      expect(decodedPayload['formatVersion'], 1);
      expect(decodedPayload['identityType'], 'ed25519');
      expect(decodedPayload['publicKey'], identityA.identityId);

      // ── Device A: Compute fingerprint ──
      final fingerprintA = await computeFingerprint(identityA.publicKeyBytes!);
      expect(fingerprintA, isNotEmpty);

      // ── Device B: Import identity ──
      final importResult = importPublicIdentity(
        qrPayload,
        localPublicKeyHex: null, // Device B has no identity yet
      );
      expect(importResult.isLocalIdentity, isFalse);
      expect(importResult.identity.publicKeyHex, equals(identityA.identityId));

      // ── Device B: Verify fingerprint matches ──
      final fingerprintB = await computeFingerprint(
        importResult.identity.publicKeyBytes,
      );
      expect(fingerprintB, equals(fingerprintA));

      // ── Device B: Associate as peer ──
      final dbB = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      final repoB = IdentityRepository(dbB);

      final (peer, result) = await repoB.findOrCreatePeer(
        publicIdentity: importResult.identity,
        localPublicKeyHex: 'fake_local_key_for_device_b',
      );
      expect(result, AssociationResult.created);
      expect(peer, isNotNull);
      expect(peer!.identityId, equals(identityA.identityId));
      expect(peer.displayName, equals('Device A'));

      // ── Device B: Simulate BLE discovery of Device A ──
      final discoveryController = StreamController<DiscoveredOneBitDevice>();
      final peerController = StreamController<List<PeerInfo>>.broadcast();

      final resolver = IdentityAssociationResolver(
        discoveryStream: discoveryController.stream,
        peerStream: peerController.stream,
      );

      final resolved = <ResolvedBleDevice>[];
      resolver.resolvedStream.listen(resolved.add);

      // Add peer AFTER resolver subscribes so it receives the update
      peerController.add([peer]);

      // Device A advertises its identity over BLE
      final bleDevice = DiscoveredOneBitDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        rssi: -55,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        name: 'Device A BLE',
        identityPublicKeyBytes: identityA.publicKeyBytes,
      );
      discoveryController.add(bleDevice);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // ── Verify: BLE identity resolves to same known peer ──
      expect(resolved.length, 1);
      expect(resolved.first.status, BlePeerStatus.knownPeer);
      expect(resolved.first.peer, isNotNull);
      expect(resolved.first.peer!.identityId, equals(identityA.identityId));
      expect(resolved.first.displayName, equals('Device A'));

      // ── Cleanup ──
      resolver.dispose();
      await discoveryController.close();
      await peerController.close();
      await dbA.close();
      await dbB.close();
    });

    test('unknown BLE device does not create peer', () async {
      final db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      final repo = IdentityRepository(db);

      final discoveryController = StreamController<DiscoveredOneBitDevice>();
      final peerController = StreamController<List<PeerInfo>>.broadcast();

      final resolver = IdentityAssociationResolver(
        discoveryStream: discoveryController.stream,
        peerStream: peerController.stream,
      );

      final resolved = <ResolvedBleDevice>[];
      resolver.resolvedStream.listen(resolved.add);

      // Discover an unknown device
      final unknownKey = List<int>.generate(32, (i) => (i + 50) & 0xFF);
      final bleDevice = DiscoveredOneBitDevice(
        deviceId: '11:22:33:44:55:66',
        rssi: -70,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        name: 'Unknown Device',
        identityPublicKeyBytes: unknownKey,
      );
      discoveryController.add(bleDevice);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Should be reported as unknown, NOT as a peer
      expect(resolved.length, 1);
      expect(resolved.first.status, BlePeerStatus.unknownIdentity);
      expect(resolved.first.peer, isNull);

      // Verify no peers were created in the database
      final peers = await repo.getAllPeerIdentities();
      expect(peers.length, 0);

      resolver.dispose();
      await discoveryController.close();
      await peerController.close();
      await db.close();
    });

    test('self identity is never a peer', () async {
      final db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      final repo = IdentityRepository(db);
      final keyStore = InMemoryPrivateKeyStore();
      final service = IdentityService(repo, keyStore);

      final identity = await service.createIdentity('My Device');

      // Try to associate own identity
      final publicIdentity = PublicIdentity(
        formatVersion: identityFormatVersion,
        identityType: 'ed25519',
        publicKeyHex: identity.identityId!,
        displayName: 'My Device',
      );

      final (peer, result) = await repo.findOrCreatePeer(
        publicIdentity: publicIdentity,
        localPublicKeyHex: identity.identityId!,
      );

      expect(result, AssociationResult.self);
      expect(peer, isNull);

      // Verify no peer was created
      final peers = await repo.getAllPeerIdentities();
      expect(peers.length, 0);

      await db.close();
    });

    test('peer rename does not change identity or fingerprint', () async {
      final db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      final repo = IdentityRepository(db);

      final keyHex =
          List<int>.generate(32, (i) => i).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final keyBytes = Uint8List.fromList(
        List<int>.generate(32, (i) => i),
      );

      // Create peer
      await db.upsertPeerIdentity(
        displayName: 'Original Name',
        createdAt: DateTime.now(),
        identityId: keyHex,
        publicKey: keyHex,
      );

      final peerBefore = await repo.getPeerByIdentityId(keyHex);
      expect(peerBefore, isNotNull);
      expect(peerBefore!.displayName, 'Original Name');

      // Compute fingerprint before rename
      final fingerprintBefore = await computeFingerprint(keyBytes);

      // Rename
      await repo.renamePeer(id: peerBefore.id, newName: 'New Name');

      // Verify identity unchanged
      final peerAfter = await repo.getPeerByIdentityId(keyHex);
      expect(peerAfter, isNotNull);
      expect(peerAfter!.displayName, 'New Name');
      expect(peerAfter.identityId, keyHex); // identity unchanged
      expect(peerAfter.publicKeyHex, keyHex); // public key unchanged

      // Fingerprint unchanged (derived from same key)
      final fingerprintAfter = await computeFingerprint(keyBytes);
      expect(fingerprintAfter, equals(fingerprintBefore));

      await db.close();
    });

    test('peer remove does not affect local identity', () async {
      final db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      final repo = IdentityRepository(db);
      final keyStore = InMemoryPrivateKeyStore();
      final service = IdentityService(repo, keyStore);

      // Create local identity
      final localIdentity = await service.createIdentity('My Device');
      expect(service.hasIdentity, isTrue);

      // Create a peer
      final foreignHex =
          List<int>.generate(32, (i) => (i + 100) & 0xFF)
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();
      await db.upsertPeerIdentity(
        displayName: 'Other Device',
        createdAt: DateTime.now(),
        identityId: foreignHex,
        publicKey: foreignHex,
      );

      final peer = await repo.getPeerByIdentityId(foreignHex);
      expect(peer, isNotNull);

      // Remove peer
      await repo.removePeer(peer!.id);

      // Local identity must be intact
      expect(service.hasIdentity, isTrue);
      expect(service.identityId, localIdentity.identityId);
      expect(service.publicKeyBytes, localIdentity.publicKeyBytes);

      // Peer is gone
      final peers = await repo.getAllPeerIdentities();
      expect(peers.length, 0);

      await db.close();
    });

    test('reimport after removal creates new peer', () async {
      final db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      final repo = IdentityRepository(db);

      final keyHex =
          List<int>.generate(32, (i) => i).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      // Create peer
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime.now(),
        identityId: keyHex,
        publicKey: keyHex,
      );

      var peer = await repo.getPeerByIdentityId(keyHex);
      expect(peer, isNotNull);

      // Remove peer
      await repo.removePeer(peer!.id);
      peer = await repo.getPeerByIdentityId(keyHex);
      expect(peer, isNull);

      // Reimport same identity
      final publicIdentity = PublicIdentity(
        formatVersion: identityFormatVersion,
        identityType: 'ed25519',
        publicKeyHex: keyHex,
        displayName: 'Alice v2',
      );

      final (newPeer, result) = await repo.findOrCreatePeer(
        publicIdentity: publicIdentity,
        localPublicKeyHex: 'some_other_local_key',
      );

      expect(result, AssociationResult.created);
      expect(newPeer, isNotNull);
      expect(newPeer!.identityId, keyHex);
      expect(newPeer.displayName, 'Alice v2');

      await db.close();
    });

    test('multiple peers with same display name remain distinct', () async {
      final db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      final repo = IdentityRepository(db);

      final key1 = List<int>.generate(32, (i) => i)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final key2 = List<int>.generate(32, (i) => (i + 10) & 0xFF)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

      // Two different identities with same display name
      await db.upsertPeerIdentity(
        displayName: 'Same Name',
        createdAt: DateTime.now(),
        identityId: key1,
        publicKey: key1,
      );
      await db.upsertPeerIdentity(
        displayName: 'Same Name',
        createdAt: DateTime.now(),
        identityId: key2,
        publicKey: key2,
      );

      final peers = await repo.getAllPeerIdentities();
      expect(peers.length, 2);
      expect(peers[0].identityId, isNot(equals(peers[1].identityId)));

      await db.close();
    });

    test('identity consistency across all subsystems', () async {
      final db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      final repo = IdentityRepository(db);
      final keyStore = InMemoryPrivateKeyStore();
      final service = IdentityService(repo, keyStore);

      // Create identity
      final identity = await service.createIdentity('Test Device');
      final identityId = identity.identityId!;
      final publicKeyBytes = identity.publicKeyBytes!;

      // 1. Fingerprint consistency
      final fingerprint = await computeFingerprint(publicKeyBytes);

      // 2. QR export consistency
      final qrPayload = await exportPublicIdentity(identity);
      final importResult = importPublicIdentity(qrPayload);
      expect(importResult.identity.publicKeyHex, equals(identityId));

      // 3. QR fingerprint matches
      final qrFingerprint = await computeFingerprint(
        importResult.identity.publicKeyBytes,
      );
      expect(qrFingerprint, equals(fingerprint));

      // 4. BLE payload consistency
      final blePayload = BleIdentityProtocol.buildPayload(publicKeyBytes);
      expect(blePayload, isNotNull);
      final parsedKey = BleIdentityProtocol.parsePayload(blePayload!);
      expect(parsedKey, isNotNull);
      final bleHex = parsedKey!
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      expect(bleHex, equals(identityId));

      // 5. BLE fingerprint matches
      final bleFingerprint = await computeFingerprint(
        Uint8List.fromList(parsedKey),
      );
      expect(bleFingerprint, equals(fingerprint));

      // 6. Peer association uses same identity
      final (peer, result) = await repo.findOrCreatePeer(
        publicIdentity: importResult.identity,
        localPublicKeyHex: 'foreign_key',
      );
      expect(result, AssociationResult.created);
      expect(peer!.identityId, equals(identityId));

      // 7. Peer fingerprint matches
      final peerFingerprint = await computeFingerprint(
        peer.publicKeyHex != null
            ? IdentityRepository.hexToBytes(peer.publicKeyHex!)
            : Uint8List(0),
      );
      expect(peerFingerprint, equals(fingerprint));

      await db.close();
    });
  });

  group('I4.12 — Identity stability across service instances', () {
    test('identity survives simulated restart', () async {
      final db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      final repo = IdentityRepository(db);
      final keyStore = InMemoryPrivateKeyStore();

      // First session: create identity
      final service1 = IdentityService(repo, keyStore);
      final identity = await service1.createIdentity('Persistent Device');
      final originalId = identity.identityId;
      final originalKey = Uint8List.fromList(identity.publicKeyBytes!);
      final originalFingerprint = await computeFingerprint(originalKey);

      // Simulate restart: new service instance, same storage
      final service2 = IdentityService(repo, keyStore);
      final loaded = await service2.initialize();

      expect(loaded, isTrue);
      expect(service2.identityId, originalId);
      expect(service2.publicKeyBytes, originalKey);

      // Fingerprint still matches
      final loadedFingerprint = await computeFingerprint(
        service2.publicKeyBytes!,
      );
      expect(loadedFingerprint, equals(originalFingerprint));

      // QR still matches
      final qrPayload = await exportPublicIdentity(service2.localIdentity!);
      final importResult = importPublicIdentity(qrPayload);
      expect(importResult.identity.publicKeyHex, originalId);

      await db.close();
    });

    test('concurrent initialization yields same identity', () async {
      final db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      final repo = IdentityRepository(db);
      final keyStore = InMemoryPrivateKeyStore();

      // Pre-create identity
      final setupService = IdentityService(repo, keyStore);
      await setupService.createIdentity('Concurrent Device');
      final originalId = setupService.identityId;

      // Multiple concurrent initializations
      final service = IdentityService(repo, keyStore);
      final results = await Future.wait([
        service.initialize(),
        service.initialize(),
        service.initialize(),
      ]);

      expect(results, everyElement(isTrue));
      expect(service.identityId, originalId);

      await db.close();
    });
  });

  group('I4.12 — Error handling integration', () {
    test('corrupted identity does not cause silent replacement', () async {
      final db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      final repo = IdentityRepository(db);
      final keyStore = InMemoryPrivateKeyStore();

      // Create valid identity
      final service = IdentityService(repo, keyStore);
      await service.createIdentity('Valid Device');
      final validId = service.identityId;

      // Simulate corruption: write wrong key to secure storage
      await keyStore.write(Uint8List(32)); // zeros

      // New service should fail, not replace
      final service2 = IdentityService(repo, keyStore);
      expect(
        () => service2.initialize(),
        throwsA(isA<IdentityCorruptionException>()),
      );

      // Identity should NOT have been replaced
      expect(service2.hasIdentity, isFalse);
      expect(service.identityId, validId);

      await db.close();
    });

    test('malformed QR import rejected safely', () {
      expect(
        () => importPublicIdentity('not json'),
        throwsA(isA<ImportError>()),
      );
      expect(
        () => importPublicIdentity('{}'),
        throwsA(isA<ImportError>()),
      );
      expect(
        () => importPublicIdentity('{"formatVersion":999}'),
        throwsA(isA<ImportError>()),
      );
    });

    test('malformed BLE payload rejected safely', () {
      expect(BleIdentityProtocol.parsePayload([]), isNull);
      expect(
        BleIdentityProtocol.parsePayload(List<int>.filled(10, 0)),
        isNull,
      );
      expect(
        BleIdentityProtocol.parsePayload(
          [0xFF, ...List<int>.filled(32, 1)],
        ),
        isNull,
      );
    });
  });

  group('I4.12 — No false security claims', () {
    test('BlePeerStatus has neutral values', () {
      for (final status in BlePeerStatus.values) {
        expect(status.name, isNot(contains('trust')));
        expect(status.name, isNot(contains('auth')));
        expect(status.name, isNot(contains('verified')));
        expect(status.name, isNot(contains('secure')));
      }
    });

    test('AssociationResult has neutral values', () {
      for (final result in AssociationResult.values) {
        expect(result.name, isNot(contains('trust')));
        expect(result.name, isNot(contains('auth')));
        expect(result.name, isNot(contains('verified')));
        expect(result.name, isNot(contains('secure')));
      }
    });
  });

  group('I4.12 — Private key never exposed', () {
    test('export does not contain private key', () async {
      final db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      final keyStore = InMemoryPrivateKeyStore();
      final service = IdentityService(IdentityRepository(db), keyStore);

      final identity = await service.createIdentity('Test');
      final json = await exportPublicIdentity(identity);
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded.containsKey('privateKey'), isFalse);
      expect(decoded.containsKey('private_key'), isFalse);
      expect(decoded.containsKey('seed'), isFalse);
      expect(decoded.containsKey('secret'), isFalse);

      await db.close();
    });

    test('import does not leak private key', () {
      final keyHex =
          List<int>.generate(32, (i) => i)
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();
      final payload = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': keyHex,
        'privateKey': 'should_be_ignored',
      });

      final result = importPublicIdentity(payload);
      expect(result.identity.toJson().containsKey('privateKey'), isFalse);
    });

    test('BLE payload contains only public key', () {
      final publicKey = List<int>.generate(32, (i) => i);
      final payload = BleIdentityProtocol.buildPayload(publicKey);

      expect(payload, isNotNull);
      expect(payload!.length, 33); // 1 version + 32 key
      expect(payload[0], BleIdentityProtocol.protocolVersion);
      expect(payload.sublist(1), publicKey);
      // No private key material in the payload
    });
  });
}
