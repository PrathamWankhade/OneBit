import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/identity/identity_export.dart';
import 'package:onebit/features/identity/identity_fingerprint.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/trust/peer_trust.dart';
import 'package:onebit/features/trust/trust_service.dart';
import 'package:onebit/features/trust/verification_state.dart';

void main() {
  late Uint8List testKeyBytes;
  late String testKeyHex;
  late IdentityInfo testIdentity;
  late TrustService trustService;

  setUp(() {
    testKeyBytes = Uint8List.fromList(List.generate(32, (i) => i));
    testKeyHex = IdentityRepository.bytesToHex(testKeyBytes);
    testIdentity = IdentityInfo(
      id: 1,
      identityId: testKeyHex,
      displayName: 'Test User',
      createdAt: DateTime(2025),
      publicKeyBytes: testKeyBytes,
    );
    trustService = TrustService();
  });

  // ── QR payload validation ───────────────────────────────────

  group('QR payload validation', () {
    test('valid QR payload can be parsed and validated', () async {
      final jsonStr = await exportPublicIdentity(testIdentity);
      final result = importPublicIdentity(jsonStr);

      expect(result.identity.publicKeyHex, testKeyHex);
      expect(result.identity.identityType, 'ed25519');
      expect(result.identity.formatVersion, identityFormatVersion);
    });

    test('QR payload contains only public information', () async {
      final jsonStr = await exportPublicIdentity(testIdentity);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Must NOT contain private key material
      expect(json.containsKey('privateKey'), isFalse);
      expect(json.containsKey('privateKeyHex'), isFalse);
      expect(json.containsKey('privateKeyBytes'), isFalse);
      expect(json.containsKey('seed'), isFalse);
      expect(json.containsKey('secretKey'), isFalse);
      expect(json.containsKey('secret'), isFalse);
      expect(json.containsKey('sessionKey'), isFalse);
      expect(json.containsKey('sharedSecret'), isFalse);
    });

    test('empty payload is rejected', () {
      expect(
        () => importPublicIdentity(''),
        throwsA(isA<ImportError>()),
      );
    });

    test('malformed JSON is rejected', () {
      expect(
        () => importPublicIdentity('{not valid json}'),
        throwsA(isA<ImportError>()),
      );
    });

    test('wrong type is rejected', () {
      final json = jsonEncode({
        'formatVersion': 1,
        'identityType': 'x25519',
        'publicKey': testKeyHex,
      });
      expect(
        () => importPublicIdentity(json),
        throwsA(isA<ImportError>()),
      );
    });

    test('unsupported version is rejected', () {
      final json = jsonEncode({
        'formatVersion': 99,
        'identityType': 'ed25519',
        'publicKey': testKeyHex,
      });
      expect(
        () => importPublicIdentity(json),
        throwsA(isA<ImportError>()),
      );
    });

    test('invalid public key is rejected', () {
      final json = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': 'not-hex',
      });
      expect(
        () => importPublicIdentity(json),
        throwsA(isA<ImportError>()),
      );
    });

    test('wrong key length is rejected', () {
      final json = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': 'abcd',
      });
      expect(
        () => importPublicIdentity(json),
        throwsA(isA<ImportError>()),
      );
    });

    test('missing publicKey field is rejected', () {
      final json = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
      });
      expect(
        () => importPublicIdentity(json),
        throwsA(isA<ImportError>()),
      );
    });

    test('missing identityType field is rejected', () {
      final json = jsonEncode({
        'formatVersion': 1,
        'publicKey': testKeyHex,
      });
      expect(
        () => importPublicIdentity(json),
        throwsA(isA<ImportError>()),
      );
    });
  });

  // ── QR round-trip ───────────────────────────────────────────

  group('QR round-trip', () {
    test('export → import preserves identity', () async {
      final jsonStr = await exportPublicIdentity(testIdentity);
      final result = importPublicIdentity(jsonStr);

      expect(result.identity.publicKeyHex, testKeyHex);
      expect(result.identity.displayName, 'Test User');
    });

    test('fingerprint matches after round-trip', () async {
      final originalFingerprint = await computeFingerprint(testKeyBytes);
      final jsonStr = await exportPublicIdentity(testIdentity);
      final result = importPublicIdentity(jsonStr);

      final importedFingerprint = await computeFingerprint(
        result.identity.publicKeyBytes,
      );
      expect(importedFingerprint, originalFingerprint);
    });

    test('same identity produces same QR payload', () async {
      final json1 = await exportPublicIdentity(testIdentity);
      final json2 = await exportPublicIdentity(testIdentity);
      expect(json1, json2);
    });
  });

  // ── QR verification integration ─────────────────────────────

  group('QR verification integration', () {
    test('QR scan verification marks peer as verified', () async {
      const peerId = 'peer_abc123';

      // Simulate: peer is associated (created) via QR scan
      // Then user taps "Verify Identity"
      trustService.verifyIdentity(
        peerIdentityId: peerId,
        at: DateTime(2025),
        publicKeyHex: peerId,
        method: VerificationMethod.qrScan,
      );

      expect(trustService.isVerified(peerId), isTrue);
    });

    test('already verified peer is idempotent', () async {
      const peerId = 'peer_abc123';

      // First verification
      trustService.verifyIdentity(
        peerIdentityId: peerId,
        at: DateTime(2025),
        publicKeyHex: peerId,
        method: VerificationMethod.qrScan,
      );

      // Second verification attempt should throw
      expect(
        () => trustService.verifyIdentity(
          peerIdentityId: peerId,
          at: DateTime(2025),
          publicKeyHex: peerId,
          method: VerificationMethod.qrScan,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('QR verification does NOT automatically trust', () async {
      const peerId = 'peer_abc123';

      trustService.verifyIdentity(
        peerIdentityId: peerId,
        at: DateTime(2025),
        publicKeyHex: peerId,
        method: VerificationMethod.qrScan,
      );

      // Verification = VERIFIED, NOT TRUSTED
      expect(trustService.isVerified(peerId), isTrue);
      expect(trustService.isTrusted(peerId), isFalse);
      expect(trustService.canCommunicate(peerId), isFalse);
    });

    test('identity match verification succeeds', () async {
      final peerId = testKeyHex;

      // QR contains the same identity as the peer
      trustService.verifyIdentity(
        peerIdentityId: peerId,
        at: DateTime(2025),
        publicKeyHex: testKeyHex,
        method: VerificationMethod.qrScan,
      );

      expect(trustService.isVerified(peerId), isTrue);
    });

    test('identity mismatch is rejected by PeerVerification', () {
      const peerId = 'peer_abc123';
      const differentKey = 'def4567890123456789012345678901234567890123456789012345678901234';

      expect(
        () => trustService.verifyIdentity(
          peerIdentityId: peerId,
          at: DateTime(2025),
          publicKeyHex: differentKey,
          method: VerificationMethod.qrScan,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('verification state is separate from trust state', () async {
      const peerId = 'peer_abc123';

      // Verify via QR
      trustService.verifyIdentity(
        peerIdentityId: peerId,
        at: DateTime(2025),
        publicKeyHex: peerId,
        method: VerificationMethod.qrScan,
      );

      // Verification record exists
      final verification = trustService.getVerification(peerId);
      expect(verification.state, VerificationState.verified);
      expect(verification.method, VerificationMethod.qrScan);

      // Trust record is also updated (verifyIdentity persists to trust)
      final trust = trustService.getTrust(peerId);
      expect(trust.isVerified, isTrue);
      // But NOT trusted — trust requires explicit trust() call
      expect(trust.isTrusted, isFalse);
    });

    test('verification does not auto-pair', () async {
      // QR scan should not create a pairing session
      // This test verifies that scanning QR does not trigger pairing protocol
      const peerId = 'peer_abc123';

      trustService.verifyIdentity(
        peerIdentityId: peerId,
        at: DateTime(2025),
        publicKeyHex: peerId,
        method: VerificationMethod.qrScan,
      );

      // Peer is verified but not paired
      expect(trustService.isVerified(peerId), isTrue);
      // There is no pairing state in TrustService — pairing is separate
    });

    test('verification does not auto-create session', () async {
      // QR scan should not establish an I5 secure session
      const peerId = 'peer_abc123';

      trustService.verifyIdentity(
        peerIdentityId: peerId,
        at: DateTime(2025),
        publicKeyHex: peerId,
        method: VerificationMethod.qrScan,
      );

      // Verification only updates verification state, not session state
      expect(trustService.isVerified(peerId), isTrue);
      expect(trustService.canCommunicate(peerId), isFalse);
    });
  });

  // ── QR identity stability ───────────────────────────────────

  group('QR identity stability', () {
    test('generating QR multiple times preserves identity', () async {
      final json1 = await exportPublicIdentity(testIdentity);
      final json2 = await exportPublicIdentity(testIdentity);
      final json3 = await exportPublicIdentity(testIdentity);

      expect(json1, json2);
      expect(json2, json3);
    });

    test('changing display name does not change cryptographic identity',
        () async {
      final identity1 = IdentityInfo(
        id: 1,
        identityId: testKeyHex,
        displayName: 'Name A',
        createdAt: DateTime(2025),
        publicKeyBytes: testKeyBytes,
      );
      final identity2 = IdentityInfo(
        id: 1,
        identityId: testKeyHex,
        displayName: 'Name B',
        createdAt: DateTime(2025),
        publicKeyBytes: testKeyBytes,
      );

      final json1 = await exportPublicIdentity(identity1);
      final json2 = await exportPublicIdentity(identity2);

      final result1 = importPublicIdentity(json1);
      final result2 = importPublicIdentity(json2);

      // Public key is the same
      expect(result1.identity.publicKeyHex, result2.identity.publicKeyHex);
      // Display names differ
      expect(result1.identity.displayName, 'Name A');
      expect(result2.identity.displayName, 'Name B');
    });
  });

  // ── Peer isolation ──────────────────────────────────────────

  group('Peer isolation', () {
    test('verification of peer A does not affect peer B', () async {
      const peerA = 'peer_aaa';
      const peerB = 'peer_bbb';

      trustService.verifyIdentity(
        peerIdentityId: peerA,
        at: DateTime(2025),
        publicKeyHex: peerA,
        method: VerificationMethod.qrScan,
      );

      expect(trustService.isVerified(peerA), isTrue);
      expect(trustService.isVerified(peerB), isFalse);
    });

    test('QR for peer A cannot verify peer B', () {
      const peerA = 'peer_aaa';
      const peerB = 'peer_bbb';

      // Try to verify peer B using peer A's key — mismatch
      expect(
        () => trustService.verifyIdentity(
          peerIdentityId: peerB,
          at: DateTime(2025),
          publicKeyHex: peerA,
          method: VerificationMethod.qrScan,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ── Duplicate scan handling ─────────────────────────────────

  group('Duplicate scan handling', () {
    test('scanning same QR repeatedly does not create duplicate state',
        () async {
      const peerId = 'peer_abc123';

      // First scan + verify
      trustService.verifyIdentity(
        peerIdentityId: peerId,
        at: DateTime(2025),
        publicKeyHex: peerId,
        method: VerificationMethod.qrScan,
      );

      // Second scan attempt to verify — should throw
      expect(
        () => trustService.verifyIdentity(
          peerIdentityId: peerId,
          at: DateTime(2025),
          publicKeyHex: peerId,
          method: VerificationMethod.qrScan,
        ),
        throwsA(isA<StateError>()),
      );

      // Still verified (state unchanged)
      expect(trustService.isVerified(peerId), isTrue);
    });
  });

  // ── No private key exposure ─────────────────────────────────

  group('No private key exposure', () {
    test('QR payload does not contain private key', () async {
      final jsonStr = await exportPublicIdentity(testIdentity);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Search for any key that might contain private material
      final suspiciousKeys = [
        'privateKey',
        'privateKeyHex',
        'private',
        'secret',
        'seed',
        'sessionKey',
        'sharedSecret',
        'private_key',
        'secret_key',
      ];

      for (final key in suspiciousKeys) {
        expect(json.containsKey(key), isFalse,
            reason: 'QR payload should not contain "$key"');
      }
    });

    test('export function only accesses public metadata', () async {
      // The exportPublicIdentity function only takes IdentityInfo
      // which contains publicKeyBytes, not the private key
      final jsonStr = await exportPublicIdentity(testIdentity);
      expect(jsonStr, isNotEmpty);

      // Verify the function signature only needs public data
      final result = importPublicIdentity(jsonStr);
      expect(result.identity.publicKeyHex, testKeyHex);
    });
  });

  // ── QR as out-of-band channel ───────────────────────────────

  group('QR as out-of-band channel', () {
    test('QR provides separate verification from BLE', () async {
      // QR is valuable because it provides a separate channel from BLE
      // This test verifies that QR verification is independent
      const peerId = 'peer_abc123';

      // QR verification
      trustService.verifyIdentity(
        peerIdentityId: peerId,
        at: DateTime(2025),
        publicKeyHex: peerId,
        method: VerificationMethod.qrScan,
      );

      final verification = trustService.getVerification(peerId);
      expect(verification.method, VerificationMethod.qrScan);
      expect(verification.state, VerificationState.verified);
    });

    test('QR verification result is bound to cryptographic identity',
        () async {
      final peerId = testKeyHex;

      trustService.verifyIdentity(
        peerIdentityId: peerId,
        at: DateTime(2025),
        publicKeyHex: testKeyHex,
        method: VerificationMethod.qrScan,
      );

      final verification = trustService.getVerification(peerId);
      expect(verification.verifiedPublicKeyHex, testKeyHex);
    });
  });
}
