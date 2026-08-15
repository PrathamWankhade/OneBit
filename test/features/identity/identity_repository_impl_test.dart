import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/crypto/identity/exchange_crypto.dart';
import 'package:onebit/core/crypto/identity/node_id.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/features/identity/data/identity_repository_impl.dart';
import 'package:onebit/features/identity/data/in_memory_trust_contact_repository.dart';
import 'package:onebit/features/identity/domain/trust_contact.dart';
import 'package:onebit/features/identity/domain/trust_level.dart';
import 'package:onebit/features/identity/domain/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'identity_test_support.dart';

void main() {
  late FakeKeystoreKeyBridge vault;
  late IdentityRepositoryImpl repository;
  late InMemoryTrustContactRepository contacts;

  setUp(() {
    vault = FakeKeystoreKeyBridge();
    contacts = InMemoryTrustContactRepository();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    repository = IdentityRepositoryImpl(
      vault: vault,
      prefs: SharedPreferencesAsync(),
      logger: silentLogger(),
      contacts: contacts,
    );
  });

  group('identity lifecycle', () {
    test('no identity on a fresh install', () async {
      final result = await repository.loadIdentity();
      expect(result.isOk, isTrue);
      expect(result.value, isNull);
    });

    test('createIdentity persists public metadata and vault seeds', () async {
      final result = await repository.createIdentity(
        displayName: 'Alice',
        avatarColor: 3,
      );
      expect(result.isOk, isTrue, reason: result.failure?.toString());
      final identity = result.value!;

      expect(
        identity.nodeId.value,
        matches(RegExp(r'^NODE-[0-9A-F]{4}-[0-9A-F]{4}$')),
      );
      expect(identity.fingerprint.bytes, hasLength(32));
      expect(identity.fingerprintHex, hasLength(64));
      expect(identity.ed25519PublicKey, hasLength(32));
      expect(identity.x25519PublicKey, hasLength(32));
      expect(identity.profile.displayName, 'Alice');
      expect(identity.profile.avatarColor, 3);

      expect(vault.store.keys, contains('onebit.identity.v1'));
      expect(vault.store.keys, contains('onebit.identity.v1.exchange'));

      final reloaded = await repository.loadIdentity();
      expect(reloaded.value!.uuid, identity.uuid);
      expect(reloaded.value!.nodeId, identity.nodeId);
      expect(reloaded.value!.profile.displayName, 'Alice');
    });

    test('createIdentity twice is rejected', () async {
      await repository.createIdentity(displayName: 'Alice', avatarColor: 0);
      final second = await repository.createIdentity(
        displayName: 'Bob',
        avatarColor: 1,
      );
      expect(second.isErr, isTrue);
      expect(second.failure, isA<IdentityFailure>());
    });

    test('updateProfile persists and reflects in state', () async {
      await repository.createIdentity(displayName: 'Alice', avatarColor: 0);
      final updated = await repository.updateProfile(
        const UserProfile(
          displayName: 'Alice Prime',
          avatarColor: 5,
          tagline: 'hi',
        ),
      );
      expect(updated.isOk, isTrue, reason: updated.failure?.toString());
      expect(updated.value!.profile.displayName, 'Alice Prime');
      expect(updated.value!.profile.tagline, 'hi');

      final reloaded = await repository.loadIdentity();
      expect(reloaded.value!.profile.displayName, 'Alice Prime');
    });

    test('updateProfile without an identity fails', () async {
      final result = await repository.updateProfile(
        const UserProfile(displayName: 'Ghost', avatarColor: 0),
      );
      expect(result.isErr, isTrue);
      expect((result.failure as IdentityFailure).code, 'not_created');
    });

    test('deleteIdentity clears vault and metadata', () async {
      await repository.createIdentity(displayName: 'Alice', avatarColor: 0);
      final deleted = await repository.deleteIdentity();
      expect(deleted.isOk, isTrue);

      expect(vault.store, isEmpty);
      final reloaded = await repository.loadIdentity();
      expect(reloaded.value, isNull);
    });

    test('metadata without a vault reports vault_missing', () async {
      await repository.createIdentity(displayName: 'Alice', avatarColor: 0);
      vault.store.clear();
      final result = await repository.loadIdentity();
      expect(result.isErr, isTrue);
      expect((result.failure as IdentityFailure).code, 'vault_missing');
    });

    test('corrupt metadata reports metadata_corrupt', () async {
      await SharedPreferencesAsync().setString(
        'onebit.identity.v1.metadata',
        '{"broken json',
      );
      final result = await repository.loadIdentity();
      expect(result.isErr, isTrue);
      expect((result.failure as IdentityFailure).code, 'metadata_corrupt');
    });
  });

  group('signing and key agreement', () {
    test('sign/verify round-trip with the identity public key', () async {
      final created = await repository.createIdentity(
        displayName: 'Alice',
        avatarColor: 0,
      );
      final identity = created.value!;
      const message = <int>[1, 2, 3, 4];

      final signed = await repository.sign(message);
      expect(signed.isOk, isTrue);
      expect(signed.value, hasLength(64));

      final ok = await repository.verify(
        publicKey: identity.ed25519PublicKey,
        message: message,
        signature: signed.value!,
      );
      expect(ok.value, isTrue);

      final bad = await repository.verify(
        publicKey: identity.ed25519PublicKey,
        message: const <int>[1, 2, 3, 5],
        signature: signed.value!,
      );
      expect(bad.value, isFalse);
    });

    test('signing without an identity fails', () async {
      final result = await repository.sign(const <int>[1, 2, 3]);
      expect(result.isErr, isTrue);
      expect((result.failure as IdentityFailure).code, 'not_created');
    });

    test('sharedSecret equals the raw ECDH between the stored seeds', () async {
      await repository.createIdentity(displayName: 'Alice', avatarColor: 0);
      final remoteSeed = Uint8List.fromList(
        List<int>.generate(32, (i) => 200 + i),
      );
      final remotePublic = await ExchangeCrypto.publicKeyFromSeed(remoteSeed);

      final ours = await repository.sharedSecret(remotePublic);
      expect(ours.isOk, isTrue);

      final seeds = await repository.loadSeeds();
      final reference = await ExchangeCrypto.sharedSecret(
        keyPairSeed: Uint8List.fromList(seeds.value!.x25519Seed),
        remotePublicKey: remotePublic,
      );
      expect(ours.value, reference);
      expect(ours.value, hasLength(32));
    });
  });

  group('backup export/import', () {
    test('export then import restores the full identity', () async {
      final created = await repository.createIdentity(
        displayName: 'Alice',
        avatarColor: 2,
      );
      final identity = created.value!;
      final document = await repository.exportBackup(passphrase: 'hunter2');
      expect(document.isOk, isTrue);
      expect(document.value, isNotEmpty);

      final freshVault = FakeKeystoreKeyBridge();
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final fresh = IdentityRepositoryImpl(
        vault: freshVault,
        prefs: SharedPreferencesAsync(),
        logger: silentLogger(),
        contacts: InMemoryTrustContactRepository(),
      );

      final imported = await fresh.importBackup(
        passphrase: 'hunter2',
        document: document.value!,
      );
      expect(imported.isOk, isTrue, reason: imported.failure?.toString());
      expect(imported.value!.uuid, identity.uuid);
      expect(imported.value!.nodeId, identity.nodeId);
      expect(imported.value!.fingerprintHex, identity.fingerprintHex);
      expect(imported.value!.profile.displayName, 'Alice');

      final signed = await fresh.sign(const <int>[9, 9, 9]);
      expect(signed.isOk, isTrue);
      final ok = await fresh.verify(
        publicKey: imported.value!.ed25519PublicKey,
        message: const <int>[9, 9, 9],
        signature: signed.value!,
      );
      expect(ok.value, isTrue);
    });

    test('import preserves trust contacts', () async {
      final created = await repository.createIdentity(
        displayName: 'Alice',
        avatarColor: 0,
      );
      final nodeId = created.value!.nodeId;
      await contacts.upsert(_bob(nodeId));
      final document = await repository.exportBackup(passphrase: 'pass');
      expect(document.isOk, isTrue);

      final freshContacts = InMemoryTrustContactRepository();
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final fresh = IdentityRepositoryImpl(
        vault: FakeKeystoreKeyBridge(),
        prefs: SharedPreferencesAsync(),
        logger: silentLogger(),
        contacts: freshContacts,
      );
      final imported = await fresh.importBackup(
        passphrase: 'pass',
        document: document.value!,
      );
      expect(imported.isOk, isTrue, reason: imported.failure?.toString());

      final loaded = await freshContacts.loadContacts();
      expect(loaded.value, hasLength(1));
      expect(loaded.value!.single.nodeId, nodeId);
      expect(loaded.value!.single.displayName, 'Bob');
    });

    test('import with a wrong passphrase fails', () async {
      await repository.createIdentity(displayName: 'Alice', avatarColor: 0);
      final document = await repository.exportBackup(passphrase: 'right');
      final result = await repository.importBackup(
        passphrase: 'wrong',
        document: document.value!,
      );
      expect(result.isErr, isTrue);
      expect(result.failure, isA<BackupFailure>());
    });

    test('import of a corrupt document fails', () async {
      final result = await repository.importBackup(
        passphrase: 'x',
        document: 'not-a-backup',
      );
      expect(result.isErr, isTrue);
      expect(result.failure, isA<BackupFailure>());
    });

    test('export without an identity fails', () async {
      final result = await repository.exportBackup(passphrase: 'x');
      expect(result.isErr, isTrue);
      expect((result.failure as IdentityFailure).code, 'not_created');
    });
  });

  group('trust contacts', () {
    test('setTrustLevel on a missing contact fails', () async {
      final contacts = InMemoryTrustContactRepository();
      final result = await contacts.setTrustLevel(
        nodeId: 'NODE-0000-0000',
        level: TrustLevel.verified,
      );
      expect(result.isErr, isTrue);
      expect((result.failure as IdentityFailure).code, 'contact_not_found');
    });
  });
}

TrustContact _bob(NodeId nodeId) => TrustContact(
  nodeId: nodeId,
  displayName: 'Bob',
  fingerprintHex: 'a' * 64,
  ed25519PublicKey: Uint8List(32),
  x25519PublicKey: Uint8List(32),
);
