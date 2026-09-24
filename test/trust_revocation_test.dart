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

  /// Helper: create a fully trusted peer through the service API.
  void makeTrusted(TrustService s, String id, {DateTime? at}) {
    final t = at ?? DateTime.now();
    s.verify(peerIdentityId: id, at: t, method: VerificationMethod.qrScan);
    s.markAuthenticated(peerIdentityId: id);
    s.trust(peerIdentityId: id, at: t);
  }

  // ── TrustService.revokeTrust ───────────────────────────────────

  group('TrustService.revokeTrust', () {
    late TrustService service;

    setUp(() => service = TrustService());

    test('trusted peer → revoked', () {
      makeTrusted(service, 'A');

      final result = service.revokeTrust(
        peerIdentityId: 'A',
        at: DateTime(2025, 8, 1),
      );

      expect(result.state, TrustState.revoked);
      expect(result.isRevoked, isTrue);
      expect(result.revokedAt, DateTime(2025, 8, 1));
    });

    test('verified peer → revoked', () {
      service.verify(
        peerIdentityId: 'B',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );

      final result = service.revokeTrust(
        peerIdentityId: 'B',
        at: DateTime(2025, 9, 1),
      );

      expect(result.state, TrustState.revoked);
    });

    test('unknown peer throws', () {
      expect(
        () => service.revokeTrust(
          peerIdentityId: 'unknown',
          at: DateTime.now(),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('already revoked returns same peer', () {
      makeTrusted(service, 'A');
      final first = service.revokeTrust(
        peerIdentityId: 'A',
        at: DateTime(2025, 1, 1),
      );
      final second = service.revokeTrust(
        peerIdentityId: 'A',
        at: DateTime(2025, 2, 1),
      );

      expect(second.state, TrustState.revoked);
      // Second call returns existing record (idempotent).
      expect(second.revokedAt, first.revokedAt);
    });

    test('stores reason when provided', () {
      makeTrusted(service, 'A');

      final result = service.revokeTrust(
        peerIdentityId: 'A',
        at: DateTime.now(),
        reason: 'compromised',
      );

      expect(result.revokeReason, 'compromised');
    });

    test('does not affect other peers', () {
      makeTrusted(service, 'A');
      makeTrusted(service, 'B');
      makeTrusted(service, 'C');

      service.revokeTrust(peerIdentityId: 'A', at: DateTime.now());

      expect(service.isTrusted('A'), isFalse);
      expect(service.isTrusted('B'), isTrue);
      expect(service.isTrusted('C'), isTrue);
    });

    test('preserves verified history after revocation', () {
      final now = DateTime.now();
      makeTrusted(service, 'A', at: now);

      final result = service.revokeTrust(
        peerIdentityId: 'A',
        at: DateTime(2025, 8, 1),
      );

      expect(result.verifiedAt, now);
      expect(result.verificationMethod, VerificationMethod.qrScan);
    });

    test('revoking peer preserves identity fields', () {
      makeTrusted(service, 'A');

      final result = service.revokeTrust(
        peerIdentityId: 'A',
        at: DateTime.now(),
      );

      expect(result.peerIdentityId, 'A');
    });
  });

  // ── TrustService.revoke (existing method) ──────────────────────

  group('TrustService.revoke', () {
    late TrustService service;

    setUp(() => service = TrustService());

    test('trusted peer → revoked via revoke()', () {
      makeTrusted(service, 'A');

      final result = service.revoke(
        peerIdentityId: 'A',
        at: DateTime.now(),
      );

      expect(result.state, TrustState.revoked);
    });

    test('already revoked returns existing', () {
      makeTrusted(service, 'A');
      final first = service.revoke(
        peerIdentityId: 'A',
        at: DateTime(2025, 1, 1),
      );
      final second = service.revoke(
        peerIdentityId: 'A',
        at: DateTime(2025, 2, 1),
      );

      expect(second.state, TrustState.revoked);
      expect(second.revokedAt, first.revokedAt);
    });
  });

  // ── Persistence ────────────────────────────────────────────────

  group('Trust revocation persistence', () {
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

    test('revoked state is persisted and restored', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      makeTrusted(service, 'peer_a_pub_key');

      service.revokeTrust(
        peerIdentityId: 'peer_a_pub_key',
        at: DateTime(2025, 7, 1),
      );

      // Reload from database.
      final service2 = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      final loaded = service2.getTrust('peer_a_pub_key');

      expect(loaded.state, TrustState.revoked);
      expect(loaded.isRevoked, isTrue);
    });

    test('revoked peer survives restart simulation', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      makeTrusted(service, 'peer_a_pub_key');

      service.revokeTrust(
        peerIdentityId: 'peer_a_pub_key',
        at: DateTime(2025, 7, 1),
      );

      // Dispose and create fresh service (simulates app restart).
      service.clear();
      final service2 = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      final loaded = service2.getTrust('peer_a_pub_key');

      expect(loaded.state, TrustState.revoked);
    });

    test('multi-peer: revoking one does not affect others', () async {
      await db.upsertPeerIdentity(
        displayName: 'Bob',
        createdAt: DateTime(2025),
        identityId: 'peer_b_pub_key',
        publicKey: 'peer_b_pub_key',
      );

      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      makeTrusted(service, 'peer_a_pub_key');
      makeTrusted(service, 'peer_b_pub_key');

      service.revokeTrust(
        peerIdentityId: 'peer_a_pub_key',
        at: DateTime(2025, 7, 1),
      );

      // Reload.
      final service2 = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      final a = service2.getTrust('peer_a_pub_key');
      final b = service2.getTrust('peer_b_pub_key');

      expect(a.state, TrustState.revoked);
      expect(b.state, TrustState.trusted);
    });

    test('revocation persisted through multi-peer restart', () async {
      await db.upsertPeerIdentity(
        displayName: 'Bob',
        createdAt: DateTime(2025),
        identityId: 'peer_b_pub_key',
        publicKey: 'peer_b_pub_key',
      );
      await db.upsertPeerIdentity(
        displayName: 'Charlie',
        createdAt: DateTime(2025),
        identityId: 'peer_c_pub_key',
        publicKey: 'peer_c_pub_key',
      );

      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      for (final id in ['peer_a_pub_key', 'peer_b_pub_key', 'peer_c_pub_key']) {
        makeTrusted(service, id);
      }

      service.revokeTrust(
        peerIdentityId: 'peer_b_pub_key',
        at: DateTime(2025, 7, 1),
      );

      // Restart.
      service.clear();
      final service2 = TrustService(repo);
      await Future<void>.delayed(Duration.zero);

      expect(service2.getTrust('peer_a_pub_key').state, TrustState.trusted);
      expect(service2.getTrust('peer_b_pub_key').state, TrustState.revoked);
      expect(service2.getTrust('peer_c_pub_key').state, TrustState.trusted);
    });

    test('identity binding: revocation applies to correct identity', () async {
      await db.upsertPeerIdentity(
        displayName: 'Bob',
        createdAt: DateTime(2025),
        identityId: 'peer_b_pub_key',
        publicKey: 'peer_b_pub_key',
      );

      final service = TrustService(repo);
      makeTrusted(service, 'peer_a_pub_key');
      makeTrusted(service, 'peer_b_pub_key');

      service.revokeTrust(
        peerIdentityId: 'peer_b_pub_key',
        at: DateTime.now(),
      );

      expect(service.isTrusted('peer_a_pub_key'), isTrue);
      expect(service.isTrusted('peer_b_pub_key'), isFalse);
    });

    test('unknown peer rejects revocation', () async {
      final service = TrustService(repo);

      expect(
        () => service.revokeTrust(
          peerIdentityId: 'nonexistent',
          at: DateTime.now(),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('identity remains after revocation', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      makeTrusted(service, 'peer_a_pub_key');

      service.revokeTrust(
        peerIdentityId: 'peer_a_pub_key',
        at: DateTime.now(),
      );

      final records = await db.loadAllTrust();
      expect(records.length, 1);
      expect(records.first.peerIdentityId, 'peer_a_pub_key');
      expect(records.first.trustState, 'revoked');
    });

    test('keys are not deleted after revocation', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      makeTrusted(service, 'peer_a_pub_key');

      service.revokeTrust(
        peerIdentityId: 'peer_a_pub_key',
        at: DateTime.now(),
      );

      // Verify identity record still exists.
      final identity = await (db.select(db.peerIdentities)
            ..where((t) => t.identityId.equals('peer_a_pub_key')))
          .getSingleOrNull();
      expect(identity, isNotNull);
      expect(identity!.identityId, 'peer_a_pub_key');
    });

    test('verification state is not destroyed by revocation', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      makeTrusted(service, 'peer_a_pub_key');

      service.revokeTrust(
        peerIdentityId: 'peer_a_pub_key',
        at: DateTime.now(),
      );

      final loaded = service.getTrust('peer_a_pub_key');
      expect(loaded.verifiedAt, isNotNull);
      expect(loaded.verificationMethod, VerificationMethod.qrScan);
      expect(loaded.state, TrustState.revoked);
    });

    test('no secrets in trust record', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      makeTrusted(service, 'peer_a_pub_key');

      service.revokeTrust(
        peerIdentityId: 'peer_a_pub_key',
        at: DateTime.now(),
      );

      final records = await db.loadAllTrust();
      final record = records.first;
      final serialized = record.toString().toLowerCase();

      expect(serialized.contains('private'), isFalse);
      expect(serialized.contains('secret'), isFalse);
    });

    test('revokeTrust method rejects already-revoked peer', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      makeTrusted(service, 'peer_a_pub_key');
      service.revokeTrust(
        peerIdentityId: 'peer_a_pub_key',
        at: DateTime(2025, 7, 1),
      );

      // Idempotent: returns existing revoked record.
      final result = service.revokeTrust(
        peerIdentityId: 'peer_a_pub_key',
        at: DateTime(2025, 8, 1),
      );
      expect(result.state, TrustState.revoked);
      expect(result.revokedAt, DateTime(2025, 7, 1));
    });

    test('authentication state remains after revocation', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      makeTrusted(service, 'peer_a_pub_key');

      final result = service.revokeTrust(
        peerIdentityId: 'peer_a_pub_key',
        at: DateTime.now(),
      );

      expect(result.isAuthenticated, isTrue);
      expect(result.state, TrustState.revoked);
    });

    test('idempotent: double revoke returns same state', () async {
      final service = TrustService(repo);
      await Future<void>.delayed(Duration.zero);
      makeTrusted(service, 'peer_a_pub_key');

      final first = service.revokeTrust(
        peerIdentityId: 'peer_a_pub_key',
        at: DateTime(2025, 7, 1),
      );
      final second = service.revokeTrust(
        peerIdentityId: 'peer_a_pub_key',
        at: DateTime(2025, 8, 1),
      );

      expect(first.state, TrustState.revoked);
      expect(second.state, TrustState.revoked);
      expect(first.revokedAt, DateTime(2025, 7, 1));
    });
  });

  // ── PeerTrust.revoke ───────────────────────────────────────────

  group('PeerTrust.revoke', () {
    test('trusted → revoked', () {
      final peer = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan)
          .markAuthenticated()
          .trust(at: DateTime.now());
      final revoked = peer.revoke(at: DateTime(2025));

      expect(revoked.state, TrustState.revoked);
      expect(revoked.revokedAt, DateTime(2025));
    });

    test('verified → revoked', () {
      final peer = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan);
      final revoked = peer.revoke(at: DateTime.now());

      expect(revoked.state, TrustState.revoked);
    });

    test('unknown → throws', () {
      final peer = PeerTrust.unknown(peerIdentityId: 'A');
      expect(
        () => peer.revoke(at: DateTime.now()),
        throwsA(isA<StateError>()),
      );
    });

    test('preserves verification info', () {
      final now = DateTime.now();
      final peer = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: now, method: VerificationMethod.qrScan)
          .markAuthenticated()
          .trust(at: now);
      final revoked = peer.revoke(at: DateTime(2025, 8, 1));

      expect(revoked.verifiedAt, now);
      expect(revoked.verificationMethod, VerificationMethod.qrScan);
    });

    test('preserves trustedAt', () {
      final now = DateTime.now();
      final peer = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: now, method: VerificationMethod.qrScan)
          .markAuthenticated()
          .trust(at: now);
      final revoked = peer.revoke(at: DateTime(2025, 8, 1));

      expect(revoked.trustedAt, now);
    });

    test('stores reason', () {
      final peer = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan)
          .markAuthenticated()
          .trust(at: DateTime.now());
      final revoked = peer.revoke(at: DateTime.now(), reason: 'compromised');

      expect(revoked.revokeReason, 'compromised');
    });
  });

  // ── No automatic revocation ────────────────────────────────────

  group('No automatic revocation', () {
    late TrustService service;

    setUp(() => service = TrustService());

    test('service trust state does not change without explicit call', () {
      makeTrusted(service, 'A');

      // Do NOT call revokeTrust.
      expect(service.isTrusted('A'), isTrue);
      expect(service.getTrust('A').isRevoked, isFalse);
    });

    test('clear resets to unknown, does not revoke', () {
      makeTrusted(service, 'A');

      service.clear();

      expect(service.getTrust('A').state, TrustState.unknown);
    });
  });
}
