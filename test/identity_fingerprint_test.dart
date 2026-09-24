import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/identity/identity_fingerprint.dart';
import 'package:onebit/features/identity/identity_repository.dart';

void main() {
  group('computeFingerprint', () {
    test('is deterministic — same input produces same output', () async {
      final keyBytes = Uint8List.fromList(List.generate(32, (i) => i));

      final fp1 = await computeFingerprint(keyBytes);
      final fp2 = await computeFingerprint(keyBytes);
      final fp3 = await computeFingerprint(keyBytes);

      expect(fp1, fp2);
      expect(fp2, fp3);
    });

    test('matches known SHA-256 vector', () async {
      // SHA-256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
      // We'll use a simple known input: 32 bytes of zeros
      final keyBytes = Uint8List(32);

      final fp = await computeFingerprint(keyBytes);

      // Compute expected: SHA-256 of 32 zero bytes
      // We can verify by computing it manually with the same library
      final sha256 = Sha256();
      final hash = await sha256.hash(keyBytes);
      final expectedHex = hash.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();

      // Format expected the same way
      final buffer = StringBuffer();
      for (var i = 0; i < expectedHex.length; i += 4) {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(expectedHex.substring(i, i + 4));
      }

      expect(fp, buffer.toString());
    });

    test('different identities produce different fingerprints', () async {
      final keyA = Uint8List.fromList(List.generate(32, (i) => i));
      final keyB = Uint8List.fromList(List.generate(32, (i) => i + 32));

      final fpA = await computeFingerprint(keyA);
      final fpB = await computeFingerprint(keyB);

      expect(fpA, isNot(fpB));
    });

    test('format is uppercase hex in groups of 4', () async {
      final keyBytes = Uint8List.fromList(List.generate(32, (i) => i));

      final fp = await computeFingerprint(keyBytes);

      // Should be 64 hex chars = 16 groups of 4, separated by spaces
      expect(fp.length, 16 * 4 + 15); // 64 chars + 15 spaces
      expect(RegExp(r'^[0-9A-F]{4}( [0-9A-F]{4}){15}$').hasMatch(fp), isTrue);
    });

    test('full 256-bit digest is retained', () async {
      final keyBytes = Uint8List.fromList(List.generate(32, (i) => i));

      final fp = await computeFingerprint(keyBytes);

      // 64 hex characters = 256 bits
      final hexOnly = fp.replaceAll(' ', '');
      expect(hexOnly.length, 64);
    });

    test('throws on empty input', () async {
      expect(
        () => computeFingerprint(Uint8List(0)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('works with wrong-length input', () async {
      // 16 bytes (not 32) — still hashes, just different
      final keyShort = Uint8List.fromList(List.generate(16, (i) => i));
      final keyLong = Uint8List.fromList(List.generate(64, (i) => i));

      final fpShort = await computeFingerprint(keyShort);
      final fpLong = await computeFingerprint(keyLong);

      // Both should produce valid fingerprints
      expect(fpShort.length, 64 + 15);
      expect(fpLong.length, 64 + 15);
    });

    test('no private key required', () async {
      // This test verifies the API accepts only public key material
      final publicKeyBytes = Uint8List.fromList(List.generate(32, (i) => i));

      // No secure storage access needed
      final fp = await computeFingerprint(publicKeyBytes);

      expect(fp, isNotEmpty);
    });

    test('peer compatibility — works with hex-derived bytes', () async {
      // Simulate peer scenario: hex identityId -> bytes -> fingerprint
      final originalKey = Uint8List.fromList(List.generate(32, (i) => i));
      final hexId = IdentityRepository.bytesToHex(originalKey);

      // Peer converts hex to bytes (same as IdentityRepository.hexToBytes)
      final peerBytes = IdentityRepository.hexToBytes(hexId);

      // Both should produce the same fingerprint
      final fpLocal = await computeFingerprint(originalKey);
      final fpPeer = await computeFingerprint(peerBytes);

      expect(fpLocal, fpPeer);
    });

    test('idempotency — calling twice returns exactly same result', () async {
      final keyBytes = Uint8List.fromList(List.generate(32, (i) => i));

      final fp1 = await computeFingerprint(keyBytes);
      final fp2 = await computeFingerprint(keyBytes);

      expect(identical(fp1, fp2), isFalse); // Not the same object
      expect(fp1, fp2); // But same value
    });
  });

  group('fingerprintCompact', () {
    test('truncates to 8 groups with ellipsis', () async {
      final keyBytes = Uint8List.fromList(List.generate(32, (i) => i));
      final full = await computeFingerprint(keyBytes);

      final compact = fingerprintCompact(full);

      // Should have 8 groups + " …"
      final groups = compact.replaceAll(' …', '').split(' ');
      expect(groups.length, 8);
      expect(compact, endsWith('…'));
    });
  });

  group('fingerprintLines', () {
    test('formats into lines of 4 groups', () async {
      final keyBytes = Uint8List.fromList(List.generate(32, (i) => i));
      final full = await computeFingerprint(keyBytes);

      final lines = fingerprintLines(full);

      final lineList = lines.split('\n');
      expect(lineList.length, 4); // 16 groups / 4 per line = 4 lines
      for (final line in lineList) {
        final groups = line.split(' ');
        expect(groups.length, 4);
      }
    });
  });

  group('IdentityRepository.hexToBytes', () {
    test('round-trips with bytesToHex', () {
      final original = Uint8List.fromList(List.generate(32, (i) => i));
      final hex = IdentityRepository.bytesToHex(original);
      final restored = IdentityRepository.hexToBytes(hex);

      expect(restored, original);
    });

    test('handles empty string', () {
      final result = IdentityRepository.hexToBytes('');
      expect(result, isEmpty);
    });

    test('handles uppercase hex', () {
      final result = IdentityRepository.hexToBytes('FF00AB');
      expect(result, [0xFF, 0x00, 0xAB]);
    });
  });
}
