import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/crypto/verification/verification_code.dart';

void main() {
  const alice =
      '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
  const bob =
      'ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100';

  group('VerificationCode', () {
    test('both parties derive the identical code', () async {
      final aliceCode = await VerificationCode.derive(
        ourFingerprintHex: alice,
        theirFingerprintHex: bob,
      );
      final bobCode = await VerificationCode.derive(
        ourFingerprintHex: bob,
        theirFingerprintHex: alice,
      );
      expect(aliceCode.value, bobCode.value);
      expect(VerificationCode.isValid(aliceCode.value), isTrue);
      expect(aliceCode.value, hasLength(6));
    });

    test('a different context produces a different code', () async {
      final defaultCode = await VerificationCode.derive(
        ourFingerprintHex: alice,
        theirFingerprintHex: bob,
      );
      final otherCode = await VerificationCode.derive(
        ourFingerprintHex: alice,
        theirFingerprintHex: bob,
        context: 'onebit/verify-contact/v2',
      );
      expect(defaultCode.value, isNot(otherCode.value));
    });

    test('a different peer produces a different code', () async {
      const carol =
          '1111111111111111111111111111111111111111111111111111111111111111';
      final withBob = await VerificationCode.derive(
        ourFingerprintHex: alice,
        theirFingerprintHex: bob,
      );
      final withCarol = await VerificationCode.derive(
        ourFingerprintHex: alice,
        theirFingerprintHex: carol,
      );
      expect(withBob.value, isNot(withCarol.value));
    });

    test('isValid accepts exactly six digits', () {
      expect(VerificationCode.isValid('123456'), isTrue);
      expect(VerificationCode.isValid('12345'), isFalse);
      expect(VerificationCode.isValid('12345a'), isFalse);
      expect(VerificationCode.isValid(''), isFalse);
    });

    test('rejects invalid fingerprint inputs', () async {
      expect(
        () => VerificationCode.derive(
          ourFingerprintHex: 'not-a-fingerprint',
          theirFingerprintHex: bob,
        ),
        throwsArgumentError,
      );
      expect(
        () => VerificationCode.derive(
          ourFingerprintHex: alice,
          theirFingerprintHex: 'zz',
        ),
        throwsArgumentError,
      );
    });
  });
}
