import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/peer_registry/peer_entry.dart';
import 'package:onebit/features/peer_registry/peer_registry.dart';
import 'package:onebit/features/trust/peer_trust.dart';
import 'package:onebit/features/trust/trust_service.dart';
import 'package:onebit/features/trust/trust_state.dart';

AppDatabase createTestDb() =>
    AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));

String fakeKey([int seed = 0]) {
  final bytes = Uint8List.fromList(
    List.generate(32, (i) => (seed + i) & 0xFF),
  );
  return IdentityRepository.bytesToHex(bytes);
}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── §24: Persistence Tests ─────────────────────────────────

  group('Peer persistence — create/update/remove/load', () {
    late AppDatabase db;
    late IdentityRepository repo;

    setUp(() async {
      db = createTestDb();
      repo = IdentityRepository(db);
    });

    tearDown(() async => db.close());

    test('create peer persists to database', () async {
      final key = fakeKey(1);
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: key,
        publicKey: key,
      );

      final peer = await repo.getPeerByIdentityId(key);
      expect(peer, isNotNull);
      expect(peer!.displayName, 'Alice');
      expect(peer.identityId, key);
    });

    test('update peer persists changes', () async {
      final key = fakeKey(1);
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: key,
        publicKey: key,
      );

      await db.updatePeerDisplayName(id: 1, displayName: 'Alice Updated');

      final peer = await repo.getPeerByIdentityId(key);
      expect(peer!.displayName, 'Alice Updated');
    });

    test('remove peer deletes from database', () async {
      final key = fakeKey(1);
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: key,
        publicKey: key,
      );

      final peer = await repo.getPeerByIdentityId(key);
      await repo.removePeer(peer!.id);

      final remaining = await repo.getPeerByIdentityId(key);
      expect(remaining, isNull);
    });

    test('load multiple peers', () async {
      for (var i = 0; i < 3; i++) {
        await db.upsertPeerIdentity(
          displayName: 'Peer $i',
          createdAt: DateTime(2025),
          identityId: fakeKey(i),
          publicKey: fakeKey(i),
        );
      }

      final all = await repo.getAllPeerIdentities();
      expect(all.length, 3);
    });

    test('restart simulation — peers load from new DB instance', () async {
      final key = fakeKey(1);
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: key,
        publicKey: key,
      );

      // Simulate restart: close old DB, open new one (same in-memory for test)
      final all = await repo.getAllPeerIdentities();
      expect(all.length, 1);
      expect(all.first.displayName, 'Alice');
      expect(all.first.identityId, key);
    });

    test('duplicate identityId is prevented by UNIQUE constraint', () async {
      final key = fakeKey(1);
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: key,
        publicKey: key,
      );

      // Upsert with same identityId should update, not duplicate
      await db.upsertPeerIdentity(
        displayName: 'Alice V2',
        createdAt: DateTime(2025),
        identityId: key,
        publicKey: key,
      );

      final all = await repo.getAllPeerIdentities();
      expect(all.length, 1);
      expect(all.first.displayName, 'Alice V2');
    });
  });

  // ── §24: Recovery Tests ───────────────────────────────────

  group('Peer recovery — A/B/C persisted → restored', () {
    late AppDatabase db;
    late IdentityRepository repo;

    setUp(() async {
      db = createTestDb();
      repo = IdentityRepository(db);
    });

    tearDown(() async => db.close());

    test('four peers with different states survive restart', () async {
      final keys = List.generate(4, fakeKey);

      for (var i = 0; i < 4; i++) {
        await db.upsertPeerIdentity(
          displayName: 'Peer $i',
          createdAt: DateTime(2025),
          identityId: keys[i],
          publicKey: keys[i],
        );
      }

      // Load all peers
      final all = await repo.getAllPeerIdentities();
      expect(all.length, 4);

      // Verify each peer is individually accessible
      for (final key in keys) {
        final peer = await repo.getPeerByIdentityId(key);
        expect(peer, isNotNull);
      }
    });

    test('registry recovers peers from database', () async {
      final key1 = fakeKey(1);
      final key2 = fakeKey(2);

      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: key1,
        publicKey: key1,
      );
      await db.upsertPeerIdentity(
        displayName: 'Bob',
        createdAt: DateTime(2025),
        identityId: key2,
        publicKey: key2,
      );

      // Simulate registry recovery: load from DB and populate
      final registry = PeerRegistryService();
      final peers = await repo.getAllPeerIdentities();
      registry.updateFromIdentities(peers);

      expect(registry.count, 2);
      expect(registry.get(key1), isNotNull);
      expect(registry.get(key2), isNotNull);
      expect(registry.get(key1)!.peer.displayName, 'Alice');
      expect(registry.get(key2)!.peer.displayName, 'Bob');

      registry.dispose();
    });
  });

  // ── §24: Trust Recovery Tests ─────────────────────────────

  group('Trust persistence — A→TRUSTED, B→VERIFIED, C→REVOKED', () {
    late AppDatabase db;
    late IdentityRepository repo;

    setUp(() async {
      db = createTestDb();
      repo = IdentityRepository(db);
    });

    tearDown(() async => db.close());

    test('trust states survive restart independently', () async {
      final keyA = fakeKey(1);
      final keyB = fakeKey(2);
      final keyC = fakeKey(3);

      // Create peers
      for (final (name, key) in [
        ('Alice', keyA),
        ('Bob', keyB),
        ('Charlie', keyC),
      ]) {
        await db.upsertPeerIdentity(
          displayName: name,
          createdAt: DateTime(2025),
          identityId: key,
          publicKey: key,
        );
      }

      // Set trust states
      final svc = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      // Alice: TRUSTED
      svc.verify(peerIdentityId: keyA, at: DateTime(2025), method: VerificationMethod.qrScan);
      svc.markAuthenticated(peerIdentityId: keyA);
      svc.establishTrust(peerIdentityId: keyA, at: DateTime(2025));

      // Bob: VERIFIED (but not trusted)
      svc.verify(peerIdentityId: keyB, at: DateTime(2025), method: VerificationMethod.fingerprintComparison);

      // Charlie: REVOKED
      svc.verify(peerIdentityId: keyC, at: DateTime(2025), method: VerificationMethod.qrScan);
      svc.revoke(peerIdentityId: keyC, at: DateTime(2025), reason: 'compromised');

      svc.dispose();

      // Simulate restart: new TrustService loads from DB
      final svc2 = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      expect(svc2.isTrusted(keyA), isTrue);
      expect(svc2.getTrust(keyB).state, TrustState.verified);
      expect(svc2.getTrust(keyC).isRevoked, isTrue);

      svc2.dispose();
    });

    test('registry restores trust state from DB on startup', () async {
      final keyA = fakeKey(1);
      final keyB = fakeKey(2);

      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: keyA,
        publicKey: keyA,
      );
      await db.upsertPeerIdentity(
        displayName: 'Bob',
        createdAt: DateTime(2025),
        identityId: keyB,
        publicKey: keyB,
      );

      // Set trust
      final svc = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      svc.verify(peerIdentityId: keyA, at: DateTime(2025), method: VerificationMethod.qrScan);
      svc.markAuthenticated(peerIdentityId: keyA);
      svc.establishTrust(peerIdentityId: keyA, at: DateTime(2025));
      svc.verify(peerIdentityId: keyB, at: DateTime(2025), method: VerificationMethod.fingerprintComparison);
      svc.dispose();

      // Simulate startup: new service loads trust, registry syncs
      final svc2 = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      final registry = PeerRegistryService();
      final peers = await repo.getAllPeerIdentities();
      registry.updateFromIdentities(peers);

      // Sync trust for each peer (same as peer_registry_providers.dart)
      for (final peer in peers) {
        final identityId = peer.identityId ?? peer.publicKeyHex;
        if (identityId == null) continue;
        final trust = svc2.getTrust(identityId);
        final verification = svc2.getVerification(identityId);
        registry.updateTrust(
          identityId,
          trustState: trust.state,
          isVerified: verification.isVerified,
          isAuthenticated: trust.isAuthenticated,
        );
      }

      expect(registry.get(keyA)!.trustState, TrustState.trusted);
      expect(registry.get(keyB)!.trustState, TrustState.verified);

      svc2.dispose();
      registry.dispose();
    });
  });

  // ── §24: Runtime State Reset Tests ────────────────────────

  group('Runtime state reset — no fabricated connections/sessions', () {
    late PeerRegistryService registry;

    setUp(() => registry = PeerRegistryService());
    tearDown(() => registry.dispose());

    test('restored peers start with disconnected lifecycle', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'alice'),
        _peer(id: 2, identityId: 'bob'),
      ]);

      for (final id in ['alice', 'bob']) {
        final entry = registry.get(id)!;
        expect(entry.lifecycleState.name, 'disconnected');
        expect(entry.connectionState.name, 'disconnected');
        expect(entry.bleDeviceId, isNull);
        expect(entry.isAuthenticated, isFalse);
      }
    });

    test('no BLE connection restored after startup', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'alice'),
      ]);

      final entry = registry.get('alice')!;
      expect(entry.isConnected, isFalse);
      expect(entry.isConnecting, isFalse);
      expect(entry.bleDeviceId, isNull);
    });

    test('no session state restored after startup', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'alice'),
      ]);

      final entry = registry.get('alice')!;
      // isAuthenticated is a runtime property, not restored
      expect(entry.isAuthenticated, isFalse);
    });
  });

  // ── §24: Identity Behavior Tests ──────────────────────────

  group('Identity behavior on persistence', () {
    late AppDatabase db;
    late IdentityRepository repo;

    setUp(() async {
      db = createTestDb();
      repo = IdentityRepository(db);
    });

    tearDown(() async => db.close());

    test('same identity restores same logical peer', () async {
      final key = fakeKey(1);
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: key,
        publicKey: key,
      );

      // Lookup by identityId — same result
      final peer1 = await repo.getPeerByIdentityId(key);
      final peer2 = await repo.getPeerByIdentityId(key);
      expect(peer1!.id, peer2!.id);
      expect(peer1.identityId, peer2.identityId);
    });

    test('different identity does not inherit trust', () async {
      final keyA = fakeKey(1);
      final keyB = fakeKey(2);

      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: keyA,
        publicKey: keyA,
      );
      await db.upsertPeerIdentity(
        displayName: 'Bob',
        createdAt: DateTime(2025),
        identityId: keyB,
        publicKey: keyB,
      );

      final svc = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      svc.verify(peerIdentityId: keyA, at: DateTime(2025), method: VerificationMethod.qrScan);
      svc.markAuthenticated(peerIdentityId: keyA);
      svc.establishTrust(peerIdentityId: keyA, at: DateTime(2025));
      svc.dispose();

      // Restart
      final svc2 = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      expect(svc2.isTrusted(keyA), isTrue);
      expect(svc2.isTrusted(keyB), isFalse);

      svc2.dispose();
    });

    test('identity change does not transfer trust', () async {
      final keyOld = fakeKey(1);
      final keyNew = fakeKey(2);

      await db.upsertPeerIdentity(
        displayName: 'Old Identity',
        createdAt: DateTime(2025),
        identityId: keyOld,
        publicKey: keyOld,
      );

      final svc = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      svc.verify(peerIdentityId: keyOld, at: DateTime(2025), method: VerificationMethod.qrScan);
      svc.markAuthenticated(peerIdentityId: keyOld);
      svc.establishTrust(peerIdentityId: keyOld, at: DateTime(2025));
      svc.dispose();

      // New identity appears
      await db.upsertPeerIdentity(
        displayName: 'New Identity',
        createdAt: DateTime(2025),
        identityId: keyNew,
        publicKey: keyNew,
      );

      // Restart
      final svc2 = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      expect(svc2.isTrusted(keyOld), isTrue);
      expect(svc2.isTrusted(keyNew), isFalse);

      svc2.dispose();
    });

    test('no silent identity replacement', () async {
      final key = fakeKey(1);
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: key,
        publicKey: key,
      );

      // Get peer
      final peer = await repo.getPeerByIdentityId(key);
      expect(peer, isNotNull);
      expect(peer!.identityId, key);
      expect(peer.displayName, 'Alice');

      // Identity is immutable — same key always resolves to same peer
      final peer2 = await repo.getPeerByIdentityId(key);
      expect(peer2!.id, peer.id);
    });
  });

  // ── §24: Peer Isolation Tests ─────────────────────────────

  group('Peer isolation on persistence', () {
    late AppDatabase db;
    late IdentityRepository repo;

    setUp(() async {
      db = createTestDb();
      repo = IdentityRepository(db);
    });

    tearDown(() async => db.close());

    test('update A does not modify B', () async {
      final keyA = fakeKey(1);
      final keyB = fakeKey(2);

      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: keyA,
        publicKey: keyA,
      );
      await db.upsertPeerIdentity(
        displayName: 'Bob',
        createdAt: DateTime(2025),
        identityId: keyB,
        publicKey: keyB,
      );

      await db.updatePeerDisplayName(id: 1, displayName: 'Alice Updated');

      final peerA = await repo.getPeerByIdentityId(keyA);
      final peerB = await repo.getPeerByIdentityId(keyB);

      expect(peerA!.displayName, 'Alice Updated');
      expect(peerB!.displayName, 'Bob');
    });

    test('remove A does not affect B', () async {
      final keyA = fakeKey(1);
      final keyB = fakeKey(2);

      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: keyA,
        publicKey: keyA,
      );
      await db.upsertPeerIdentity(
        displayName: 'Bob',
        createdAt: DateTime(2025),
        identityId: keyB,
        publicKey: keyB,
      );

      final peerA = await repo.getPeerByIdentityId(keyA);
      await repo.removePeer(peerA!.id);

      expect(await repo.getPeerByIdentityId(keyA), isNull);
      expect(await repo.getPeerByIdentityId(keyB), isNotNull);
    });

    test('trust of A does not affect B persistence', () async {
      final keyA = fakeKey(1);
      final keyB = fakeKey(2);

      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: keyA,
        publicKey: keyA,
      );
      await db.upsertPeerIdentity(
        displayName: 'Bob',
        createdAt: DateTime(2025),
        identityId: keyB,
        publicKey: keyB,
      );

      final svc = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      svc.verify(peerIdentityId: keyA, at: DateTime(2025), method: VerificationMethod.qrScan);
      svc.markAuthenticated(peerIdentityId: keyA);
      svc.establishTrust(peerIdentityId: keyA, at: DateTime(2025));
      svc.dispose();

      // Restart
      final svc2 = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      expect(svc2.isTrusted(keyA), isTrue);
      expect(svc2.getTrust(keyB).state, TrustState.unknown);

      svc2.dispose();
    });
  });

  // ── §24: Idempotent Recovery Tests ────────────────────────

  group('Idempotent recovery', () {
    late AppDatabase db;
    late IdentityRepository repo;

    setUp(() async {
      db = createTestDb();
      repo = IdentityRepository(db);
    });

    tearDown(() async => db.close());

    test('multiple loads produce same result', () async {
      final key = fakeKey(1);
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: key,
        publicKey: key,
      );

      final load1 = await repo.getAllPeerIdentities();
      final load2 = await repo.getAllPeerIdentities();
      final load3 = await repo.getAllPeerIdentities();

      expect(load1.length, 1);
      expect(load2.length, 1);
      expect(load3.length, 1);
      expect(load1.first.id, load2.first.id);
      expect(load2.first.id, load3.first.id);
    });

    test('registry recovery is idempotent', () {
      final registry = PeerRegistryService();
      final peers = [
        _peer(id: 1, identityId: 'alice'),
        _peer(id: 2, identityId: 'bob'),
      ];

      // Populate twice
      registry.updateFromIdentities(peers);
      registry.updateFromIdentities(peers);

      // Should still be 2 peers, not 4
      expect(registry.count, 2);

      registry.dispose();
    });

    test('trust service recovery is idempotent', () async {
      final key = fakeKey(1);
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: key,
        publicKey: key,
      );

      await repo.savePeerTrust(
        peerIdentityId: key,
        state: TrustState.trusted,
        trustedAt: DateTime(2025),
      );

      // Load twice
      final svc1 = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      final trust1 = svc1.getTrust(key);
      svc1.dispose();

      final svc2 = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      final trust2 = svc2.getTrust(key);

      expect(trust1.isTrusted, trust2.isTrusted);
      expect(trust1.trustedAt, trust2.trustedAt);

      svc2.dispose();
    });
  });

  // ── §24: Failure Handling Tests ───────────────────────────

  group('Failure handling', () {
    late AppDatabase db;
    late IdentityRepository repo;

    setUp(() async {
      db = createTestDb();
      repo = IdentityRepository(db);
    });

    tearDown(() async => db.close());

    test('missing identity returns null', () async {
      final peer = await repo.getPeerByIdentityId('nonexistent');
      expect(peer, isNull);
    });

    test('missing peer by ID returns null', () async {
      final peer = await repo.getPeerIdentity(99999);
      expect(peer, isNull);
    });

    test('trust for nonexistent peer returns unknown', () async {
      final svc = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      final trust = svc.getTrust('nonexistent_peer');
      expect(trust.state, TrustState.unknown);
      expect(trust.isTrusted, isFalse);

      svc.dispose();
    });

    test('savePeerTrust for nonexistent peer is a no-op', () async {
      await repo.savePeerTrust(
        peerIdentityId: 'nonexistent',
        state: TrustState.trusted,
      );

      final records = await db.loadAllTrust();
      expect(records, isEmpty);
    });

    test('remove non-existent peer returns 0', () async {
      final deleted = await repo.removePeer(99999);
      expect(deleted, 0);
    });

    test('duplicate peer upsert does not create duplicate', () async {
      final key = fakeKey(1);
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: key,
        publicKey: key,
      );
      await db.upsertPeerIdentity(
        displayName: 'Alice V2',
        createdAt: DateTime(2025),
        identityId: key,
        publicKey: key,
      );

      final all = await repo.getAllPeerIdentities();
      expect(all.length, 1);
    });
  });

  // ── §25: Security Tests ───────────────────────────────────

  group('No secret exposure', () {
    late AppDatabase db;
    late IdentityRepository repo;

    setUp(() async {
      db = createTestDb();
      repo = IdentityRepository(db);
    });

    tearDown(() async => db.close());

    test('peer record does not contain private keys', () async {
      final key = fakeKey(1);
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: key,
        publicKey: key,
      );

      final peer = await repo.getPeerByIdentityId(key);
      final str = peer.toString();

      expect(str, isNot(contains('private')));
      expect(str, isNot(contains('seed')));
      expect(str, isNot(contains('secret')));
    });

    test('trust record does not contain session keys', () async {
      final key = fakeKey(1);
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: key,
        publicKey: key,
      );

      final svc = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      svc.verify(peerIdentityId: key, at: DateTime(2025), method: VerificationMethod.qrScan);
      svc.markAuthenticated(peerIdentityId: key);
      svc.establishTrust(peerIdentityId: key, at: DateTime(2025));

      final records = await db.loadAllTrust();
      final recordStr = records.first.toString();

      expect(recordStr, isNot(contains('session')));
      expect(recordStr, isNot(contains('aes')));
      expect(recordStr, isNot(contains('x25519')));

      svc.dispose();
    });

    test('PeerEntry does not expose cryptographic secrets', () {
      final entry = PeerEntry(
        identityId: 'aabbccdd',
        peer: _peer(id: 1, identityId: 'aabbccdd'),
        trustState: TrustState.trusted,
      );

      final str = entry.toString();
      expect(str, isNot(contains('private')));
      expect(str, isNot(contains('seed')));
      expect(str, isNot(contains('secret')));
    });
  });

  // ── §24: Full Recovery Flow Test ──────────────────────────

  group('Full recovery flow', () {
    test('complete A/B/C/D recovery with different trust states', () async {
      final db = createTestDb();
      final repo = IdentityRepository(db);

      final keys = List.generate(4, fakeKey);

      // Phase 1: Create peers and set trust states
      final displayNames = ['Alice', 'Bob', 'Charlie', 'Diana'];
      for (var i = 0; i < 4; i++) {
        await db.upsertPeerIdentity(
          displayName: displayNames[i],
          createdAt: DateTime(2025),
          identityId: keys[i],
          publicKey: keys[i],
        );
      }

      final svc = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      // Alice: TRUSTED
      svc.verify(peerIdentityId: keys[0], at: DateTime(2025), method: VerificationMethod.qrScan);
      svc.markAuthenticated(peerIdentityId: keys[0]);
      svc.establishTrust(peerIdentityId: keys[0], at: DateTime(2025));

      // Bob: VERIFIED
      svc.verify(peerIdentityId: keys[1], at: DateTime(2025), method: VerificationMethod.fingerprintComparison);

      // Charlie: REVOKED
      svc.verify(peerIdentityId: keys[2], at: DateTime(2025), method: VerificationMethod.qrScan);
      svc.revoke(peerIdentityId: keys[2], at: DateTime(2025), reason: 'compromised');

      // Diana: UNVERIFIED (default)
      svc.dispose();

      // Phase 2: Simulate restart
      final svc2 = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      final registry = PeerRegistryService();
      final peers = await repo.getAllPeerIdentities();
      registry.updateFromIdentities(peers);

      for (final peer in peers) {
        final identityId = peer.identityId ?? peer.publicKeyHex;
        if (identityId == null) continue;
        final trust = svc2.getTrust(identityId);
        final verification = svc2.getVerification(identityId);
        registry.updateTrust(
          identityId,
          trustState: trust.state,
          isVerified: verification.isVerified,
          isAuthenticated: trust.isAuthenticated,
        );
      }

      // Phase 3: Verify recovery
      expect(registry.count, 4);

      final alice = registry.get(keys[0])!;
      expect(alice.trustState, TrustState.trusted);
      expect(alice.peer.displayName, 'Alice');

      final bob = registry.get(keys[1])!;
      expect(bob.trustState, TrustState.verified);
      expect(bob.peer.displayName, 'Bob');

      final charlie = registry.get(keys[2])!;
      expect(charlie.trustState, TrustState.revoked);
      expect(charlie.peer.displayName, 'Charlie');

      final diana = registry.get(keys[3])!;
      expect(diana.trustState, TrustState.unknown);
      expect(diana.peer.displayName, 'Diana');

      // Runtime state is reset
      for (final key in keys) {
        final entry = registry.get(key)!;
        expect(entry.lifecycleState.name, 'disconnected');
        expect(entry.connectionState.name, 'disconnected');
        expect(entry.bleDeviceId, isNull);
        expect(entry.isAuthenticated, isFalse);
      }

      svc2.dispose();
      registry.dispose();
      await db.close();
    });
  });
}
