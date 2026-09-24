import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/trust/peer_trust.dart';
import 'package:onebit/features/trust/peer_verification.dart';
import 'package:onebit/features/trust/trust_service.dart';
import 'package:onebit/features/trust/trust_state.dart';
import 'package:onebit/features/trust/verification_state.dart';

void main() {
  // ── VerificationState enum ────────────────────────────────────

  group('VerificationState', () {
    test('has 3 expected states', () {
      expect(VerificationState.values.length, 3);
      expect(
        VerificationState.values,
        contains(VerificationState.unverified),
      );
      expect(
        VerificationState.values,
        contains(VerificationState.verificationRequired),
      );
      expect(
        VerificationState.values,
        contains(VerificationState.verified),
      );
    });
  });

  // ── PeerVerification construction ─────────────────────────────

  group('PeerVerification construction', () {
    test('unverified factory creates unverified state', () {
      final v = PeerVerification.unverified(peerIdentityId: 'key_A');
      expect(v.peerIdentityId, 'key_A');
      expect(v.state, VerificationState.unverified);
      expect(v.isUnverified, isTrue);
      expect(v.isVerified, isFalse);
      expect(v.verifiedPublicKeyHex, isNull);
      expect(v.verifiedAt, isNull);
      expect(v.method, isNull);
    });

    test('verificationRequired factory creates correct state', () {
      final v = PeerVerification.verificationRequired(
        peerIdentityId: 'key_A',
      );
      expect(v.state, VerificationState.verificationRequired);
      expect(v.isVerificationRequired, isTrue);
    });
  });

  // ── State transitions ─────────────────────────────────────────

  group('PeerVerification state transitions', () {
    test('unverified → verificationRequired', () {
      final v = PeerVerification.unverified(peerIdentityId: 'key_A');
      final updated = v.requireVerification();
      expect(updated.state, VerificationState.verificationRequired);
      expect(v.state, VerificationState.unverified); // original unchanged
    });

    test('unverified → verified (skip verificationRequired)', () {
      final v = PeerVerification.unverified(peerIdentityId: 'key_A');
      final updated = v.markVerified(
        at: DateTime(2026),
        publicKeyHex: 'key_A',
        method: VerificationMethod.qrScan,
      );
      expect(updated.state, VerificationState.verified);
      expect(updated.verifiedPublicKeyHex, 'key_A');
      expect(updated.method, VerificationMethod.qrScan);
    });

    test('verificationRequired → verified', () {
      final v = PeerVerification.verificationRequired(
        peerIdentityId: 'key_A',
      );
      final updated = v.markVerified(
        at: DateTime(2026),
        publicKeyHex: 'key_A',
        method: VerificationMethod.fingerprintComparison,
      );
      expect(updated.state, VerificationState.verified);
      expect(updated.method, VerificationMethod.fingerprintComparison);
    });
  });

  // ── Invalid transitions ───────────────────────────────────────

  group('PeerVerification invalid transitions', () {
    test('verificationRequired → requireVerification throws', () {
      final v = PeerVerification.verificationRequired(
        peerIdentityId: 'key_A',
      );
      expect(() => v.requireVerification(), throwsStateError);
    });

    test('verified → requireVerification throws', () {
      final v = PeerVerification.unverified(peerIdentityId: 'key_A')
          .markVerified(
        at: DateTime(2026),
        publicKeyHex: 'key_A',
        method: VerificationMethod.qrScan,
      );
      expect(() => v.requireVerification(), throwsStateError);
    });

    test('verified → markVerified throws (already verified)', () {
      final v = PeerVerification.unverified(peerIdentityId: 'key_A')
          .markVerified(
        at: DateTime(2026),
        publicKeyHex: 'key_A',
        method: VerificationMethod.qrScan,
      );
      expect(
        () => v.markVerified(
          at: DateTime(2026),
          publicKeyHex: 'key_A',
          method: VerificationMethod.qrScan,
        ),
        throwsStateError,
      );
    });

    test('markVerified with wrong key throws ArgumentError', () {
      final v = PeerVerification.unverified(peerIdentityId: 'key_A');
      expect(
        () => v.markVerified(
          at: DateTime(2026),
          publicKeyHex: 'key_B',
          method: VerificationMethod.qrScan,
        ),
        throwsArgumentError,
      );
    });
  });

  // ── Identity mismatch ─────────────────────────────────────────

  group('PeerVerification identity mismatch', () {
    test('publicKeyHex must match peerIdentityId', () {
      final v = PeerVerification.unverified(peerIdentityId: 'real_key');
      expect(
        () => v.markVerified(
          at: DateTime(2026),
          publicKeyHex: 'different_key',
          method: VerificationMethod.qrScan,
        ),
        throwsArgumentError,
      );
    });

    test('verifiedPublicKeyHex matches peerIdentityId', () {
      final v = PeerVerification.unverified(peerIdentityId: 'key_A')
          .markVerified(
        at: DateTime(2026),
        publicKeyHex: 'key_A',
        method: VerificationMethod.qrScan,
      );
      expect(v.verifiedPublicKeyHex, v.peerIdentityId);
    });
  });

  // ── Immutability ──────────────────────────────────────────────

  group('PeerVerification immutability', () {
    test('original unchanged after requireVerification', () {
      final original = PeerVerification.unverified(peerIdentityId: 'k');
      original.requireVerification();
      expect(original.state, VerificationState.unverified);
    });

    test('original unchanged after markVerified', () {
      final original = PeerVerification.unverified(peerIdentityId: 'k');
      original.markVerified(
        at: DateTime(2026),
        publicKeyHex: 'k',
        method: VerificationMethod.qrScan,
      );
      expect(original.state, VerificationState.unverified);
    });
  });

  // ── Equality ──────────────────────────────────────────────────

  group('PeerVerification equality', () {
    test('same identity and state are equal', () {
      final a = PeerVerification.unverified(peerIdentityId: 'k');
      final b = PeerVerification.unverified(peerIdentityId: 'k');
      expect(a, equals(b));
    });

    test('same identity different state are not equal', () {
      final a = PeerVerification.unverified(peerIdentityId: 'k');
      final b = PeerVerification.verificationRequired(peerIdentityId: 'k');
      expect(a, isNot(equals(b)));
    });

    test('different identity same state are not equal', () {
      final a = PeerVerification.unverified(peerIdentityId: 'k1');
      final b = PeerVerification.unverified(peerIdentityId: 'k2');
      expect(a, isNot(equals(b)));
    });
  });

  // ── toString ──────────────────────────────────────────────────

  group('PeerVerification toString', () {
    test('shows truncated ID and state', () {
      final v = PeerVerification.unverified(peerIdentityId: 'abcdefghijklmnop');
      expect(v.toString(), startsWith('PeerVerification(abcdefgh…, unverified)'));
    });

    test('shows full ID when short', () {
      final v = PeerVerification.unverified(peerIdentityId: 'short');
      expect(v.toString(), contains('short'));
    });
  });

  // ── Trust separation ──────────────────────────────────────────

  group('Trust separation', () {
    test('TrustState enum has 4 states (not verification states)', () {
      expect(TrustState.values.length, 4);
    });

    test('VerificationState enum has 3 states (not trust states)', () {
      expect(VerificationState.values.length, 3);
    });

    test('PeerTrust and PeerVerification are separate types', () {
      const trust = PeerTrust(
        peerIdentityId: 'k',
        state: TrustState.verified,
      );
      const v = PeerVerification(
        peerIdentityId: 'k',
        state: VerificationState.verified,
      );
      expect(trust.runtimeType, isNot(equals(v.runtimeType)));
    });
  });

  // ── TrustService verification methods ─────────────────────────

  group('TrustService verification', () {
    late TrustService service;

    setUp(() {
      service = TrustService();
    });

    test('getVerification returns unverified for unknown peer', () {
      final v = service.getVerification('peer_A');
      expect(v.state, VerificationState.unverified);
      expect(v.peerIdentityId, 'peer_A');
    });

    test('isVerified returns false for unknown peer', () {
      expect(service.isVerified('peer_A'), isFalse);
    });

    test('requireVerification transitions to verificationRequired', () {
      final v = service.requireVerification('peer_A');
      expect(v.state, VerificationState.verificationRequired);
      expect(service.getVerification('peer_A').isVerificationRequired, isTrue);
    });

    test('verifyIdentity marks peer as verified', () {
      service.requireVerification('peer_A');
      final v = service.verifyIdentity(
        peerIdentityId: 'peer_A',
        at: DateTime(2026),
        publicKeyHex: 'peer_A',
        method: VerificationMethod.qrScan,
      );
      expect(v.state, VerificationState.verified);
      expect(service.isVerified('peer_A'), isTrue);
    });

    test('verifyIdentity rejects wrong public key', () {
      service.requireVerification('peer_A');
      expect(
        () => service.verifyIdentity(
          peerIdentityId: 'peer_A',
          at: DateTime(2026),
          publicKeyHex: 'wrong_key',
          method: VerificationMethod.qrScan,
        ),
        throwsArgumentError,
      );
    });

    test('verify from unverified works without requireVerification', () {
      final v = service.verifyIdentity(
        peerIdentityId: 'peer_A',
        at: DateTime(2026),
        publicKeyHex: 'peer_A',
        method: VerificationMethod.fingerprintComparison,
      );
      expect(v.state, VerificationState.verified);
    });

    test('clear removes verification records', () {
      service.requireVerification('peer_A');
      service.clear();
      expect(service.getVerification('peer_A').isUnverified, isTrue);
    });

    test('independent peers have independent verification', () {
      service.requireVerification('peer_A');
      service.verifyIdentity(
        peerIdentityId: 'peer_B',
        at: DateTime(2026),
        publicKeyHex: 'peer_B',
        method: VerificationMethod.qrScan,
      );
      expect(service.isVerified('peer_A'), isFalse);
      expect(service.isVerified('peer_B'), isTrue);
    });
  });

  // ── Security properties ───────────────────────────────────────

  group('Security properties', () {
    test('PeerVerification does not contain private key fields', () {
      final v = PeerVerification.unverified(peerIdentityId: 'k');
      final fields = v.toString();
      expect(fields, isNot(contains('privateKey')));
      expect(fields, isNot(contains('sessionKey')));
      expect(fields, isNot(contains('sharedSecret')));
    });

    test('verification does not automatically establish trust', () {
      final service = TrustService();
      service.verifyIdentity(
        peerIdentityId: 'peer_A',
        at: DateTime(2026),
        publicKeyHex: 'peer_A',
        method: VerificationMethod.qrScan,
      );
      expect(service.isVerified('peer_A'), isTrue);
      expect(service.isTrusted('peer_A'), isFalse);
    });

    test('discovery does not automatically verify', () {
      final service = TrustService();
      // Simulating discovery — getVerification returns unverified
      expect(service.isVerified('peer_A'), isFalse);
    });

    test('encrypted session does not change verification state', () {
      final service = TrustService();
      service.requireVerification('peer_A');
      // Simulating session — no verification methods called
      expect(service.isVerified('peer_A'), isFalse);
      expect(
        service.getVerification('peer_A').state,
        VerificationState.verificationRequired,
      );
    });
  });

  // ── Full lifecycle ────────────────────────────────────────────

  group('Full lifecycle', () {
    test('complete verification lifecycle', () {
      final service = TrustService();

      // 1. Peer discovered → unverified
      expect(service.isVerified('peer_A'), isFalse);

      // 2. Verification required
      service.requireVerification('peer_A');
      expect(
        service.getVerification('peer_A').isVerificationRequired,
        isTrue,
      );

      // 3. Identity verified via QR (verification layer)
      service.verifyIdentity(
        peerIdentityId: 'peer_A',
        at: DateTime(2026),
        publicKeyHex: 'peer_A',
        method: VerificationMethod.qrScan,
      );
      expect(service.isVerified('peer_A'), isTrue);

      // 4. Verified but NOT trusted
      expect(service.isTrusted('peer_A'), isFalse);

      // 5. Trust established separately (trust layer requires verified + authenticated)
      // Note: verifyIdentity() already transitioned trust to verified.
      service.markAuthenticated(peerIdentityId: 'peer_A');
      service.trust(peerIdentityId: 'peer_A', at: DateTime(2026));
      expect(service.isTrusted('peer_A'), isTrue);
      expect(service.isVerified('peer_A'), isTrue);
    });

    test('verification → revoke trust leaves verification intact', () {
      final service = TrustService();
      service.verifyIdentity(
        peerIdentityId: 'peer_A',
        at: DateTime(2026),
        publicKeyHex: 'peer_A',
        method: VerificationMethod.qrScan,
      );
      // Note: verifyIdentity() already transitioned trust to verified.
      service.markAuthenticated(peerIdentityId: 'peer_A');
      service.trust(peerIdentityId: 'peer_A', at: DateTime(2026));
      service.revoke(peerIdentityId: 'peer_A', at: DateTime(2026));
      expect(service.isTrusted('peer_A'), isFalse);
      expect(service.isVerified('peer_A'), isTrue);
    });
  });
}
