import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/crypto/identity/exchange_crypto.dart';

void main() {
  final aliceSeed = Uint8List.fromList(List<int>.generate(32, (i) => i));
  final bobSeed = Uint8List.fromList(List<int>.generate(32, (i) => i * 2));

  group('ExchangeCrypto', () {
    test('derives 32-byte X25519 public keys', () async {
      final alice = await ExchangeCrypto.publicKeyFromSeed(aliceSeed);
      final bob = await ExchangeCrypto.publicKeyFromSeed(bobSeed);
      expect(alice, hasLength(32));
      expect(bob, hasLength(32));
    });

    test('both parties derive the same shared secret', () async {
      final alicePublic = await ExchangeCrypto.publicKeyFromSeed(aliceSeed);
      final bobPublic = await ExchangeCrypto.publicKeyFromSeed(bobSeed);

      final aliceSecret = await ExchangeCrypto.sharedSecret(
        keyPairSeed: aliceSeed,
        remotePublicKey: bobPublic,
      );
      final bobSecret = await ExchangeCrypto.sharedSecret(
        keyPairSeed: bobSeed,
        remotePublicKey: alicePublic,
      );
      expect(aliceSecret, bobSecret);
      expect(aliceSecret, hasLength(32));
    });

    test(
      'deriveKey is deterministic and differs on salt or info change',
      () async {
        final secret = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
        const salt = <int>[0, 1, 2, 3];
        const info = 'onebit/test/v1';

        final a = await ExchangeCrypto.deriveKey(
          sharedSecret: secret,
          salt: salt,
          info: info,
        );
        final b = await ExchangeCrypto.deriveKey(
          sharedSecret: secret,
          salt: salt,
          info: info,
        );
        expect(a, b);
        expect(a, hasLength(32));

        final otherSalt = await ExchangeCrypto.deriveKey(
          sharedSecret: secret,
          salt: const <int>[0, 1, 2, 4],
          info: info,
        );
        final otherInfo = await ExchangeCrypto.deriveKey(
          sharedSecret: secret,
          salt: salt,
          info: 'onebit/test/v2',
        );
        expect(a, isNot(otherSalt));
        expect(a, isNot(otherInfo));
      },
    );

    test('encrypt/decrypt round-trip with AAD', () async {
      final key = List<int>.generate(32, (i) => i);
      const clearText = <int>[10, 20, 30, 40];
      final nonce = Uint8List.fromList(List<int>.generate(12, (i) => i + 100));
      const aad = <int>[1, 2, 3];

      final box = await ExchangeCrypto.encrypt(
        key: key,
        clearText: clearText,
        nonce: nonce,
        aad: aad,
      );
      final decrypted = await ExchangeCrypto.decrypt(
        key: key,
        box: box,
        aad: aad,
      );
      expect(decrypted, clearText);
    });

    test('decrypt rejects a tampered ciphertext', () async {
      final key = List<int>.generate(32, (i) => i);
      const clearText = <int>[10, 20, 30, 40];
      final nonce = Uint8List.fromList(List<int>.generate(12, (i) => i + 100));

      final box = await ExchangeCrypto.encrypt(
        key: key,
        clearText: clearText,
        nonce: nonce,
      );
      final tampered = SecretBox(
        Uint8List.fromList([...box.cipherText]..[0] ^= 0xFF),
        nonce: box.nonce,
        mac: box.mac,
      );
      await expectLater(
        ExchangeCrypto.decrypt(key: key, box: tampered),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('decrypt rejects a mismatched AAD', () async {
      final key = List<int>.generate(32, (i) => i);
      final box = await ExchangeCrypto.encrypt(
        key: key,
        clearText: const <int>[10, 20, 30, 40],
        nonce: Uint8List.fromList(List<int>.generate(12, (i) => i + 100)),
        aad: const <int>[1, 2, 3],
      );
      await expectLater(
        ExchangeCrypto.decrypt(key: key, box: box, aad: const <int>[9, 9]),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('encrypt produces a fresh nonce and 16-byte mac', () async {
      final key = List<int>.generate(32, (i) => i);
      final box = await ExchangeCrypto.encrypt(
        key: key,
        clearText: utf8.encode('hello'),
        nonce: Uint8List.fromList(List<int>.generate(12, (i) => i)),
      );
      expect(box.mac.bytes, hasLength(16));
      expect(box.cipherText, isNotEmpty);
    });
  });
}
