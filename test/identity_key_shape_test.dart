import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/data/database/identity_key_migration.dart';
import 'package:onebit/features/crypto/ed25519_keys.dart';
import 'package:onebit/features/crypto/key_material.dart';
import 'package:onebit/features/identity/identity_export.dart';
import 'package:onebit/features/identity/identity_fingerprint.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/identity/identity_service.dart';
import 'package:onebit/features/identity/private_key_store.dart';

/// A fixed seed, so the expected public key is stable across runs.
Uint8List testSeed() => Uint8List.fromList(List.generate(32, (i) => i + 1));

String hexOf(Uint8List bytes) => IdentityRepository.bytesToHex(bytes);

Future<String> publicHexOfSeed(Uint8List seed) async {
  final pair = await Ed25519().newKeyPairFromSeed(seed);
  final public = await pair.extractPublicKey();
  return hexOf(Uint8List.fromList(public.bytes));
}

class MemoryKeyStore extends PrivateKeyStore {
  MemoryKeyStore() : super();
  Uint8List? held;
  @override
  Future<Uint8List?> read() async => held;
  @override
  Future<void> write(Uint8List keyBytes) async => held = keyBytes;
  @override
  Future<void> delete() async => held = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ed25519PublicKeyHex', () {
    test('derives the public half, not the seed', () async {
      final seed = testSeed();
      final derived = await ed25519PublicKeyHex(hexOf(seed));

      expect(derived, isNotNull);
      expect(derived, await publicHexOfSeed(seed));
      expect(derived!.toLowerCase(), isNot(hexOf(seed).toLowerCase()));
    });

    test('returns null for anything that is not a 32-byte hex value',
        () async {
      expect(await ed25519PublicKeyHex(''), isNull);
      expect(await ed25519PublicKeyHex('abcd'), isNull);
      expect(await ed25519PublicKeyHex('zz' * 32), isNull);
      expect(await ed25519PublicKeyHex('00' * 31), isNull);
      expect(await ed25519PublicKeyHex('00' * 33), isNull);
    });
  });

  group('createIdentity stores a public key', () {
    test('identityId is the public half and reloads cleanly', () async {
      final db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      addTearDown(db.close);
      final keys = MemoryKeyStore();
      final service = IdentityService(IdentityRepository(db), keys);

      final identity = await service.createIdentity('Me');

      final seedBytes =
          Uint8List.fromList((await service.keyPair!.extract()).bytes);
      final seedHex = hexOf(seedBytes);
      expect(identity.identityId, isNotNull);
      expect(identity.identityId!.toLowerCase(), isNot(seedHex.toLowerCase()));
      expect(
        identity.identityId!.toLowerCase(),
        (await publicHexOfSeed(seedBytes)).toLowerCase(),
      );

      // The fixed consistency check accepts the new shape on reload.
      final reloaded = IdentityService(IdentityRepository(db), keys);
      expect(await reloaded.initialize(), isTrue);
      expect(reloaded.identityId, identity.identityId);
    });
  });

  group('export carries a public key', () {
    test('export is version 2 and re-imports without resolution loss',
        () async {
      final db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      addTearDown(db.close);
      final service =
          IdentityService(IdentityRepository(db), MemoryKeyStore());
      final identity = await service.createIdentity('Me');

      final payload = await exportPublicIdentity(identity);
      expect(payload, contains('"formatVersion":2'));

      final result = await importAndResolvePublicIdentity(payload);
      expect(result.identity.formatVersion, identityFormatVersion);
      expect(result.identity.publicKeyHex, identity.identityId);
    });
  });

  group('legacy payloads resolve to public keys', () {
    test('a version-1 payload resolves to the true public key', () async {
      final seed = testSeed();
      final seedHex = hexOf(seed);
      final expected = await publicHexOfSeed(seed);

      final legacy = PublicIdentity(
        formatVersion: legacyIdentityFormatVersion,
        identityType: 'ed25519',
        publicKeyHex: seedHex,
        displayName: 'Old peer',
        fingerprint: await computeFingerprint(seed),
      );

      final resolved = await resolvePublicIdentity(legacy);

      expect(resolved.formatVersion, identityFormatVersion);
      expect(resolved.publicKeyHex.toLowerCase(), expected.toLowerCase());
      // The fingerprint describes what is stored, not what arrived.
      expect(
        resolved.fingerprint,
        await computeFingerprint(IdentityRepository.hexToBytes(expected)),
      );
      expect(resolved.displayName, 'Old peer');
    });

    test('a current payload comes back untouched', () async {
      final seed = testSeed();
      final expected = await publicHexOfSeed(seed);
      final current = PublicIdentity(
        formatVersion: identityFormatVersion,
        identityType: 'ed25519',
        publicKeyHex: expected,
        displayName: 'New peer',
        fingerprint: 'kept',
      );

      final resolved = await resolvePublicIdentity(current);

      expect(resolved.publicKeyHex, expected);
      expect(resolved.fingerprint, 'kept');
    });

    test('legacy JSON imports through the combined entry point', () async {
      final seed = testSeed();
      final payload = PublicIdentity(
        formatVersion: legacyIdentityFormatVersion,
        identityType: 'ed25519',
        publicKeyHex: hexOf(seed),
      ).toJsonString();

      final result = await importAndResolvePublicIdentity(payload);

      expect(result.identity.formatVersion, identityFormatVersion);
      expect(
        result.identity.publicKeyHex.toLowerCase(),
        (await publicHexOfSeed(seed)).toLowerCase(),
      );
    });

    test('a legacy payload that is not a key is rejected, not stored',
        () async {
      final notAKey = PublicIdentity(
        formatVersion: legacyIdentityFormatVersion,
        identityType: 'ed25519',
        publicKeyHex:
            'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz',
      );

      expect(
        () => resolvePublicIdentity(notAKey),
        throwsA(isA<ImportError>()),
      );
    });
  });

  group('schema v13 migration', () {
    test('seed-shaped rows become public keys and threads follow',
        () async {
      final db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      addTearDown(db.close);

      final seed = testSeed();
      final seedHex = hexOf(seed);
      final expected = await publicHexOfSeed(seed);

      // Legacy-shaped rows: the mistake, as earlier builds wrote it.
      await db.into(db.localIdentity).insert(
            LocalIdentityCompanion.insert(
              id: const Value(1),
              displayName: 'Me',
              createdAt: DateTime(2025),
              identityId: Value(seedHex),
              publicKey: Value(seedHex),
            ),
          );
      await db.upsertPeerIdentity(
        displayName: 'Old peer',
        createdAt: DateTime(2025),
        identityId: seedHex,
        publicKey: seedHex,
      );
      final convId = await db.createConversationWithPeer('Old peer', seedHex);
      final bleConvId = await db.createConversationWithPeer(
        'Nearby',
        'AA:BB:CC:DD:EE:FF',
      );

      await migrateIdentityIdsToPublicKeys(db);

      final local = await db.getLocalIdentity();
      expect(local!.identityId!.toLowerCase(), expected.toLowerCase());
      expect(local.publicKey!.toLowerCase(), expected.toLowerCase());

      expect(
        await db.getPeerIdentityByIdentityId(seedHex),
        isNull,
        reason: 'the seed must not survive as an identity',
      );
      final peer = await db.getPeerIdentityByIdentityId(expected);
      expect(peer, isNotNull);

      final conv = await db.getConversation(convId);
      expect(conv!.peerDeviceId, expected);

      // A BLE address is not an identity and is left alone.
      final bleConv = await db.getConversation(bleConvId);
      expect(bleConv!.peerDeviceId, 'AA:BB:CC:DD:EE:FF');

      // The marker lands, and a second run changes nothing.
      final marker = await (db.select(db.settings)
            ..where((t) => t.key.equals(identityKeyShapeSetting)))
          .getSingleOrNull();
      expect(marker, isNotNull);
      await migrateIdentityIdsToPublicKeys(db);
      expect((await db.getLocalIdentity())!.identityId, expected);
    });
  });

  group('KeyMaterial.getLocalPublicKey', () {
    test('returns the X25519 public half, not the derived seed', () async {
      final seed = testSeed();
      final public = await KeyMaterial.getLocalPublicKey(ed25519Seed: seed);

      final pair = await KeyMaterial.deriveLocalKeyAgreementKey(
        ed25519Seed: seed,
      );
      final expected = await pair.extractPublicKey();

      expect(public, Uint8List.fromList(expected.bytes));
    });
  });

  group('key-agreement exchange over QR', () {
    IdentityInfo testIdentity() => IdentityInfo(
          id: 1,
          identityId: 'ab' * 32,
          displayName: 'Me',
          createdAt: DateTime(2025),
          publicKeyBytes: Uint8List.fromList(List.generate(32, (i) => i)),
        );

    test('export carries the key when provided, omits it otherwise',
        () async {
      final withKey = await exportPublicIdentity(
        testIdentity(),
        keyAgreementPublicKeyHex: 'cd' * 32,
      );
      expect(
        (jsonDecode(withKey) as Map<String, dynamic>)['keyAgreement'],
        'cd' * 32,
      );

      final withoutKey = await exportPublicIdentity(testIdentity());
      expect(
        (jsonDecode(withoutKey) as Map<String, dynamic>)
            .containsKey('keyAgreement'),
        isFalse,
      );
    });

    test('import rejects a malformed keyAgreement', () {
      final malformed = <Object?>['xyz', 'ab' * 31, 'gg' * 32, 42, true];
      for (final bad in malformed) {
        final payload = jsonEncode({
          'formatVersion': identityFormatVersion,
          'identityType': 'ed25519',
          'publicKey': 'ab' * 32,
          'keyAgreement': bad,
        });
        expect(
          () => importPublicIdentity(payload),
          throwsA(isA<ImportError>()),
          reason: 'keyAgreement=$bad',
        );
      }
    });

    test('import keeps a well-formed keyAgreement through resolution',
        () async {
      final payload = jsonEncode({
        'formatVersion': identityFormatVersion,
        'identityType': 'ed25519',
        'publicKey': 'ab' * 32,
        'keyAgreement': 'cd' * 32,
      });

      final result = await importAndResolvePublicIdentity(payload);

      expect(result.identity.formatVersion, identityFormatVersion);
      expect(result.identity.keyAgreementPublicKeyHex, 'cd' * 32);
    });

    test('associate stores the scanned key, including on re-scan',
        () async {
      final db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      addTearDown(db.close);
      final repo = IdentityRepository(db);
      final service = IdentityService(repo, MemoryKeyStore());
      await service.createIdentity('Me');
      final peerHex = await publicHexOfSeed(testSeed());

      PublicIdentity scanned(String? keyHex) => PublicIdentity(
            formatVersion: identityFormatVersion,
            identityType: 'ed25519',
            publicKeyHex: peerHex,
            displayName: 'Peer',
            keyAgreementPublicKeyHex: keyHex,
          );

      final (peer, result) = await service.associatePeer(scanned('cd' * 32));
      expect(result, AssociationResult.created);
      expect(peer!.keyAgreementPublicKeyHex, 'cd' * 32);

      final (_, again) = await service.associatePeer(scanned('ef' * 32));
      expect(again, AssociationResult.existing);
      expect(
        (await repo.getPeerByIdentityId(peerHex))!.keyAgreementPublicKeyHex,
        'ef' * 32,
      );
    });
  });
}
