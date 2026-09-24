import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/identity/identity_export.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/identity/identity_repository.dart';

AppDatabase createTestDb() =>
    AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));

String fakePublicKeyHex([int seed = 0]) {
  final bytes = Uint8List.fromList(
    List.generate(32, (i) => (seed + i) & 0xFF),
  );
  return IdentityRepository.bytesToHex(bytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late IdentityRepository repo;

  setUp(() async {
    db = createTestDb();
    await db.customStatement('PRAGMA foreign_keys = ON');
    repo = IdentityRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('IdentityRepository - renamePeer', () {
    test('updates display name of existing peer', () async {
      final key = fakePublicKeyHex(1);
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime.now(),
        identityId: key,
        publicKey: key,
      );

      final peer = await repo.getPeerByIdentityId(key);
      expect(peer, isNotNull);
      expect(peer!.displayName, 'Alice');

      await repo.renamePeer(id: peer.id, newName: 'Alice Updated');

      final updated = await repo.getPeerIdentity(peer.id);
      expect(updated, isNotNull);
      expect(updated!.displayName, 'Alice Updated');
    });

    test('rename persists across multiple reads', () async {
      final key = fakePublicKeyHex(2);
      await db.upsertPeerIdentity(
        displayName: 'Bob',
        createdAt: DateTime.now(),
        identityId: key,
        publicKey: key,
      );

      final peer = await repo.getPeerByIdentityId(key);
      await repo.renamePeer(id: peer!.id, newName: 'Robert');

      // Read via different methods
      final byId = await repo.getPeerIdentity(peer.id);
      final byKey = await repo.getPeerByIdentityId(key);
      expect(byId!.displayName, 'Robert');
      expect(byKey!.displayName, 'Robert');
    });

    test('rename does not affect other peers', () async {
      final key1 = fakePublicKeyHex(1);
      final key2 = fakePublicKeyHex(2);

      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime.now(),
        identityId: key1,
        publicKey: key1,
      );
      await db.upsertPeerIdentity(
        displayName: 'Bob',
        createdAt: DateTime.now(),
        identityId: key2,
        publicKey: key2,
      );

      final peer1 = await repo.getPeerByIdentityId(key1);
      await repo.renamePeer(id: peer1!.id, newName: 'Alice Renamed');

      final peer2 = await repo.getPeerByIdentityId(key2);
      expect(peer2!.displayName, 'Bob');
    });
  });

  group('IdentityRepository - removePeer', () {
    test('removes peer from database', () async {
      final key = fakePublicKeyHex(1);
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime.now(),
        identityId: key,
        publicKey: key,
      );

      final peer = await repo.getPeerByIdentityId(key);
      expect(peer, isNotNull);

      final deleted = await repo.removePeer(peer!.id);
      expect(deleted, 1);

      final remaining = await repo.getPeerByIdentityId(key);
      expect(remaining, isNull);
    });

    test('remove returns 0 for non-existent peer', () async {
      final result = await repo.removePeer(99999);
      expect(result, 0);
    });

    test('remove does not affect other peers', () async {
      final key1 = fakePublicKeyHex(1);
      final key2 = fakePublicKeyHex(2);

      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime.now(),
        identityId: key1,
        publicKey: key1,
      );
      await db.upsertPeerIdentity(
        displayName: 'Bob',
        createdAt: DateTime.now(),
        identityId: key2,
        publicKey: key2,
      );

      final peer1 = await repo.getPeerByIdentityId(key1);
      await repo.removePeer(peer1!.id);

      final peer2 = await repo.getPeerByIdentityId(key2);
      expect(peer2, isNotNull);
      expect(peer2!.displayName, 'Bob');
    });

    test('remove decrements peer count', () async {
      final key1 = fakePublicKeyHex(1);
      final key2 = fakePublicKeyHex(2);

      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime.now(),
        identityId: key1,
        publicKey: key1,
      );
      await db.upsertPeerIdentity(
        displayName: 'Bob',
        createdAt: DateTime.now(),
        identityId: key2,
        publicKey: key2,
      );

      var all = await repo.getAllPeerIdentities();
      expect(all.length, 2);

      final peer1 = await repo.getPeerByIdentityId(key1);
      await repo.removePeer(peer1!.id);

      all = await repo.getAllPeerIdentities();
      expect(all.length, 1);
      expect(all.first.displayName, 'Bob');
    });
  });

  group('AppDatabase - updatePeerDisplayName', () {
    test('direct database rename works', () async {
      final key = fakePublicKeyHex(1);
      await db.upsertPeerIdentity(
        displayName: 'Original',
        createdAt: DateTime.now(),
        identityId: key,
        publicKey: key,
      );

      final peer = await db.getPeerIdentityByIdentityId(key);
      expect(peer, isNotNull);

      await db.updatePeerDisplayName(
        id: peer!.id,
        displayName: 'Updated',
      );

      final updated = await db.getPeerIdentityByIdentityId(key);
      expect(updated!.displayName, 'Updated');
    });
  });

  group('PeerInfo model', () {
    test('equality based on fields', () {
      final peer1 = PeerInfo(
        id: 1,
        identityId: 'abc',
        publicKeyHex: 'def',
        displayName: 'Alice',
        createdAt: DateTime(2025),
      );
      final peer2 = PeerInfo(
        id: 1,
        identityId: 'abc',
        publicKeyHex: 'def',
        displayName: 'Alice',
        createdAt: DateTime(2025),
      );

      expect(peer1.id, peer2.id);
      expect(peer1.identityId, peer2.identityId);
      expect(peer1.displayName, peer2.displayName);
    });

    test('different peers have different ids', () {
      final peer1 = PeerInfo(
        id: 1,
        displayName: 'Alice',
        createdAt: DateTime(2025),
      );
      final peer2 = PeerInfo(
        id: 2,
        displayName: 'Bob',
        createdAt: DateTime(2025),
      );

      expect(peer1.id, isNot(equals(peer2.id)));
    });
  });

  group('Regression - existing operations', () {
    test('getAllPeerIdentities still works', () async {
      final key = fakePublicKeyHex(1);
      await db.upsertPeerIdentity(
        displayName: 'Test',
        createdAt: DateTime.now(),
        identityId: key,
        publicKey: key,
      );

      final all = await repo.getAllPeerIdentities();
      expect(all.length, 1);
    });

    test('watchPeerIdentities emits updates', () async {
      final key = fakePublicKeyHex(1);

      // Start watching
      final stream = repo.watchPeerIdentities();
      final first = await stream.first;
      expect(first, isEmpty);

      // Insert
      await db.upsertPeerIdentity(
        displayName: 'New Peer',
        createdAt: DateTime.now(),
        identityId: key,
        publicKey: key,
      );

      // The stream should emit the new list
      final second = await stream.first;
      expect(second.length, 1);
      expect(second.first.displayName, 'New Peer');
    });

    test('findOrCreatePeer still creates peers', () async {
      final localKey = fakePublicKeyHex(0);
      final foreignKey = fakePublicKeyHex(1);

      final publicIdentity = PublicIdentity(
        formatVersion: identityFormatVersion,
        identityType: 'ed25519',
        publicKeyHex: foreignKey,
        displayName: 'Remote',
      );

      final (peer, result) = await repo.findOrCreatePeer(
        publicIdentity: publicIdentity,
        localPublicKeyHex: localKey,
      );

      expect(result, AssociationResult.created);
      expect(peer, isNotNull);
    });
  });
}
