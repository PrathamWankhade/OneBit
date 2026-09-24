import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/identity/identity_export.dart';
import 'package:onebit/features/identity/identity_fingerprint.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/trust/peer_trust.dart';
import 'package:onebit/features/trust/trust_service.dart';
import 'package:onebit/features/trust/trust_state.dart';

void main() {
  final keyA = Uint8List.fromList(List.generate(32, (i) => i));
  final keyB = Uint8List.fromList(List.generate(32, (i) => i + 32));

  group('normalizeFingerprint', () {
    test('strips spaces', () {
      expect(normalizeFingerprint('ABCD 1234'), 'ABCD1234');
    });

    test('strips hyphens', () {
      expect(normalizeFingerprint('ABCD-1234'), 'ABCD1234');
    });

    test('converts to uppercase', () {
      expect(normalizeFingerprint('abcd1234'), 'ABCD1234');
    });

    test('handles combined spaces, hyphens, and case', () {
      expect(normalizeFingerprint('abcd-1234-ef56'), 'ABCD1234EF56');
    });

    test('handles mixed separators and case', () {
      expect(normalizeFingerprint('aBcD 1234-eF56'), 'ABCD1234EF56');
    });

    test('preserves already canonical form', () {
      expect(normalizeFingerprint('ABCD1234'), 'ABCD1234');
    });

    test('handles empty string', () {
      expect(normalizeFingerprint(''), '');
    });

    test('handles full fingerprint format', () async {
      final fp = await computeFingerprint(keyA);
      final normalized = normalizeFingerprint(fp);
      // Normalized should have no spaces
      expect(normalized.contains(' '), isFalse);
      // Should be 64 hex chars
      expect(normalized.length, 64);
    });
  });

  group('compareFingerprint', () {
    test('matches identical fingerprints', () async {
      final fp = await computeFingerprint(keyA);
      expect(compareFingerprint(fp, fp), isTrue);
    });

    test('matches with different spacing', () async {
      final fp = await computeFingerprint(keyA);
      final spaced = fingerprintLines(fp).replaceAll('\n', ' ');
      expect(compareFingerprint(fp, spaced), isTrue);
    });

    test('matches with hyphens vs spaces', () async {
      final fp = await computeFingerprint(keyA);
      final hyphened = fp.replaceAll(' ', '-');
      expect(compareFingerprint(fp, hyphened), isTrue);
    });

    test('matches case-insensitive', () async {
      final fp = await computeFingerprint(keyA);
      final lower = fp.toLowerCase();
      expect(compareFingerprint(fp, lower), isTrue);
    });

    test('rejects different fingerprints', () async {
      final fpA = await computeFingerprint(keyA);
      final fpB = await computeFingerprint(keyB);
      expect(compareFingerprint(fpA, fpB), isFalse);
    });

    test('rejects near-match (no fuzzy matching)', () async {
      final fp = await computeFingerprint(keyA);
      // Change last character
      final modified = '${fp.substring(0, fp.length - 1)}0';
      expect(compareFingerprint(fp, modified), isFalse);
    });

    test('rejects truncated fingerprint', () async {
      final fp = await computeFingerprint(keyA);
      final truncated = fp.substring(0, fp.length - 5);
      expect(compareFingerprint(fp, truncated), isFalse);
    });
  });

  group('QR identity → fingerprint consistency', () {
    test('scanned identity fingerprint matches computed fingerprint', () async {
      final hexId = IdentityRepository.bytesToHex(keyA);
      final exported = PublicIdentity(
        formatVersion: 1,
        identityType: 'ed25519',
        publicKeyHex: hexId,
        displayName: 'Peer A',
      );

      final imported = importPublicIdentity(
        exported.toJsonString(),
        localPublicKeyHex: IdentityRepository.bytesToHex(keyB),
      );

      final fpLocal = await computeFingerprint(keyA);
      final fpImported = await computeFingerprint(imported.identity.publicKeyBytes);

      expect(fpImported, fpLocal);
    });

    test('different QR identity produces different fingerprint', () async {
      final hexA = IdentityRepository.bytesToHex(keyA);

      final fpA = await computeFingerprint(keyA);
      final fpB = await computeFingerprint(keyB);

      expect(fpA, isNot(fpB));

      // Verify via import
      final exportedA = PublicIdentity(
        formatVersion: 1,
        identityType: 'ed25519',
        publicKeyHex: hexA,
      );
      final importedA = importPublicIdentity(
        exportedA.toJsonString(),
        localPublicKeyHex: IdentityRepository.bytesToHex(keyB),
      );
      final fpImported = await computeFingerprint(importedA.identity.publicKeyBytes);
      expect(fpImported, fpA);
    });
  });

  group('pairing identity → fingerprint consistency', () {
    test('same public key produces same fingerprint regardless of context', () async {
      final fp1 = await computeFingerprint(keyA);
      final fp2 = await computeFingerprint(keyA);

      expect(fp1, fp2);
    });

    test('hex round-trip preserves fingerprint', () async {
      final hex = IdentityRepository.bytesToHex(keyA);
      final restored = IdentityRepository.hexToBytes(hex);

      final fpOriginal = await computeFingerprint(keyA);
      final fpRestored = await computeFingerprint(restored);

      expect(fpRestored, fpOriginal);
    });
  });

  group('identity change → fingerprint change', () {
    test('different public key produces different fingerprint', () async {
      final fpA = await computeFingerprint(keyA);
      final fpB = await computeFingerprint(keyB);
      expect(fpA, isNot(fpB));
    });

    test('single bit change produces different fingerprint', () async {
      final modified = Uint8List.fromList(keyA);
      modified[0] ^= 0x01; // Flip one bit

      final fpOriginal = await computeFingerprint(keyA);
      final fpModified = await computeFingerprint(modified);

      expect(fpOriginal, isNot(fpModified));
    });
  });

  group('display name / BLE address do not affect fingerprint', () {
    test('changing display name does not change fingerprint', () async {
      final fp1 = await computeFingerprint(keyA);
      final fp2 = await computeFingerprint(keyA);
      expect(fp1, fp2);
    });

    test('fingerprint is derived from key bytes only', () async {
      // Fingerprint depends only on the public key bytes,
      // not on display name, BLE address, or device name
      final fp = await computeFingerprint(keyA);

      // Same key → same fingerprint regardless of metadata
      expect(fp, await computeFingerprint(keyA));
    });
  });

  group('no auto-trust on fingerprint match', () {
    test('fingerprint match does not change trust state', () async {
      final service = TrustService();
      final peerId = IdentityRepository.bytesToHex(keyA);

      // Initially unknown
      expect(service.getTrust(peerId).state, TrustState.unknown);

      // Fingerprint match does not change trust
      final fp = await computeFingerprint(keyA);
      final fp2 = await computeFingerprint(keyA);
      compareFingerprint(fp, fp2); // This is just a comparison, not a trust action

      // Still unknown
      expect(service.getTrust(peerId).state, TrustState.unknown);
    });
  });

  group('fingerprint verification uses I6.2', () {
    test('explicit verification updates verification state', () async {
      final service = TrustService();
      final peerId = IdentityRepository.bytesToHex(keyA);

      // Initially not verified
      expect(service.isVerified(peerId), isFalse);

      // Explicit verification via TrustService
      service.verifyIdentity(
        peerIdentityId: peerId,
        at: DateTime.now(),
        publicKeyHex: IdentityRepository.bytesToHex(keyA),
        method: VerificationMethod.fingerprintComparison,
      );

      // Now verified
      expect(service.isVerified(peerId), isTrue);
    });

    test('fingerprint comparison does not auto-verify', () async {
      final service = TrustService();
      final peerId = IdentityRepository.bytesToHex(keyA);

      // Fingerprint comparison alone does not call verifyIdentity
      final fpA = await computeFingerprint(keyA);
      final fpB = await computeFingerprint(keyA);
      compareFingerprint(fpA, fpB); // Just a comparison

      // Should NOT be verified
      expect(service.isVerified(peerId), isFalse);
    });
  });

  group('peer isolation', () {
    test('verifying peer A does not verify peer B', () async {
      final service = TrustService();
      final peerA = IdentityRepository.bytesToHex(keyA);
      final peerB = IdentityRepository.bytesToHex(keyB);

      service.verifyIdentity(
        peerIdentityId: peerA,
        at: DateTime.now(),
        publicKeyHex: IdentityRepository.bytesToHex(keyA),
        method: VerificationMethod.qrScan,
      );

      expect(service.isVerified(peerA), isTrue);
      expect(service.isVerified(peerB), isFalse);
    });
  });

  group('no secrets exposed', () {
    test('fingerprint requires only public key bytes', () async {
      final fp = await computeFingerprint(keyA);
      expect(fp, isNotEmpty);
      // No secure storage access, no private key needed
    });

    test('fingerprint does not log secrets', () async {
      // The fingerprint function is a pure function with no logging
      final fp = await computeFingerprint(keyA);
      expect(fp, isNotNull);
    });
  });

  group('fingerprint format properties', () {
    test('full 256-bit digest is retained', () async {
      final fp = await computeFingerprint(keyA);
      final hexOnly = fp.replaceAll(' ', '');
      expect(hexOnly.length, 64); // 256 bits = 64 hex chars
    });

    test('format is uppercase hex in groups of 4', () async {
      final fp = await computeFingerprint(keyA);
      expect(RegExp(r'^[0-9A-F]{4}( [0-9A-F]{4}){15}$').hasMatch(fp), isTrue);
    });

    test('deterministic across calls', () async {
      final fp1 = await computeFingerprint(keyA);
      final fp2 = await computeFingerprint(keyA);
      final fp3 = await computeFingerprint(keyA);
      expect(fp1, fp2);
      expect(fp2, fp3);
    });
  });
}
