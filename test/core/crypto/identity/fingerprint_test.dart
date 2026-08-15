import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/crypto/identity/fingerprint.dart';
import 'package:onebit/core/crypto/identity/identity_crypto.dart';

void main() {
  const fingerprintHex =
      '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

  group('Fingerprint', () {
    test('requires exactly 32 bytes', () {
      expect(() => Fingerprint(Uint8List(31)), throwsArgumentError);
      expect(() => Fingerprint(Uint8List(33)), throwsArgumentError);
      expect(Fingerprint(Uint8List(32)).bytes, hasLength(32));
    });

    test('fromHex and hex are inverse', () {
      final fingerprint = Fingerprint.fromHex(fingerprintHex);
      expect(fingerprint.hex, fingerprintHex);
    });

    test('rejects malformed hex', () {
      expect(() => Fingerprint.fromHex('ff'), throwsFormatException);
      expect(() => Fingerprint.fromHex('G' * 64), throwsFormatException);
      expect(Fingerprint.isValidHex(fingerprintHex), isTrue);
      expect(Fingerprint.isValidHex('ff'), isFalse);
      expect(Fingerprint.isValidHex(''), isFalse);
    });

    test('tolerates uppercase and whitespace on parse', () {
      expect(
        Fingerprint.fromHex('  ${fingerprintHex.toUpperCase()}  ').hex,
        fingerprintHex,
      );
    });

    test('formatted renders uppercase groups of four', () {
      final formatted = Fingerprint.fromHex(fingerprintHex).formatted;
      expect(
        formatted,
        '0011-2233-4455-6677-8899-AABB-CCDD-EEFF-0011-2233-4455-6677-8899-AABB-CCDD-EEFF',
      );
    });

    test('shortCode is the uppercase first eight hex digits', () {
      expect(Fingerprint.fromHex(fingerprintHex).shortCode, '00112233');
      expect(Fingerprint.fromHex(fingerprintHex).headHex, '00112233');
    });

    test('equality is value-based and constant-time safe', () {
      final a = Fingerprint.fromHex(fingerprintHex);
      final b = Fingerprint(Uint8List.fromList(a.bytes));
      final different = Fingerprint.fromHex('f' * 64);
      expect(a, a);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(different));
    });

    test('derives a 32-byte digest from an Ed25519 public key', () async {
      final seed = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final publicKey = await IdentityCrypto.publicKeyFromSeed(seed);
      final fingerprint = await Fingerprint.fromPublicKey(publicKey);
      expect(fingerprint.bytes, hasLength(32));
      // Identical input yields an identical fingerprint.
      final again = await Fingerprint.fromPublicKey(publicKey);
      expect(fingerprint, again);
    });
  });
}
