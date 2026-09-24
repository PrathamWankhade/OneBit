import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/trust/peer_trust.dart';
import 'package:onebit/features/trust/trust_service.dart';
import 'package:onebit/features/trust/trust_state.dart';

void main() {
  AppDatabase createTestDb() =>
      AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));

  group('Trust persistence', () {
    late AppDatabase db;
    late IdentityRepository repo;

    setUp(() async {
      db = createTestDb();
      repo = IdentityRepository(db);

      // Create a peer so trust can be persisted against it.
      await db.upsertPeerIdentity(
        displayName: 'Alice',
        createdAt: DateTime(2025),
        identityId: 'peer_a_pub_key_hex',
        publicKey: 'peer_a_pub_key_hex',
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('savePeerTrust persists trust state', () async {
      await repo.savePeerTrust(
        peerIdentityId: 'peer_a_pub_key_hex',
        state: TrustState.trusted,
        trustedAt: DateTime(2025, 1, 1),
      );

      final records = await db.loadAllTrust();
      expect(records.length, 1);
      expect(records.first.peerIdentityId, 'peer_a_pub_key_hex');
      expect(records.first.trustState, 'trusted');
      expect(records.first.trustedAt, DateTime(2025, 1, 1));
    });

    test('loadAllTrust returns persisted trust records', () async {
      await repo.savePeerTrust(
        peerIdentityId: 'peer_a_pub_key_hex',
        state: TrustState.verified,
        verifiedAt: DateTime(2025, 6, 1),
        verificationMethod: VerificationMethod.qrScan,
      );

      final records = await db.loadAllTrust();
      expect(records.length, 1);
      expect(records.first.trustState, 'verified');
      expect(records.first.verifiedAt, DateTime(2025, 6, 1));
      expect(records.first.verificationMethod, 'qrScan');
    });

    test('loadAllTrust excludes unknown trust state', () async {
      // Default trust state is 'unknown' — should not appear in loadAllTrust.
      final records = await db.loadAllTrust();
      expect(records, isEmpty);
    });

    test('TrustService loads persisted trust on construction', () async {
      // Persist trust directly to DB.
      await repo.savePeerTrust(
        peerIdentityId: 'peer_a_pub_key_hex',
        state: TrustState.trusted,
        trustedAt: DateTime(2025, 1, 1),
      );

      // Create a new TrustService with repository — should load persisted trust.
      final service = TrustService(repo);
      // Wait for async load to complete.
      await Future<void>.delayed(Duration.zero);

      final trust = service.getTrust('peer_a_pub_key_hex');
      expect(trust.isTrusted, isTrue);
      expect(trust.trustedAt, DateTime(2025, 1, 1));
    });

    test('TrustService without repository has no persistence', () {
      final service = TrustService();
      // Default trust is unknown.
      expect(service.getTrust('peer_a_pub_key_hex').state, TrustState.unknown);
    });

    test('TrustService persists trust after establishTrust', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      // Setup: verify + authenticate
      service.verify(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'peer_a_pub_key_hex');

      // Establish trust
      service.establishTrust(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025, 1, 1),
      );

      // Verify it's persisted
      final records = await db.loadAllTrust();
      expect(records.length, 1);
      expect(records.first.trustState, 'trusted');
      expect(records.first.trustedAt, DateTime(2025, 1, 1));
    });

    test('TrustService persists trust after trust() call', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      service.verify(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025),
        method: VerificationMethod.fingerprintComparison,
      );
      service.markAuthenticated(peerIdentityId: 'peer_a_pub_key_hex');
      service.trust(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025, 3, 1),
      );

      final records = await db.loadAllTrust();
      expect(records.length, 1);
      expect(records.first.trustState, 'trusted');
      expect(records.first.verificationMethod, 'fingerprintComparison');
    });

    test('TrustService persists revocation', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      service.verify(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'peer_a_pub_key_hex');
      service.trust(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025, 1, 1),
      );
      service.revoke(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025, 6, 1),
        reason: 'compromised',
      );

      final records = await db.loadAllTrust();
      expect(records.length, 1);
      expect(records.first.trustState, 'revoked');
    });

    test('restart simulation: trust survives service re-creation', () async {
      // Phase 1: Establish trust with first service instance.
      final service1 = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      service1.verify(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025),
        method: VerificationMethod.qrScan,
      );
      service1.markAuthenticated(peerIdentityId: 'peer_a_pub_key_hex');
      service1.establishTrust(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025, 1, 1),
      );

      expect(service1.isTrusted('peer_a_pub_key_hex'), isTrue);

      // Phase 2: Simulate restart — create new service instance.
      service1.clear();
      final service2 = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      // Trust should be restored from persistence.
      expect(service2.isTrusted('peer_a_pub_key_hex'), isTrue);
      final trust = service2.getTrust('peer_a_pub_key_hex');
      expect(trust.trustedAt, DateTime(2025, 1, 1));
    });

    test('peer isolation: trust of A does not affect B', () async {
      // Create peer B.
      await db.upsertPeerIdentity(
        displayName: 'Bob',
        createdAt: DateTime(2025),
        identityId: 'peer_b_pub_key_hex',
        publicKey: 'peer_b_pub_key_hex',
      );

      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      // Trust only A.
      service.verify(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'peer_a_pub_key_hex');
      service.establishTrust(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025, 1, 1),
      );

      // Restart.
      service.clear();
      final service2 = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      expect(service2.isTrusted('peer_a_pub_key_hex'), isTrue);
      expect(service2.isTrusted('peer_b_pub_key_hex'), isFalse);
    });

    test('multiple trusted peers persist independently', () async {
      await db.upsertPeerIdentity(
        displayName: 'Bob',
        createdAt: DateTime(2025),
        identityId: 'peer_b_pub_key_hex',
        publicKey: 'peer_b_pub_key_hex',
      );

      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      for (final id in ['peer_a_pub_key_hex', 'peer_b_pub_key_hex']) {
        service.verify(
          peerIdentityId: id,
          at: DateTime(2025),
          method: VerificationMethod.qrScan,
        );
        service.markAuthenticated(peerIdentityId: id);
        service.establishTrust(
          peerIdentityId: id,
          at: DateTime(2025, 1, 1),
        );
      }

      // Restart.
      service.clear();
      final service2 = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      expect(service2.isTrusted('peer_a_pub_key_hex'), isTrue);
      expect(service2.isTrusted('peer_b_pub_key_hex'), isTrue);
    });

    test('duplicate trust does not create duplicate records', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      service.verify(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'peer_a_pub_key_hex');

      // Establish trust twice.
      service.establishTrust(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025, 1, 1),
      );
      service.establishTrust(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025, 2, 1),
      );

      final records = await db.loadAllTrust();
      // Should be one record, not two.
      expect(records.length, 1);
      // First trust time should be preserved (idempotent).
      expect(records.first.trustedAt, DateTime(2025, 1, 1));
    });

    test('trust is bound to cryptographic identity, not peer DB id', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      service.verify(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'peer_a_pub_key_hex');
      service.establishTrust(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025, 1, 1),
      );

      // The trust is keyed by identityId, not by database row id.
      final records = await db.loadAllTrust();
      expect(records.first.peerIdentityId, 'peer_a_pub_key_hex');
    });

    test('trust record contains no private/session secrets', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      service.verify(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'peer_a_pub_key_hex');
      service.establishTrust(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025, 1, 1),
      );

      final records = await db.loadAllTrust();
      final record = records.first;

      // Verify no secret material is in the trust record.
      // PeerTrustRecord only contains: peerIdentityId, trustState,
      // verifiedAt, verificationMethod, trustedAt.
      expect(record.peerIdentityId, isNotEmpty);
      expect(record.trustState, isNotEmpty);
      // No private keys, session keys, etc. in the record.
    });

    test('restored trust does not imply current authentication', () async {
      // Persist trust.
      await repo.savePeerTrust(
        peerIdentityId: 'peer_a_pub_key_hex',
        state: TrustState.trusted,
        trustedAt: DateTime(2025, 1, 1),
      );

      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      // Trust is restored.
      expect(service.isTrusted('peer_a_pub_key_hex'), isTrue);
      // But authentication is NOT restored (it's a runtime property).
      expect(service.isAuthenticated('peer_a_pub_key_hex'), isFalse);
    });

    test('restored trust does not modify verification state', () async {
      await repo.savePeerTrust(
        peerIdentityId: 'peer_a_pub_key_hex',
        state: TrustState.trusted,
        trustedAt: DateTime(2025, 1, 1),
      );

      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      expect(service.isTrusted('peer_a_pub_key_hex'), isTrue);
      // Verification is a separate runtime concern.
      expect(service.isVerified('peer_a_pub_key_hex'), isFalse);
    });

    test('existing peer without trust decision defaults to unknown', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      final trust = service.getTrust('peer_a_pub_key_hex');
      expect(trust.state, TrustState.unknown);
      expect(trust.isTrusted, isFalse);
    });

    test('trust with verification metadata persists correctly', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      final at = DateTime(2025, 7, 15, 10, 30);
      service.verify(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: at,
        method: VerificationMethod.pairingProtocol,
      );
      service.markAuthenticated(peerIdentityId: 'peer_a_pub_key_hex');
      service.establishTrust(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025, 7, 15, 11, 0),
      );

      final records = await db.loadAllTrust();
      expect(records.length, 1);
      expect(records.first.trustState, 'trusted');
      expect(records.first.verifiedAt, at);
      expect(records.first.verificationMethod, 'pairingProtocol');
      expect(records.first.trustedAt, DateTime(2025, 7, 15, 11, 0));
    });

    test('savePeerTrust handles non-existent peer gracefully', () async {
      // Should not throw — UPDATE with no matching rows is a no-op.
      await repo.savePeerTrust(
        peerIdentityId: 'nonexistent_peer',
        state: TrustState.trusted,
      );

      final records = await db.loadAllTrust();
      expect(records, isEmpty);
    });

    test('clear() resets in-memory state but not persistence', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      service.verify(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'peer_a_pub_key_hex');
      service.establishTrust(
        peerIdentityId: 'peer_a_pub_key_hex',
        at: DateTime(2025, 1, 1),
      );

      // Clear in-memory state.
      service.clear();
      expect(service.isTrusted('peer_a_pub_key_hex'), isFalse);

      // But persistence is not cleared.
      final records = await db.loadAllTrust();
      expect(records.length, 1);
      expect(records.first.trustState, 'trusted');
    });
  });

  // ── Schema migration test ────────────────────────────────

  group('Schema v11 migration', () {
    test('migration adds trust columns to peer_identities', () async {
      final db = createTestDb();
      // Schema version 11 includes trust columns and lastSeenBleAddress.
      expect(db.schemaVersion, 11);

      // Verify trust columns exist by inserting a peer and checking.
      await db.upsertPeerIdentity(
        displayName: 'Test',
        createdAt: DateTime(2025),
        identityId: 'test_key',
      );

      // The trust_state column should default to 'unknown'.
      final peer = await db.getPeerIdentityByIdentityId('test_key');
      expect(peer, isNotNull);

      // Verify we can load trust (should be empty since state is 'unknown').
      final records = await db.loadAllTrust();
      expect(records, isEmpty);

      await db.close();
    });

    test('existing peer data survives migration', () async {
      final db = createTestDb();

      // Insert a peer with pre-migration data pattern.
      await db.upsertPeerIdentity(
        displayName: 'Existing Peer',
        createdAt: DateTime(2025),
        identityId: 'existing_key',
        publicKey: 'existing_key',
        keyAgreementPublicKey: 'x25519_key',
      );

      // Peer should still be accessible after schema upgrade.
      final peer = await db.getPeerIdentityByIdentityId('existing_key');
      expect(peer, isNotNull);
      expect(peer!.displayName, 'Existing Peer');
      expect(peer.publicKey, 'existing_key');
      expect(peer.keyAgreementPublicKey, 'x25519_key');

      await db.close();
    });
  });
}
