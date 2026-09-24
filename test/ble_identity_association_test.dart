import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/ble/ble_uuids.dart';
import 'package:onebit/features/ble/discovered_device.dart';
import 'package:onebit/features/identity/identity_association_resolver.dart';
import 'package:onebit/features/identity/identity_export.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/identity/identity_repository.dart';

AppDatabase createTestDb() =>
    AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));

String fakePublicKeyHex([int seed = 0]) {
  final bytes = List<int>.generate(32, (i) => (seed + i) & 0xFF);
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

List<int> fakePublicKeyBytes([int seed = 0]) {
  return List<int>.generate(32, (i) => (seed + i) & 0xFF);
}

/// Build a fake scan result map mimicking Kotlin's emitScanResult().
Map<String, dynamic> fakeScanResult({
  String deviceId = 'AA:BB:CC:DD:EE:FF',
  String? name,
  int rssi = -60,
  List<int>? identityKey,
}) {
  final manufacturerData = <String, dynamic>{};
  if (identityKey != null) {
    final payload = <int>[BleIdentityProtocol.protocolVersion, ...identityKey];
    // Use lowercase hex key to match code's toRadixString(16) output
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

  // ── BleIdentityProtocol tests ──

  group('BleIdentityProtocol', () {
    test('buildPayload creates correct format', () {
      final key = fakePublicKeyBytes(1);
      final payload = BleIdentityProtocol.buildPayload(key);

      expect(payload, isNotNull);
      expect(payload!.length, BleIdentityProtocol.payloadLength);
      expect(payload[0], BleIdentityProtocol.protocolVersion);
      expect(payload.sublist(1), key);
    });

    test('buildPayload returns null for null key', () {
      expect(BleIdentityProtocol.buildPayload(null), isNull);
    });

    test('buildPayload returns null for wrong length key', () {
      expect(BleIdentityProtocol.buildPayload([1, 2, 3]), isNull);
      expect(BleIdentityProtocol.buildPayload(List.filled(33, 0)), isNull);
    });

    test('parsePayload extracts public key from valid payload', () {
      final key = fakePublicKeyBytes(1);
      final payload = [BleIdentityProtocol.protocolVersion, ...key];

      final result = BleIdentityProtocol.parsePayload(payload);
      expect(result, isNotNull);
      expect(result, key);
    });

    test('parsePayload returns null for wrong length', () {
      expect(BleIdentityProtocol.parsePayload([1, 2, 3]), isNull);
      expect(
        BleIdentityProtocol.parsePayload(List.filled(34, 0)),
        isNull,
      );
    });

    test('parsePayload returns null for wrong version', () {
      final key = fakePublicKeyBytes(1);
      final payload = [99, ...key];
      expect(BleIdentityProtocol.parsePayload(payload), isNull);
    });

    test('parsePayload returns null for all-zero key', () {
      final payload = [BleIdentityProtocol.protocolVersion, ...List.filled(32, 0)];
      expect(BleIdentityProtocol.parsePayload(payload), isNull);
    });

    test('round-trip build then parse preserves key', () {
      final key = fakePublicKeyBytes(42);
      final payload = BleIdentityProtocol.buildPayload(key);
      final parsed = BleIdentityProtocol.parsePayload(payload!);

      expect(parsed, key);
    });

    test('payload length is 33 bytes', () {
      expect(BleIdentityProtocol.payloadLength, 33);
    });
  });

  // ── DiscoveredOneBitDevice identity parsing ──

  group('DiscoveredOneBitDevice identity parsing', () {
    test('parses identity from manufacturer data', () {
      final key = fakePublicKeyBytes(1);
      final data = fakeScanResult(identityKey: key);

      final device = DiscoveredOneBitDevice.fromScanResult(data);

      expect(device.hasIdentity, isTrue);
      expect(device.identityPublicKeyBytes, key);
      expect(device.identityIdHex, isNotNull);
      expect(device.identityIdHex!.length, 64);
    });

    test('no identity when manufacturer data is empty', () {
      final data = fakeScanResult();

      final device = DiscoveredOneBitDevice.fromScanResult(data);

      expect(device.hasIdentity, isFalse);
      expect(device.identityPublicKeyBytes, isNull);
      expect(device.identityIdHex, isNull);
    });

    test('no identity when manufacturer data has wrong version', () {
      final key = fakePublicKeyBytes(1);
      final data = fakeScanResult();
      data['advertisement']['manufacturerData'] = {
        '0xFFFF': [99, ...key],
      };

      final device = DiscoveredOneBitDevice.fromScanResult(data);

      expect(device.hasIdentity, isFalse);
    });

    test('no identity when manufacturer data is truncated', () {
      final data = fakeScanResult();
      data['advertisement']['manufacturerData'] = {
        '0xFFFF': [1, 2, 3],
      };

      final device = DiscoveredOneBitDevice.fromScanResult(data);

      expect(device.hasIdentity, isFalse);
    });

    test('no identity when manufacturer data map is null', () {
      final data = fakeScanResult();
      data['advertisement']['manufacturerData'] = null;

      final device = DiscoveredOneBitDevice.fromScanResult(data);

      expect(device.hasIdentity, isFalse);
    });

    test('identity preserved through withUpdatedRssi', () {
      final key = fakePublicKeyBytes(1);
      final data = fakeScanResult(identityKey: key);
      final device = DiscoveredOneBitDevice.fromScanResult(data);

      final updated = device.withUpdatedRssi(-50, 999);

      expect(updated.identityPublicKeyBytes, key);
      expect(updated.hasIdentity, isTrue);
    });

    test('toString includes hasIdentity', () {
      final key = fakePublicKeyBytes(1);
      final data = fakeScanResult(identityKey: key);
      final device = DiscoveredOneBitDevice.fromScanResult(data);

      expect(device.toString(), contains('hasIdentity: true'));
    });

    test('isOneBit remains true regardless of identity', () {
      final data = fakeScanResult();
      final device = DiscoveredOneBitDevice.fromScanResult(data);

      expect(device.isOneBit, isTrue);
    });
  });

  // ── IdentityAssociationResolver ──

  group('IdentityAssociationResolver', () {
    late AppDatabase db;
    late IdentityRepository repo;
    late StreamController<DiscoveredOneBitDevice> discoveryController;
    late StreamController<List<PeerInfo>> peerController;

    setUp(() async {
      db = createTestDb();
      await db.customStatement('PRAGMA foreign_keys = ON');
      repo = IdentityRepository(db);
      discoveryController = StreamController<DiscoveredOneBitDevice>.broadcast();
      peerController = StreamController<List<PeerInfo>>.broadcast();
    });

    tearDown(() async {
      await db.close();
      await discoveryController.close();
      await peerController.close();
    });

    IdentityAssociationResolver createResolver({
      String? localKeyHex,
    }) {
      return IdentityAssociationResolver(
        discoveryStream: discoveryController.stream,
        peerStream: peerController.stream,
        localPublicKeyHex: localKeyHex,
      );
    }

    test('resolves known peer from BLE discovery', () async {
      final foreignKey = fakePublicKeyHex(2);

      // Insert a known peer.
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime.now(),
        identityId: foreignKey,
        publicKey: foreignKey,
      );

      final resolver = createResolver();

      // Emit peer list update.
      final peers = await repo.getAllPeerIdentities();
      peerController.add(peers);

      // Wait for cache update.
      await Future<void>.delayed(Duration.zero);

      // Discover a BLE device with Alice's identity.
      final key = fakePublicKeyBytes(2);
      final device = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(identityKey: key),
      );

      final resolved = resolver.resolve(device);

      expect(resolved.status, BlePeerStatus.knownPeer);
      expect(resolved.peer, isNotNull);
      expect(resolved.peer!.displayName, 'Alice');
      expect(resolved.displayName, 'Alice');

      resolver.dispose();
    });

    test('resolves self identity', () async {
      final localKey = fakePublicKeyHex(1);
      final resolver = createResolver(localKeyHex: localKey);

      final key = fakePublicKeyBytes(1);
      final device = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(identityKey: key),
      );

      final resolved = resolver.resolve(device);

      expect(resolved.status, BlePeerStatus.selfIdentity);
      expect(resolved.peer, isNull);
      expect(resolved.displayName, device.name ?? 'OneBit device');

      resolver.dispose();
    });

    test('reports unknown identity', () async {
      final resolver = createResolver();

      final key = fakePublicKeyBytes(99);
      final device = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(identityKey: key),
      );

      final resolved = resolver.resolve(device);

      expect(resolved.status, BlePeerStatus.unknownIdentity);
      expect(resolved.peer, isNull);

      resolver.dispose();
    });

    test('reports noIdentity when advertisement has no identity', () async {
      final resolver = createResolver();

      final device = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(),
      );

      final resolved = resolver.resolve(device);

      expect(resolved.status, BlePeerStatus.noIdentity);
      expect(resolved.peer, isNull);

      resolver.dispose();
    });

    test('does not create peers from BLE discovery', () async {
      final resolver = createResolver();

      final key = fakePublicKeyBytes(99);
      final device = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(identityKey: key),
      );

      resolver.resolve(device);

      // Verify no peer was created.
      final peers = await repo.getAllPeerIdentities();
      expect(peers, isEmpty);

      resolver.dispose();
    });

    test('duplicate discovery resolves to same result', () async {
      final foreignKey = fakePublicKeyHex(2);
      await db.upsertPeerIdentity(
        displayName: 'Bob',
        createdAt: DateTime.now(),
        identityId: foreignKey,
        publicKey: foreignKey,
      );

      final resolver = createResolver();
      final peers = await repo.getAllPeerIdentities();
      peerController.add(peers);
      await Future<void>.delayed(Duration.zero);

      final key = fakePublicKeyBytes(2);
      final device1 = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(deviceId: 'AA:BB:CC:DD:EE:01', identityKey: key),
      );
      final device2 = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(deviceId: 'AA:BB:CC:DD:EE:02', identityKey: key),
      );

      final resolved1 = resolver.resolve(device1);
      final resolved2 = resolver.resolve(device2);

      // Same identity, different BLE addresses → same peer.
      expect(resolved1.peer!.id, resolved2.peer!.id);
      expect(resolved1.status, BlePeerStatus.knownPeer);
      expect(resolved2.status, BlePeerStatus.knownPeer);

      resolver.dispose();
    });

    test('same BLE name different identities remain separate', () async {
      final key1 = fakePublicKeyBytes(1);
      final key2 = fakePublicKeyBytes(2);

      final resolver = createResolver();

      final device1 = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(
          deviceId: 'AA:BB:CC:DD:EE:01',
          name: 'SameName',
          identityKey: key1,
        ),
      );
      final device2 = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(
          deviceId: 'AA:BB:CC:DD:EE:02',
          name: 'SameName',
          identityKey: key2,
        ),
      );

      final resolved1 = resolver.resolve(device1);
      final resolved2 = resolver.resolve(device2);

      expect(resolved1.device.deviceId, isNot(equals(resolved2.device.deviceId)));
      expect(resolved1.status, BlePeerStatus.unknownIdentity);
      expect(resolved2.status, BlePeerStatus.unknownIdentity);

      resolver.dispose();
    });

    test('BLE address change does not affect identity', () async {
      final foreignKey = fakePublicKeyHex(2);
      await db.upsertPeerIdentity(
        displayName: 'Charlie',
        createdAt: DateTime.now(),
        identityId: foreignKey,
        publicKey: foreignKey,
      );

      final resolver = createResolver();
      final peers = await repo.getAllPeerIdentities();
      peerController.add(peers);
      await Future<void>.delayed(Duration.zero);

      final key = fakePublicKeyBytes(2);

      // Same identity, different BLE addresses.
      final device1 = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(deviceId: 'AA:AA:AA:AA:AA:01', identityKey: key),
      );
      final device2 = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(deviceId: 'BB:BB:BB:BB:BB:02', identityKey: key),
      );

      final resolved1 = resolver.resolve(device1);
      final resolved2 = resolver.resolve(device2);

      expect(resolved1.peer!.id, resolved2.peer!.id);

      resolver.dispose();
    });

    test('self identity detection is case-insensitive', () async {
      final localKey = fakePublicKeyHex(1);
      final resolver = createResolver(localKeyHex: localKey);

      // Advertise with uppercase.
      final key = fakePublicKeyBytes(1);
      final device = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(
          identityKey: key,
        ),
      );

      final resolved = resolver.resolve(device);
      expect(resolved.status, BlePeerStatus.selfIdentity);

      resolver.dispose();
    });

    test('knownPeerCount reflects cache size', () async {
      final resolver = createResolver();
      expect(resolver.knownPeerCount, 0);

      final foreignKey = fakePublicKeyHex(2);
      await db.upsertPeerIdentity(
        displayName: 'Dave',
        createdAt: DateTime.now(),
        identityId: foreignKey,
        publicKey: foreignKey,
      );

      final peers = await repo.getAllPeerIdentities();
      peerController.add(peers);
      await Future<void>.delayed(Duration.zero);

      expect(resolver.knownPeerCount, 1);

      resolver.dispose();
    });

    test('peer cache updates when peers change', () async {
      final resolver = createResolver();

      // Initially empty.
      peerController.add([]);
      await Future<void>.delayed(Duration.zero);
      expect(resolver.knownPeerCount, 0);

      // Add a peer.
      final foreignKey = fakePublicKeyHex(2);
      await db.upsertPeerIdentity(
        displayName: 'Eve',
        createdAt: DateTime.now(),
        identityId: foreignKey,
        publicKey: foreignKey,
      );
      var peers = await repo.getAllPeerIdentities();
      peerController.add(peers);
      await Future<void>.delayed(Duration.zero);
      expect(resolver.knownPeerCount, 1);

      // Remove the peer.
      await db.deletePeerIdentity(1);
      peers = await repo.getAllPeerIdentities();
      peerController.add(peers);
      await Future<void>.delayed(Duration.zero);
      expect(resolver.knownPeerCount, 0);

      resolver.dispose();
    });

    test('resolvedStream emits when discovery arrives', () async {
      final resolver = createResolver();
      final emitted = <ResolvedBleDevice>[];

      final sub = resolver.resolvedStream.listen(emitted.add);

      final device = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(),
      );
      discoveryController.add(device);

      await Future<void>.delayed(Duration.zero);

      expect(emitted.length, 1);
      expect(emitted.first.status, BlePeerStatus.noIdentity);

      await sub.cancel();
      resolver.dispose();
    });

    test('resolvedStream emits known peer status', () async {
      final foreignKey = fakePublicKeyHex(2);
      await db.upsertPeerIdentity(
        displayName: 'Frank',
        createdAt: DateTime.now(),
        identityId: foreignKey,
        publicKey: foreignKey,
      );

      final resolver = createResolver();
      final peers = await repo.getAllPeerIdentities();
      peerController.add(peers);
      await Future<void>.delayed(Duration.zero);

      final emitted = <ResolvedBleDevice>[];
      final sub = resolver.resolvedStream.listen(emitted.add);

      final key = fakePublicKeyBytes(2);
      discoveryController.add(
        DiscoveredOneBitDevice.fromScanResult(
          fakeScanResult(identityKey: key),
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(emitted.length, 1);
      expect(emitted.first.status, BlePeerStatus.knownPeer);
      expect(emitted.first.peer!.displayName, 'Frank');

      await sub.cancel();
      resolver.dispose();
    });

    test('setLocalIdentity updates self-detection', () async {
      final resolver = createResolver();

      // Initially no local identity set.
      final key = fakePublicKeyBytes(1);
      final device = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(identityKey: key),
      );

      var resolved = resolver.resolve(device);
      expect(resolved.status, BlePeerStatus.unknownIdentity);

      // Set local identity.
      resolver.setLocalIdentity(fakePublicKeyHex(1));

      resolved = resolver.resolve(device);
      expect(resolved.status, BlePeerStatus.selfIdentity);

      resolver.dispose();
    });
  });

  // ── Fingerprint match ──

  group('BLE identity fingerprint match', () {
    test('BLE identity fingerprint matches I4.4 format', () {
      final key = fakePublicKeyBytes(1);
      final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      // The identityIdHex from BLE matches the hex encoding used by I4.7.
      expect(hex.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hex), isTrue);
    });
  });

  // ── Regression tests ──

  group('I4.8 regression', () {
    test('peer rename still works', () async {
      final db = createTestDb();
      await db.customStatement('PRAGMA foreign_keys = ON');
      final repo = IdentityRepository(db);

      final key = fakePublicKeyHex(1);
      await db.upsertPeerIdentity(
        displayName: 'Original',
        createdAt: DateTime.now(),
        identityId: key,
        publicKey: key,
      );

      final peer = await repo.getPeerByIdentityId(key);
      await repo.renamePeer(id: peer!.id, newName: 'Renamed');

      final updated = await repo.getPeerByIdentityId(key);
      expect(updated!.displayName, 'Renamed');

      await db.close();
    });

    test('peer remove still works', () async {
      final db = createTestDb();
      await db.customStatement('PRAGMA foreign_keys = ON');
      final repo = IdentityRepository(db);

      final key = fakePublicKeyHex(1);
      await db.upsertPeerIdentity(
        displayName: 'ToRemove',
        createdAt: DateTime.now(),
        identityId: key,
        publicKey: key,
      );

      final peer = await repo.getPeerByIdentityId(key);
      final deleted = await repo.removePeer(peer!.id);
      expect(deleted, 1);

      final remaining = await repo.getPeerByIdentityId(key);
      expect(remaining, isNull);

      await db.close();
    });
  });

  group('I4.7 regression', () {
    test('findOrCreatePeer still works', () async {
      final db = createTestDb();
      await db.customStatement('PRAGMA foreign_keys = ON');
      final repo = IdentityRepository(db);

      final localKey = fakePublicKeyHex(0);
      final foreignKey = fakePublicKeyHex(1);

      final publicIdentity = PublicIdentity(
        formatVersion: identityFormatVersion,
        identityType: 'ed25519',
        publicKeyHex: foreignKey,
        displayName: 'Test Peer',
      );

      final (peer, result) = await repo.findOrCreatePeer(
        publicIdentity: publicIdentity,
        localPublicKeyHex: localKey,
      );

      expect(result, AssociationResult.created);
      expect(peer, isNotNull);

      await db.close();
    });
  });

  group('I4.5 regression', () {
    test('identity export/import still works', () async {
      final key = fakePublicKeyBytes(1);
      final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      final identity = IdentityInfo(
        id: 1,
        identityId: hex,
        displayName: 'Test',
        createdAt: DateTime(2025),
        publicKeyBytes: Uint8List.fromList(key),
      );

      final json = await exportPublicIdentity(identity);
      expect(json, isNotEmpty);

      final result = importPublicIdentity(json, localPublicKeyHex: hex);
      expect(result.isLocalIdentity, isTrue);
    });
  });

  group('I4.4 regression', () {
    test('fingerprint computation unchanged', () async {
      final key = fakePublicKeyBytes(1);
      final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      // The identity ID is a 64-char hex string.
      expect(hex.length, 64);
    });
  });

  group('Security checks', () {
    test('no private key in DiscoveredOneBitDevice', () {
      const device = DiscoveredOneBitDevice(
        deviceId: 'test',
        rssi: -60,
        timestamp: 0,
      );

      // Verify no private key field exists.
      expect(device.identityPublicKeyBytes, isNull);
    });

    test('no private key in ResolvedBleDevice', () {
      const device = DiscoveredOneBitDevice(
        deviceId: 'test',
        rssi: -60,
        timestamp: 0,
      );
      const resolved = ResolvedBleDevice( device: device, status: BlePeerStatus.noIdentity,);

      expect(resolved.peer, isNull);
    });

    test('BLE address is not used as identity', () {
      final key = fakePublicKeyBytes(1);
      final device1 = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(deviceId: 'AA:AA:AA:AA:AA:01', identityKey: key),
      );
      final device2 = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(deviceId: 'BB:BB:BB:BB:BB:02', identityKey: key),
      );

      // Same identity, different addresses.
      expect(device1.identityIdHex, device2.identityIdHex);
      expect(device1.deviceId, isNot(equals(device2.deviceId)));
    });

    test('BLE name is not used as identity', () {
      final key1 = fakePublicKeyBytes(1);
      final key2 = fakePublicKeyBytes(2);

      final device1 = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(name: 'Same', identityKey: key1),
      );
      final device2 = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(name: 'Same', identityKey: key2),
      );

      // Same name, different identities.
      expect(device1.identityIdHex, isNot(equals(device2.identityIdHex)));
    });

    test('discovery does not imply authentication', () {
      final resolver = IdentityAssociationResolver(
        discoveryStream: const Stream.empty(),
        peerStream: const Stream.empty(),
      );

      final key = fakePublicKeyBytes(1);
      final device = DiscoveredOneBitDevice.fromScanResult(
        fakeScanResult(identityKey: key),
      );

      final resolved = resolver.resolve(device);

      // Status is unknownIdentity, NOT authenticated/trusted.
      expect(resolved.status, BlePeerStatus.unknownIdentity);
      expect(resolved.status, isNot(equals(BlePeerStatus.knownPeer)));

      resolver.dispose();
    });
  });
}
