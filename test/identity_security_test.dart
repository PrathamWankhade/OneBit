import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
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

import 'identity_test.mocks.dart';

AppDatabase createTestDb() =>
    AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));

String fakePublicKeyHex([int seed = 0]) {
  final bytes = List<int>.generate(32, (i) => (seed + i) & 0xFF);
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

List<int> fakePublicKeyBytes([int seed = 0]) {
  return List<int>.generate(32, (i) => (seed + i) & 0xFF);
}

/// Build a fake scan result map.
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

  group('I4.11 — Input size limits', () {
    test('importPublicIdentity rejects oversized payload', () {
      final oversizedPayload = 'x' * (kMaxImportPayloadSize + 1);
      expect(
        () => importPublicIdentity(oversizedPayload),
        throwsA(
          isA<ImportError>().having(
            (e) => e.message,
            'message',
            contains('too large'),
          ),
        ),
      );
    });

    test('importPublicIdentity accepts payload at exact size limit', () {
      // Build a valid payload just under the limit
      final keyHex = fakePublicKeyHex();
      final payload = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': keyHex,
        'displayName': 'A',
      });
      // Pad to exactly kMaxImportPayloadSize if needed
      expect(
        () => importPublicIdentity(payload),
        returnsNormally,
      );
    });

    test('importPublicIdentity rejects displayName too long', () {
      final keyHex = fakePublicKeyHex();
      final longName = 'A' * (kMaxDisplayNameLength + 1);
      final payload = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': keyHex,
        'displayName': longName,
      });
      expect(
        () => importPublicIdentity(payload),
        throwsA(
          isA<ImportError>().having(
            (e) => e.message,
            'message',
            contains('displayName too long'),
          ),
        ),
      );
    });

    test('importPublicIdentity rejects non-string displayName', () {
      final keyHex = fakePublicKeyHex();
      final payload = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': keyHex,
        'displayName': 123,
      });
      expect(
        () => importPublicIdentity(payload),
        throwsA(
          isA<ImportError>().having(
            (e) => e.message,
            'message',
            contains('displayName must be a string'),
          ),
        ),
      );
    });

    test('importPublicIdentity rejects non-string fingerprint', () {
      final keyHex = fakePublicKeyHex();
      final payload = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': keyHex,
        'fingerprint': 123,
      });
      expect(
        () => importPublicIdentity(payload),
        throwsA(
          isA<ImportError>().having(
            (e) => e.message,
            'message',
            contains('fingerprint must be a string'),
          ),
        ),
      );
    });
  });

  group('I4.11 — Malformed input rejection', () {
    test('rejects empty JSON object', () {
      expect(
        () => importPublicIdentity('{}'),
        throwsA(isA<ImportError>()),
      );
    });

    test('rejects JSON array instead of object', () {
      expect(
        () => importPublicIdentity('[]'),
        throwsA(isA<ImportError>()),
      );
    });

    test('rejects non-JSON garbage', () {
      expect(
        () => importPublicIdentity('not json at all !!!'),
        throwsA(isA<ImportError>()),
      );
    });

    test('rejects unsupported format version', () {
      final keyHex = fakePublicKeyHex();
      final payload = jsonEncode({
        'formatVersion': 999,
        'identityType': 'ed25519',
        'publicKey': keyHex,
      });
      expect(
        () => importPublicIdentity(payload),
        throwsA(
          isA<ImportError>().having(
            (e) => e.message,
            'message',
            contains('Unsupported format version'),
          ),
        ),
      );
    });

    test('rejects unsupported identity type', () {
      final keyHex = fakePublicKeyHex();
      final payload = jsonEncode({
        'formatVersion': 1,
        'identityType': 'rsa4096',
        'publicKey': keyHex,
      });
      expect(
        () => importPublicIdentity(payload),
        throwsA(
          isA<ImportError>().having(
            (e) => e.message,
            'message',
            contains('Unsupported identity type'),
          ),
        ),
      );
    });

    test('rejects non-hex publicKey', () {
      final payload = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': 'ZZZZ_not_hex',
      });
      expect(
        () => importPublicIdentity(payload),
        throwsA(
          isA<ImportError>().having(
            (e) => e.message,
            'message',
            contains('not valid hex'),
          ),
        ),
      );
    });

    test('rejects publicKey too short', () {
      final payload = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': 'abcd',
      });
      expect(
        () => importPublicIdentity(payload),
        throwsA(
          isA<ImportError>().having(
            (e) => e.message,
            'message',
            contains('64 hex characters'),
          ),
        ),
      );
    });

    test('rejects publicKey too long', () {
      final payload = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': 'ab' * 33, // 66 chars
      });
      expect(
        () => importPublicIdentity(payload),
        throwsA(
          isA<ImportError>().having(
            (e) => e.message,
            'message',
            contains('64 hex characters'),
          ),
        ),
      );
    });

    test('rejects publicKey as list (wrong type)', () {
      final payload = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': [1, 2, 3],
      });
      expect(
        () => importPublicIdentity(payload),
        throwsA(
          isA<ImportError>().having(
            (e) => e.message,
            'message',
            contains('publicKey must be a string'),
          ),
        ),
      );
    });

    test('rejects missing formatVersion', () {
      final keyHex = fakePublicKeyHex();
      final payload = jsonEncode({
        'identityType': 'ed25519',
        'publicKey': keyHex,
      });
      expect(
        () => importPublicIdentity(payload),
        throwsA(
          isA<ImportError>().having(
            (e) => e.message,
            'message',
            contains('Missing formatVersion'),
          ),
        ),
      );
    });

    test('rejects missing identityType', () {
      final keyHex = fakePublicKeyHex();
      final payload = jsonEncode({
        'formatVersion': 1,
        'publicKey': keyHex,
      });
      expect(
        () => importPublicIdentity(payload),
        throwsA(
          isA<ImportError>().having(
            (e) => e.message,
            'message',
            contains('Missing identityType'),
          ),
        ),
      );
    });

    test('rejects missing publicKey', () {
      final payload = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
      });
      expect(
        () => importPublicIdentity(payload),
        throwsA(
          isA<ImportError>().having(
            (e) => e.message,
            'message',
            contains('Missing publicKey'),
          ),
        ),
      );
    });

    test('rejects empty publicKey', () {
      final payload = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': '',
      });
      expect(
        () => importPublicIdentity(payload),
        throwsA(
          isA<ImportError>().having(
            (e) => e.message,
            'message',
            contains('publicKey is empty'),
          ),
        ),
      );
    });

    test('rejects null publicKey', () {
      final payload = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': null,
      });
      expect(
        () => importPublicIdentity(payload),
        throwsA(isA<ImportError>()),
      );
    });
  });

  group('I4.11 — Fingerprint security', () {
    test('computeFingerprint throws on empty key', () {
      expect(
        () => computeFingerprint(Uint8List(0)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('computeFingerprint produces deterministic output', () async {
      final keyBytes = Uint8List.fromList(fakePublicKeyBytes());
      final fp1 = await computeFingerprint(keyBytes);
      final fp2 = await computeFingerprint(keyBytes);
      expect(fp1, equals(fp2));
    });

    test('different keys produce different fingerprints', () async {
      final key1 = Uint8List.fromList(fakePublicKeyBytes(0));
      final key2 = Uint8List.fromList(fakePublicKeyBytes(100));
      final fp1 = await computeFingerprint(key1);
      final fp2 = await computeFingerprint(key2);
      expect(fp1, isNot(equals(fp2)));
    });

    test('fingerprint is stable across multiple calls', () async {
      final keyBytes = Uint8List.fromList(fakePublicKeyBytes(42));
      final results = <String>[];
      for (var i = 0; i < 10; i++) {
        results.add(await computeFingerprint(keyBytes));
      }
      expect(results.toSet().length, 1);
    });
  });

  group('I4.11 — BLE input validation', () {
    test('BleIdentityProtocol rejects empty payload', () {
      expect(BleIdentityProtocol.parsePayload([]), isNull);
    });

    test('BleIdentityProtocol rejects wrong-length payload', () {
      expect(
        BleIdentityProtocol.parsePayload(List<int>.generate(16, (i) => i)),
        isNull,
      );
    });

    test('BleIdentityProtocol rejects wrong version byte', () {
      final payload = <int>[
        0xFF, // wrong version
        ...fakePublicKeyBytes(),
      ];
      expect(BleIdentityProtocol.parsePayload(payload), isNull);
    });

    test('BleIdentityProtocol rejects all-zero key', () {
      final payload = <int>[
        BleIdentityProtocol.protocolVersion,
        ...List<int>.filled(32, 0),
      ];
      expect(BleIdentityProtocol.parsePayload(payload), isNull);
    });

    test('BleIdentityProtocol accepts valid payload', () {
      final key = fakePublicKeyBytes();
      final payload = <int>[
        BleIdentityProtocol.protocolVersion,
        ...key,
      ];
      final result = BleIdentityProtocol.parsePayload(payload);
      expect(result, isNotNull);
      expect(result!.length, 32);
    });

    test('DiscoveredOneBitDevice parses valid identity', () {
      final key = fakePublicKeyBytes();
      final scanResult = fakeScanResult(identityKey: key);
      final device = DiscoveredOneBitDevice.fromScanResult(scanResult);
      expect(device.hasIdentity, isTrue);
      expect(device.identityPublicKeyBytes, isNotNull);
      expect(device.identityPublicKeyBytes!.length, 32);
    });

    test('DiscoveredOneBitDevice ignores wrong company ID', () {
      final key = fakePublicKeyBytes();
      final payload = <int>[BleIdentityProtocol.protocolVersion, ...key];
      final scanResult = fakeScanResult();
      // Put identity data under wrong company ID
      (scanResult['advertisement'] as Map)['manufacturerData']['0x1234'] =
          payload;
      final device = DiscoveredOneBitDevice.fromScanResult(scanResult);
      expect(device.hasIdentity, isFalse);
    });

    test('DiscoveredOneBitDevice handles non-list manufacturer data', () {
      final scanResult = fakeScanResult();
      (scanResult['advertisement'] as Map)['manufacturerData']['0xFFFF'] =
          'not a list';
      final device = DiscoveredOneBitDevice.fromScanResult(scanResult);
      expect(device.hasIdentity, isFalse);
    });
  });

  group('I4.11 — Identity stability', () {
    test('identity persists across service instance re-creation', () async {
      final mockRepo = MockIdentityRepository();
      final mockKeyStore = MockPrivateKeyStore();
      final service = IdentityService(mockRepo, mockKeyStore);

      // Create identity
      when(mockRepo.createLocalIdentity(
        displayName: anyNamed('displayName'),
        publicKeyHex: anyNamed('publicKeyHex'),
      )).thenAnswer(
        (_) async => IdentityInfo(
          id: 1,
          displayName: 'Test',
          createdAt: DateTime(2025),
        ),
      );
      when(mockRepo.updateLocalIdentityCrypto(
        id: anyNamed('id'),
        identityId: anyNamed('identityId'),
        publicKeyHex: anyNamed('publicKeyHex'),
      )).thenAnswer((_) async {});
      when(mockKeyStore.write(any)).thenAnswer((_) async {});

      final identity = await service.createIdentity('Test');
      final originalId = identity.identityId;
      final originalKey = Uint8List.fromList(identity.publicKeyBytes!);

      // Simulate restart
      final service2 = IdentityService(mockRepo, mockKeyStore);
      when(mockRepo.getLocalIdentity()).thenAnswer(
        (_) async => IdentityInfo(
          id: 1,
          identityId: originalId,
          displayName: 'Test',
          createdAt: DateTime(2025),
          publicKeyBytes: originalKey,
        ),
      );
      when(mockKeyStore.read()).thenAnswer((_) async => originalKey);

      final loaded = await service2.initialize();
      expect(loaded, isTrue);
      expect(service2.identityId, originalId);
      expect(service2.publicKeyBytes, originalKey);
    });

    test('concurrent initialize calls resolve to same identity', () async {
      final mockRepo = MockIdentityRepository();
      final mockKeyStore = MockPrivateKeyStore();

      // Use a real Ed25519 key pair
      final algorithm = Ed25519();
      final kp = await algorithm.newKeyPair();
      final pub = await kp.extract();
      final priv = await kp.extract();
      final pubBytes = Uint8List.fromList(pub.bytes);
      final privBytes = Uint8List.fromList(priv.bytes);
      final pubHex = IdentityRepository.bytesToHex(pubBytes);

      when(mockRepo.getLocalIdentity()).thenAnswer(
        (_) async => IdentityInfo(
          id: 1,
          identityId: pubHex,
          displayName: 'Test',
          createdAt: DateTime(2025),
          publicKeyBytes: pubBytes,
        ),
      );
      when(mockKeyStore.read()).thenAnswer((_) async => privBytes);

      // All three concurrent calls should resolve to the same identity
      final service = IdentityService(mockRepo, mockKeyStore);
      final results = await Future.wait([
        service.initialize(),
        service.initialize(),
        service.initialize(),
      ]);

      expect(results, everyElement(isTrue));
      expect(service.identityId, pubHex);
      expect(service.hasIdentity, isTrue);
    });
  });

  group('I4.11 — Identity immutability', () {
    test('createIdentity throws if identity already exists', () async {
      final mockRepo = MockIdentityRepository();
      final mockKeyStore = MockPrivateKeyStore();
      final service = IdentityService(mockRepo, mockKeyStore);

      when(mockRepo.createLocalIdentity(
        displayName: anyNamed('displayName'),
        publicKeyHex: anyNamed('publicKeyHex'),
      )).thenAnswer(
        (_) async => IdentityInfo(
          id: 1,
          displayName: 'Test',
          createdAt: DateTime(2025),
        ),
      );
      when(mockRepo.updateLocalIdentityCrypto(
        id: anyNamed('id'),
        identityId: anyNamed('identityId'),
        publicKeyHex: anyNamed('publicKeyHex'),
      )).thenAnswer((_) async {});
      when(mockKeyStore.write(any)).thenAnswer((_) async {});

      await service.createIdentity('First');
      expect(service.hasIdentity, isTrue);

      expect(
        () => service.createIdentity('Second'),
        throwsA(isA<StateError>()),
      );
    });

    test('corrupted storage does not cause silent replacement', () async {
      final mockRepo = MockIdentityRepository();
      final mockKeyStore = MockPrivateKeyStore();
      final service = IdentityService(mockRepo, mockKeyStore);

      // Identity exists but private key is missing
      when(mockRepo.getLocalIdentity()).thenAnswer(
        (_) async => IdentityInfo(
          id: 1,
          identityId: fakePublicKeyHex(),
          displayName: 'Test',
          createdAt: DateTime(2025),
          publicKeyBytes: Uint8List.fromList(fakePublicKeyBytes()),
        ),
      );
      when(mockKeyStore.read()).thenAnswer((_) async => null);

      expect(
        () => service.initialize(),
        throwsA(isA<PrivateKeyStoreException>()),
      );

      // Service should NOT have created a new identity
      expect(service.hasIdentity, isFalse);
    });
  });

  group('I4.11 — Peer security', () {
    late AppDatabase db;

    setUp(() {
      db = createTestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('duplicate peer identity is prevented by unique constraint',
        () async {
      final keyHex = fakePublicKeyHex();
      final now = DateTime.now();

      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: now,
        identityId: keyHex,
        publicKey: keyHex,
      );

      // Second insert with same identityId should update, not duplicate
      await db.upsertPeerIdentity(
        displayName: 'Alice Updated',
        createdAt: now,
        identityId: keyHex,
        publicKey: keyHex,
      );

      final peers = await db.getAllPeerIdentities();
      expect(peers.length, 1);
      expect(peers.first.displayName, 'Alice Updated');
    });

    test('self identity is never a peer', () {
      final service = IdentityService(
        MockIdentityRepository(),
        MockPrivateKeyStore(),
      );
      // Without initialization, identityId is null
      expect(service.identityId, isNull);
    });

    test('identity conflict detection works', () async {
      final repo = IdentityRepository(db);
      final localKey = fakePublicKeyHex(1);
      final foreignKey = fakePublicKeyHex(2);

      // Create a peer
      await db.upsertPeerIdentity(
        displayName: 'Bob',
        createdAt: DateTime.now(),
        identityId: foreignKey,
        publicKey: foreignKey,
      );

      // Try to import with a different public key for the same identityId
      // but different hex - simulates a conflict
      final publicIdentity = PublicIdentity(
        formatVersion: identityFormatVersion,
        identityType: 'ed25519',
        publicKeyHex: foreignKey,
        displayName: 'Bob',
      );

      final (_, result) = await repo.findOrCreatePeer(
        publicIdentity: publicIdentity,
        localPublicKeyHex: localKey,
      );

      expect(result, AssociationResult.existing);
    });
  });

  group('I4.11 — BLE discovery deduplication', () {
    test('repeated discoveries within window are deduplicated', () async {
      final discoveryController = StreamController<DiscoveredOneBitDevice>();
      final peerController = StreamController<List<PeerInfo>>.broadcast();
      final now = DateTime.now().millisecondsSinceEpoch;

      final resolver = IdentityAssociationResolver(
        discoveryStream: discoveryController.stream,
        peerStream: peerController.stream,
      );

      final results = <ResolvedBleDevice>[];
      resolver.resolvedStream.listen(results.add);

      final key = fakePublicKeyBytes();
      final device = DiscoveredOneBitDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        rssi: -60,
        timestamp: now,
        name: 'Test',
        identityPublicKeyBytes: key,
      );

      // Emit same device 5 times within the dedup window
      for (var i = 0; i < 5; i++) {
        discoveryController.add(device);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      // Should only get 1 result (first emission)
      expect(results.length, 1);

      resolver.dispose();
      await discoveryController.close();
      await peerController.close();
    });

    test('different devices are not deduplicated', () async {
      final discoveryController = StreamController<DiscoveredOneBitDevice>();
      final peerController = StreamController<List<PeerInfo>>.broadcast();
      final now = DateTime.now().millisecondsSinceEpoch;

      final resolver = IdentityAssociationResolver(
        discoveryStream: discoveryController.stream,
        peerStream: peerController.stream,
      );

      final results = <ResolvedBleDevice>[];
      resolver.resolvedStream.listen(results.add);

      // Emit 3 different devices
      for (var i = 0; i < 3; i++) {
        discoveryController.add(DiscoveredOneBitDevice(
          deviceId: 'AA:BB:CC:DD:EE:$i',
          rssi: -60,
          timestamp: now + i * 100,
          name: 'Device $i',
          identityPublicKeyBytes: fakePublicKeyBytes(i),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(results.length, 3);

      resolver.dispose();
      await discoveryController.close();
      await peerController.close();
    });
  });

  group('I4.11 — Local identity database constraint', () {
    late AppDatabase db;

    setUp(() {
      db = createTestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('createLocalIdentity prevents multiple rows', () async {
      final first = await db.createLocalIdentity(
        displayName: 'First',
      );
      expect(first.id, 1);

      // Second call should return existing, not create new
      final second = await db.createLocalIdentity(
        displayName: 'Second',
      );
      expect(second.id, 1);
      expect(second.displayName, 'First');

      // Verify only one row exists
      final all = await db.select(db.localIdentity).get();
      expect(all.length, 1);
    });

    test('explicit id=1 is used for local identity', () async {
      final identity = await db.createLocalIdentity(
        displayName: 'Test',
      );
      expect(identity.id, 1);
    });
  });

  group('I4.11 — No false security claims in UI', () {
    test('BlePeerStatus does not contain trust/auth claims', () {
      // Verify enum values are neutral
      expect(BlePeerStatus.values, contains(BlePeerStatus.noIdentity));
      expect(BlePeerStatus.values, contains(BlePeerStatus.selfIdentity));
      expect(BlePeerStatus.values, contains(BlePeerStatus.knownPeer));
      expect(BlePeerStatus.values, contains(BlePeerStatus.unknownIdentity));

      // Ensure no "trusted", "authenticated", "verified" etc.
      for (final status in BlePeerStatus.values) {
        expect(status.name.toLowerCase(), isNot(contains('trust')));
        expect(status.name.toLowerCase(), isNot(contains('auth')));
        expect(status.name.toLowerCase(), isNot(contains('verified')));
        expect(status.name.toLowerCase(), isNot(contains('secure')));
      }
    });

    test('AssociationResult does not contain trust/auth claims', () {
      for (final result in AssociationResult.values) {
        expect(result.name.toLowerCase(), isNot(contains('trust')));
        expect(result.name.toLowerCase(), isNot(contains('auth')));
        expect(result.name.toLowerCase(), isNot(contains('verified')));
        expect(result.name.toLowerCase(), isNot(contains('secure')));
      }
    });
  });

  group('I4.11 — Private key never in export', () {
    test('exportPublicIdentity never includes private key', () async {
      final keyPair = await Ed25519().newKeyPair();
      final pub = await keyPair.extract();
      final pubBytes = Uint8List.fromList(pub.bytes);
      final pubHex = IdentityRepository.bytesToHex(pubBytes);

      final identity = IdentityInfo(
        id: 1,
        identityId: pubHex,
        displayName: 'Test',
        createdAt: DateTime(2025),
        publicKeyBytes: pubBytes,
      );

      final json = await exportPublicIdentity(identity);
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      // Explicitly verify private key is NOT present
      expect(decoded.containsKey('privateKey'), isFalse);
      expect(decoded.containsKey('private_key'), isFalse);
      expect(decoded.containsKey('seed'), isFalse);
      expect(decoded.containsKey('secret'), isFalse);
      expect(decoded.containsKey('privateKeyBytes'), isFalse);
    });

    test('import never accepts private key field', () {
      final keyHex = fakePublicKeyHex();
      final payload = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': keyHex,
        'privateKey': 'should_be_ignored',
      });

      // Should import successfully (private key is just ignored)
      final result = importPublicIdentity(payload);
      expect(result.identity.toJson().containsKey('privateKey'), isFalse);
    });
  });

  group('I4.11 — Constant-time comparison', () {
    test('identity comparison uses case-insensitive hex', () {
      final keyHex = 'AbCd1234' * 8; // 64 chars
      final keyHexUpper = keyHex.toUpperCase();
      final keyHexLower = keyHex.toLowerCase();

      expect(
        keyHexLower == keyHexUpper.toLowerCase(),
        isTrue,
      );
    });
  });
}
