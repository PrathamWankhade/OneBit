import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/trust/peer_trust.dart';
import 'package:onebit/features/trust/trust_service.dart';
import 'package:onebit/features/trust/trust_state.dart';

void main() {
  // ── TrustState enum ──────────────────────────────────────────

  group('TrustState', () {
    test('has 4 expected states', () {
      expect(TrustState.values.length, 4);
      expect(TrustState.values, contains(TrustState.unknown));
      expect(TrustState.values, contains(TrustState.verified));
      expect(TrustState.values, contains(TrustState.trusted));
      expect(TrustState.values, contains(TrustState.revoked));
    });
  });

  // ── VerificationMethod enum ──────────────────────────────────

  group('VerificationMethod', () {
    test('has 3 expected methods', () {
      expect(VerificationMethod.values.length, 3);
      expect(
        VerificationMethod.values,
        contains(VerificationMethod.qrScan),
      );
      expect(
        VerificationMethod.values,
        contains(VerificationMethod.fingerprintComparison),
      );
      expect(
        VerificationMethod.values,
        contains(VerificationMethod.pairingProtocol),
      );
    });
  });

  // ── PeerTrust construction ───────────────────────────────────

  group('PeerTrust construction', () {
    test('unknown factory creates unknown state', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'peer_A');
      expect(trust.peerIdentityId, 'peer_A');
      expect(trust.state, TrustState.unknown);
      expect(trust.isUnknown, isTrue);
      expect(trust.verifiedAt, isNull);
      expect(trust.verificationMethod, isNull);
      expect(trust.trustedAt, isNull);
      expect(trust.revokedAt, isNull);
      expect(trust.revokeReason, isNull);
    });

    test('holds all fields', () {
      final now = DateTime.now();
      final trust = PeerTrust(
        peerIdentityId: 'peer_B',
        state: TrustState.trusted,
        verifiedAt: now,
        verificationMethod: VerificationMethod.qrScan,
        trustedAt: now,
      );
      expect(trust.peerIdentityId, 'peer_B');
      expect(trust.state, TrustState.trusted);
      expect(trust.verifiedAt, now);
      expect(trust.verificationMethod, VerificationMethod.qrScan);
      expect(trust.trustedAt, now);
    });
  });

  // ── PeerTrust state queries ──────────────────────────────────

  group('PeerTrust state queries', () {
    test('unknown peer is not trusted', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A');
      expect(trust.isUnknown, isTrue);
      expect(trust.isVerified, isFalse);
      expect(trust.isTrusted, isFalse);
      expect(trust.isRevoked, isFalse);
      expect(trust.canCommunicate, isFalse);
    });

    test('verified peer canCommunicate is false', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A').verify(
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      expect(trust.isVerified, isTrue);
      expect(trust.canCommunicate, isFalse);
    });

    test('trusted peer canCommunicate is true', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan)
          .markAuthenticated()
          .trust(at: DateTime.now());
      expect(trust.isTrusted, isTrue);
      expect(trust.canCommunicate, isTrue);
    });

    test('revoked peer is not trusted', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan)
          .revoke(at: DateTime.now(), reason: 'compromised');
      expect(trust.isRevoked, isTrue);
      expect(trust.canCommunicate, isFalse);
    });
  });

  // ── PeerTrust state transitions ──────────────────────────────

  group('PeerTrust state transitions', () {
    test('unknown → verified via qrScan', () {
      final now = DateTime.now();
      final trust = PeerTrust.unknown(peerIdentityId: 'A');
      final verified = trust.verify(at: now, method: VerificationMethod.qrScan);

      expect(verified.state, TrustState.verified);
      expect(verified.verifiedAt, now);
      expect(verified.verificationMethod, VerificationMethod.qrScan);
      expect(verified.peerIdentityId, 'A');
    });

    test('unknown → verified via fingerprintComparison', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A');
      final verified = trust.verify(
        at: DateTime.now(),
        method: VerificationMethod.fingerprintComparison,
      );
      expect(verified.verificationMethod, VerificationMethod.fingerprintComparison);
    });

    test('unknown → verified via pairingProtocol', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A');
      final verified = trust.verify(
        at: DateTime.now(),
        method: VerificationMethod.pairingProtocol,
      );
      expect(verified.verificationMethod, VerificationMethod.pairingProtocol);
    });

    test('verified → trusted', () {
      final now = DateTime.now();
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: now, method: VerificationMethod.qrScan)
          .markAuthenticated();
      final trusted = trust.trust(at: DateTime.now());

      expect(trusted.state, TrustState.trusted);
      expect(trusted.trustedAt, isNotNull);
      expect(trusted.verifiedAt, now);
      expect(trusted.verificationMethod, VerificationMethod.qrScan);
    });

    test('verified → revoked', () {
      final now = DateTime.now();
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: now, method: VerificationMethod.qrScan);
      final revoked = trust.revoke(at: DateTime.now(), reason: 'no longer needed');

      expect(revoked.state, TrustState.revoked);
      expect(revoked.revokedAt, isNotNull);
      expect(revoked.revokeReason, 'no longer needed');
      expect(revoked.verifiedAt, now);
    });

    test('trusted → revoked', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan)
          .markAuthenticated()
          .trust(at: DateTime.now());
      final revoked = trust.revoke(at: DateTime.now());

      expect(revoked.state, TrustState.revoked);
      expect(revoked.revokedAt, isNotNull);
      expect(revoked.trustedAt, isNotNull);
    });

    test('revoke without reason works', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan);
      final revoked = trust.revoke(at: DateTime.now());
      expect(revoked.revokeReason, isNull);
    });
  });

  // ── PeerTrust invalid transitions ────────────────────────────

  group('PeerTrust invalid transitions', () {
    test('cannot verify from verified state', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan);
      expect(
        () => trust.verify(at: DateTime.now(), method: VerificationMethod.qrScan),
        throwsA(isA<StateError>()),
      );
    });

    test('cannot verify from trusted state', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan)
          .markAuthenticated()
          .trust(at: DateTime.now());
      expect(
        () => trust.verify(at: DateTime.now(), method: VerificationMethod.qrScan),
        throwsA(isA<StateError>()),
      );
    });

    test('cannot verify from revoked state', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan)
          .revoke(at: DateTime.now());
      expect(
        () => trust.verify(at: DateTime.now(), method: VerificationMethod.qrScan),
        throwsA(isA<StateError>()),
      );
    });

    test('cannot trust from unknown state', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A');
      expect(
        () => trust.trust(at: DateTime.now()),
        throwsA(isA<StateError>()),
      );
    });

    test('cannot trust from verified state without authentication', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan);
      expect(
        () => trust.trust(at: DateTime.now()),
        throwsA(isA<StateError>()),
      );
    });

    test('cannot trust from trusted state', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan)
          .markAuthenticated()
          .trust(at: DateTime.now());
      expect(
        () => trust.trust(at: DateTime.now()),
        throwsA(isA<StateError>()),
      );
    });

    test('cannot trust from revoked state', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan)
          .revoke(at: DateTime.now());
      expect(
        () => trust.trust(at: DateTime.now()),
        throwsA(isA<StateError>()),
      );
    });

    test('cannot revoke from unknown state', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A');
      expect(
        () => trust.revoke(at: DateTime.now()),
        throwsA(isA<StateError>()),
      );
    });

    test('cannot revoke from revoked state', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan)
          .revoke(at: DateTime.now());
      expect(
        () => trust.revoke(at: DateTime.now()),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ── PeerTrust immutability ───────────────────────────────────

  group('PeerTrust immutability', () {
    test('transitions return new instances', () {
      final original = PeerTrust.unknown(peerIdentityId: 'A');
      final verified = original.verify(
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );

      expect(original.state, TrustState.unknown);
      expect(verified.state, TrustState.verified);
      expect(identical(original, verified), isFalse);
    });

    test('original unchanged after trust', () {
      final original = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan)
          .markAuthenticated();
      final trusted = original.trust(at: DateTime.now());

      expect(original.state, TrustState.verified);
      expect(trusted.state, TrustState.trusted);
    });
  });

  // ── PeerTrust equality ───────────────────────────────────────

  group('PeerTrust equality', () {
    test('same identity and state are equal', () {
      final a = PeerTrust.unknown(peerIdentityId: 'A');
      final b = PeerTrust.unknown(peerIdentityId: 'A');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('same identity different state are not equal', () {
      final a = PeerTrust.unknown(peerIdentityId: 'A');
      final b = a.verify(at: DateTime.now(), method: VerificationMethod.qrScan);
      expect(a, isNot(equals(b)));
    });

    test('different identity same state are not equal', () {
      final a = PeerTrust.unknown(peerIdentityId: 'A');
      final b = PeerTrust.unknown(peerIdentityId: 'B');
      expect(a, isNot(equals(b)));
    });
  });

  // ── PeerTrust toString ───────────────────────────────────────

  group('PeerTrust toString', () {
    test('shows truncated ID and state', () {
      final trust = PeerTrust.unknown(
        peerIdentityId: 'abcdef1234567890',
      );
      expect(trust.toString(), contains('PeerTrust'));
      expect(trust.toString(), contains('unknown'));
      expect(trust.toString(), contains('abcdef12…'));
    });

    test('short ID is not truncated', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'AB');
      expect(trust.toString(), contains('AB'));
    });
  });

  // ── TrustService ─────────────────────────────────────────────

  group('TrustService', () {
    late TrustService service;

    setUp(() {
      service = TrustService();
    });

    test('getTrust returns unknown for unknown peer', () {
      final trust = service.getTrust('peer_A');
      expect(trust.state, TrustState.unknown);
      expect(trust.peerIdentityId, 'peer_A');
    });

    test('isTrusted returns false for unknown peer', () {
      expect(service.isTrusted('peer_A'), isFalse);
    });

    test('canCommunicate returns false for unknown peer', () {
      expect(service.canCommunicate('peer_A'), isFalse);
    });

    test('verify transitions peer to verified', () {
      final now = DateTime.now();
      final trust = service.verify(
        peerIdentityId: 'peer_A',
        at: now,
        method: VerificationMethod.qrScan,
      );

      expect(trust.state, TrustState.verified);
      expect(service.isTrusted('peer_A'), isFalse);
      expect(service.canCommunicate('peer_A'), isFalse);
    });

    test('trust transitions verified peer to trusted', () {
      service.verify(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'peer_A');
      final trusted = service.trust(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
      );

      expect(trusted.state, TrustState.trusted);
      expect(service.isTrusted('peer_A'), isTrue);
      expect(service.canCommunicate('peer_A'), isTrue);
    });

    test('revoke transitions trusted peer to revoked', () {
      service.verify(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'peer_A');
      service.trust(peerIdentityId: 'peer_A', at: DateTime.now());
      final revoked = service.revoke(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
        reason: 'compromised',
      );

      expect(revoked.state, TrustState.revoked);
      expect(service.isTrusted('peer_A'), isFalse);
      expect(service.canCommunicate('peer_A'), isFalse);
    });

    test('verify throws for already verified peer', () {
      service.verify(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      expect(
        () => service.verify(
          peerIdentityId: 'peer_A',
          at: DateTime.now(),
          method: VerificationMethod.qrScan,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('trust throws for unknown peer', () {
      expect(
        () => service.trust(peerIdentityId: 'peer_A', at: DateTime.now()),
        throwsA(isA<StateError>()),
      );
    });

    test('revoke throws for unknown peer', () {
      expect(
        () => service.revoke(peerIdentityId: 'peer_A', at: DateTime.now()),
        throwsA(isA<StateError>()),
      );
    });

    test('getAll returns all trust records', () {
      service.verify(
        peerIdentityId: 'A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      service.verify(
        peerIdentityId: 'B',
        at: DateTime.now(),
        method: VerificationMethod.fingerprintComparison,
      );

      expect(service.getAll().length, 2);
    });

    test('getTrusted returns only trusted peers', () {
      service.verify(
        peerIdentityId: 'A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'A');
      service.trust(peerIdentityId: 'A', at: DateTime.now());

      service.verify(
        peerIdentityId: 'B',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );

      expect(service.getTrusted().length, 1);
      expect(service.getTrusted().first.peerIdentityId, 'A');
    });

    test('getVerified returns only verified peers', () {
      service.verify(
        peerIdentityId: 'A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'A');
      service.trust(peerIdentityId: 'A', at: DateTime.now());

      service.verify(
        peerIdentityId: 'B',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );

      expect(service.getVerified().length, 1);
      expect(service.getVerified().first.peerIdentityId, 'B');
    });

    test('getRevoked returns only revoked peers', () {
      service.verify(
        peerIdentityId: 'A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      service.revoke(peerIdentityId: 'A', at: DateTime.now());

      service.verify(
        peerIdentityId: 'B',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );

      expect(service.getRevoked().length, 1);
      expect(service.getRevoked().first.peerIdentityId, 'A');
    });

    test('count returns number of trust records', () {
      expect(service.count, 0);
      service.verify(
        peerIdentityId: 'A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      expect(service.count, 1);
    });

    test('clear removes all trust records', () {
      service.verify(
        peerIdentityId: 'A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      service.clear();
      expect(service.count, 0);
      expect(service.getTrust('A').state, TrustState.unknown);
    });

    test('independent peers have independent trust', () {
      service.verify(
        peerIdentityId: 'A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'A');
      service.trust(peerIdentityId: 'A', at: DateTime.now());

      service.verify(
        peerIdentityId: 'B',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );

      expect(service.isTrusted('A'), isTrue);
      expect(service.isTrusted('B'), isFalse);
    });
  });

  // ── Security: no key in trust model ──────────────────────────

  group('Security properties', () {
    test('PeerTrust does not contain private key fields', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A');
      final str = trust.toString();
      expect(str, isNot(contains('privateKey')));
      expect(str, isNot(contains('secret')));
      expect(str, isNot(contains('seed')));
    });

    test('TrustService does not expose key material', () {
      final service = TrustService();
      service.verify(
        peerIdentityId: 'A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      final all = service.getAll();
      expect(all.length, 1);
      expect(all.first.peerIdentityId, 'A');
    });

    test('trust is anchored to identity, not display name', () {
      final service = TrustService();
      service.verify(
        peerIdentityId: 'identity_A_hex_public_key',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'identity_A_hex_public_key');
      service.trust(
        peerIdentityId: 'identity_A_hex_public_key',
        at: DateTime.now(),
      );

      // Different display name, same identity → still trusted
      expect(service.isTrusted('identity_A_hex_public_key'), isTrue);
      // Same display name, different identity → not trusted
      expect(service.isTrusted('identity_B_hex_public_key'), isFalse);
    });
  });

  // ── Full lifecycle ───────────────────────────────────────────

  group('Full lifecycle', () {
    test('complete lifecycle: unknown → verified → trusted → revoked', () {
      final service = TrustService();

      // Start unknown
      var trust = service.getTrust('peer_X');
      expect(trust.state, TrustState.unknown);

      // Verify
      trust = service.verify(
        peerIdentityId: 'peer_X',
        at: DateTime(2025, 1, 1),
        method: VerificationMethod.qrScan,
      );
      expect(trust.state, TrustState.verified);

      // Authenticate
      service.markAuthenticated(peerIdentityId: 'peer_X');

      // Trust
      trust = service.trust(
        peerIdentityId: 'peer_X',
        at: DateTime(2025, 1, 2),
      );
      expect(trust.state, TrustState.trusted);
      expect(service.canCommunicate('peer_X'), isTrue);

      // Revoke
      trust = service.revoke(
        peerIdentityId: 'peer_X',
        at: DateTime(2025, 1, 3),
        reason: 'key compromised',
      );
      expect(trust.state, TrustState.revoked);
      expect(service.canCommunicate('peer_X'), isFalse);
      expect(trust.revokedAt, DateTime(2025, 1, 3));
      expect(trust.revokeReason, 'key compromised');
    });

    test('verify → revoke lifecycle', () {
      final service = TrustService();

      service.verify(
        peerIdentityId: 'Y',
        at: DateTime.now(),
        method: VerificationMethod.fingerprintComparison,
      );
      service.revoke(peerIdentityId: 'Y', at: DateTime.now());

      expect(service.isTrusted('Y'), isFalse);
      expect(service.getRevoked().length, 1);
    });
  });
}
