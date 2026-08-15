import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/crypto/identity/identity_crypto.dart';

void main() {
  final seed = Uint8List.fromList(List<int>.generate(32, (i) => i));

  group('IdentityCrypto', () {
    test('derives a 32-byte Ed25519 public key', () async {
      final publicKey = await IdentityCrypto.publicKeyFromSeed(seed);
      expect(publicKey, hasLength(32));
    });

    test('sign produces a 64-byte signature that verifies', () async {
      final publicKey = await IdentityCrypto.publicKeyFromSeed(seed);
      const message = <int>[1, 2, 3, 4, 5];
      final signature = await IdentityCrypto.sign(seed: seed, message: message);
      expect(signature, hasLength(64));
      final ok = await IdentityCrypto.verify(
        publicKey: publicKey,
        message: message,
        signature: signature,
      );
      expect(ok, isTrue);
    });

    test('signing is deterministic for a fixed seed and message', () async {
      const message = <int>[7, 8, 9];
      final first = await IdentityCrypto.sign(seed: seed, message: message);
      final second = await IdentityCrypto.sign(seed: seed, message: message);
      expect(first, second);
    });

    test('verification rejects a tampered message', () async {
      final publicKey = await IdentityCrypto.publicKeyFromSeed(seed);
      const message = <int>[1, 2, 3];
      final signature = await IdentityCrypto.sign(seed: seed, message: message);
      final ok = await IdentityCrypto.verify(
        publicKey: publicKey,
        message: const <int>[1, 2, 4],
        signature: signature,
      );
      expect(ok, isFalse);
    });

    test('verification rejects a signature from another key', () async {
      final publicKey = await IdentityCrypto.publicKeyFromSeed(seed);
      final otherSeed = Uint8List.fromList(
        List<int>.generate(32, (i) => 255 - i),
      );
      const message = <int>[1, 2, 3];
      final signature = await IdentityCrypto.sign(
        seed: otherSeed,
        message: message,
      );
      final ok = await IdentityCrypto.verify(
        publicKey: publicKey,
        message: message,
        signature: signature,
      );
      expect(ok, isFalse);
    });

    test('publicKeyFromSeed is deterministic', () async {
      final a = await IdentityCrypto.publicKeyFromSeed(seed);
      final b = await IdentityCrypto.publicKeyFromSeed(seed);
      expect(a, b);
    });
  });
}
