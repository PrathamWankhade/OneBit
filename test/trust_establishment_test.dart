import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/trust/peer_trust.dart';
import 'package:onebit/features/trust/trust_service.dart';
import 'package:onebit/features/trust/trust_state.dart';

void main() {
  // ── PeerTrust.markAuthenticated ─────────────────────────────

  group('PeerTrust.markAuthenticated', () {
    test('marks unknown peer as authenticated', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A');
      final auth = trust.markAuthenticated();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.state, TrustState.unknown);
    });

    test('marks verified peer as authenticated', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan);
      final auth = trust.markAuthenticated();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.state, TrustState.verified);
    });

    test('idempotent: already authenticated returns same instance', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .markAuthenticated();
      final same = trust.markAuthenticated();

      expect(identical(trust, same), isTrue);
    });

    test('cannot authenticate revoked peer', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan)
          .revoke(at: DateTime.now());
      expect(
        () => trust.markAuthenticated(),
        throwsA(isA<StateError>()),
      );
    });

    test('preserves existing fields after authentication', () {
      final now = DateTime.now();
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: now, method: VerificationMethod.qrScan);
      final auth = trust.markAuthenticated();

      expect(auth.peerIdentityId, 'A');
      expect(auth.verifiedAt, now);
      expect(auth.verificationMethod, VerificationMethod.qrScan);
    });

    test('preserves trusted state after authentication', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan);
      final auth = trust.markAuthenticated();
      expect(auth.state, TrustState.verified);
    });

    test('preserves revoked state after authentication', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan)
          .revoke(at: DateTime.now(), reason: 'bad');
      expect(
        () => trust.markAuthenticated(),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ── PeerTrust.trust with authentication ─────────────────────

  group('PeerTrust.trust with authentication', () {
    test('verified + authenticated → trusted', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan)
          .markAuthenticated();
      final trusted = trust.trust(at: DateTime.now());

      expect(trusted.state, TrustState.trusted);
      expect(trusted.isAuthenticated, isTrue);
      expect(trusted.verificationMethod, VerificationMethod.qrScan);
    });

    test('verified but NOT authenticated → throws', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan);
      expect(
        () => trust.trust(at: DateTime.now()),
        throwsA(isA<StateError>()),
      );
    });

    test('authenticated but NOT verified → throws', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .markAuthenticated();
      expect(
        () => trust.trust(at: DateTime.now()),
        throwsA(isA<StateError>()),
      );
    });

    test('unknown peer → throws even with authentication', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .markAuthenticated();
      expect(
        () => trust.trust(at: DateTime.now()),
        throwsA(isA<StateError>()),
      );
    });

    test('trusted peer preserves authentication', () {
      final trust = PeerTrust.unknown(peerIdentityId: 'A')
          .verify(at: DateTime.now(), method: VerificationMethod.qrScan)
          .markAuthenticated()
          .trust(at: DateTime.now());

      expect(trust.isTrusted, isTrue);
      expect(trust.isAuthenticated, isTrue);
    });
  });

  // ── TrustService authentication ─────────────────────────────

  group('TrustService.markAuthenticated', () {
    late TrustService service;

    setUp(() {
      service = TrustService();
    });

    test('marks peer as authenticated', () {
      service.markAuthenticated(peerIdentityId: 'peer_A');
      expect(service.isAuthenticated('peer_A'), isTrue);
    });

    test('default peer is not authenticated', () {
      expect(service.isAuthenticated('peer_A'), isFalse);
    });

    test('verified peer can be authenticated', () {
      service.verify(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'peer_A');
      expect(service.isAuthenticated('peer_A'), isTrue);
    });

    test('unverified peer can still be authenticated', () {
      service.markAuthenticated(peerIdentityId: 'peer_A');
      expect(service.isAuthenticated('peer_A'), isTrue);
      // But cannot be trusted without verification
      expect(
        () => service.establishTrust(
          peerIdentityId: 'peer_A',
          at: DateTime.now(),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ── TrustService.canEstablishTrust ──────────────────────────

  group('TrustService.canEstablishTrust', () {
    late TrustService service;

    setUp(() {
      service = TrustService();
    });

    test('returns false for unknown peer', () {
      expect(service.canEstablishTrust('peer_A'), isFalse);
    });

    test('returns false when verified but not authenticated', () {
      service.verify(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      expect(service.canEstablishTrust('peer_A'), isFalse);
    });

    test('returns false when authenticated but not verified', () {
      service.markAuthenticated(peerIdentityId: 'peer_A');
      expect(service.canEstablishTrust('peer_A'), isFalse);
    });

    test('returns true when both verified and authenticated', () {
      service.verify(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'peer_A');
      expect(service.canEstablishTrust('peer_A'), isTrue);
    });

    test('returns false when revoked', () {
      service.verify(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'peer_A');
      service.establishTrust(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
      );
      service.revoke(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
        reason: 'bad',
      );
      expect(service.canEstablishTrust('peer_A'), isFalse);
    });
  });

  // ── TrustService.establishTrust ─────────────────────────────

  group('TrustService.establishTrust', () {
    late TrustService service;

    setUp(() {
      service = TrustService();
    });

    test('establishes trust when verified and authenticated', () {
      service.verify(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'peer_A');
      final trust = service.establishTrust(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
      );

      expect(trust.state, TrustState.trusted);
      expect(service.isTrusted('peer_A'), isTrue);
    });

    test('idempotent when already trusted', () {
      service.verify(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'peer_A');
      service.establishTrust(
        peerIdentityId: 'peer_A',
        at: DateTime(2025, 1, 1),
      );
      final second = service.establishTrust(
        peerIdentityId: 'peer_A',
        at: DateTime(2025, 6, 1),
      );

      expect(second.trustedAt, DateTime(2025, 1, 1));
    });

    test('throws when not verified', () {
      service.markAuthenticated(peerIdentityId: 'peer_A');
      expect(
        () => service.establishTrust(
          peerIdentityId: 'peer_A',
          at: DateTime.now(),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when not authenticated', () {
      service.verify(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      expect(
        () => service.establishTrust(
          peerIdentityId: 'peer_A',
          at: DateTime.now(),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when revoked', () {
      service.verify(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'peer_A');
      service.establishTrust(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
      );
      service.revoke(
        peerIdentityId: 'peer_A',
        at: DateTime.now(),
        reason: 'compromised',
      );
      expect(
        () => service.establishTrust(
          peerIdentityId: 'peer_A',
          at: DateTime.now(),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ── Full trust establishment lifecycle ──────────────────────

  group('Full trust establishment lifecycle', () {
    test('verify → authenticate → trust → revoke', () {
      final service = TrustService();

      var trust = service.getTrust('peer_X');
      expect(trust.state, TrustState.unknown);
      expect(service.isAuthenticated('peer_X'), isFalse);

      trust = service.verify(
        peerIdentityId: 'peer_X',
        at: DateTime(2025, 1, 1),
        method: VerificationMethod.qrScan,
      );
      expect(trust.state, TrustState.verified);
      expect(service.canEstablishTrust('peer_X'), isFalse);

      service.markAuthenticated(peerIdentityId: 'peer_X');
      expect(service.isAuthenticated('peer_X'), isTrue);
      expect(service.canEstablishTrust('peer_X'), isTrue);

      trust = service.establishTrust(
        peerIdentityId: 'peer_X',
        at: DateTime(2025, 1, 2),
      );
      expect(trust.state, TrustState.trusted);
      expect(service.isTrusted('peer_X'), isTrue);
      expect(service.canCommunicate('peer_X'), isTrue);

      trust = service.revoke(
        peerIdentityId: 'peer_X',
        at: DateTime(2025, 1, 3),
        reason: 'key compromised',
      );
      expect(trust.state, TrustState.revoked);
      expect(service.isTrusted('peer_X'), isFalse);
      expect(service.canCommunicate('peer_X'), isFalse);
      expect(service.isAuthenticated('peer_X'), isTrue);
    });

    test('authenticate → verify → trust', () {
      final service = TrustService();

      service.markAuthenticated(peerIdentityId: 'peer_Y');
      expect(service.canEstablishTrust('peer_Y'), isFalse);

      service.verify(
        peerIdentityId: 'peer_Y',
        at: DateTime(2025, 1, 1),
        method: VerificationMethod.fingerprintComparison,
      );
      expect(service.canEstablishTrust('peer_Y'), isTrue);

      final trust = service.establishTrust(
        peerIdentityId: 'peer_Y',
        at: DateTime(2025, 1, 2),
      );
      expect(trust.state, TrustState.trusted);
      expect(trust.isAuthenticated, isTrue);
      expect(trust.verificationMethod, VerificationMethod.fingerprintComparison);
    });

    test('independent peers have independent trust', () {
      final service = TrustService();

      service.verify(
        peerIdentityId: 'A',
        at: DateTime.now(),
        method: VerificationMethod.qrScan,
      );
      service.markAuthenticated(peerIdentityId: 'A');
      service.establishTrust(
        peerIdentityId: 'A',
        at: DateTime.now(),
      );

      service.verify(
        peerIdentityId: 'B',
        at: DateTime.now(),
        method: VerificationMethod.fingerprintComparison,
      );
      service.markAuthenticated(peerIdentityId: 'B');

      expect(service.isTrusted('A'), isTrue);
      expect(service.isTrusted('B'), isFalse);
      expect(service.canEstablishTrust('B'), isTrue);
    });
  });
}
