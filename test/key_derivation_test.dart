import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/crypto/key_derivation.dart';

void main() {
  group('KeyDerivation', () {
    late SecretKey sharedSecret;

    setUp(() {
      // Create a realistic 32-byte shared secret (simulating X25519 output)
      sharedSecret = SecretKey(
        Uint8List.fromList(List.generate(32, (i) => i + 1)),
      );
    });

    group('deriveSessionKey', () {
      test('produces 32-byte key by default', () async {
        final key = await KeyDerivation.deriveSessionKey(
          sharedSecret: sharedSecret,
        );
        final bytes = await key.extractBytes();
        expect(bytes.length, 32);
      });

      test('is deterministic — same inputs produce same output', () async {
        final key1 = await KeyDerivation.deriveSessionKey(
          sharedSecret: sharedSecret,
        );
        final key2 = await KeyDerivation.deriveSessionKey(
          sharedSecret: sharedSecret,
        );
        final bytes1 = await key1.extractBytes();
        final bytes2 = await key2.extractBytes();
        expect(bytes1, equals(bytes2));
      });

      test('different shared secrets produce different keys', () async {
        final otherSecret = SecretKey(
          Uint8List.fromList(List.generate(32, (i) => i + 100)),
        );

        final key1 = await KeyDerivation.deriveSessionKey(
          sharedSecret: sharedSecret,
        );
        final key2 = await KeyDerivation.deriveSessionKey(
          sharedSecret: otherSecret,
        );
        final bytes1 = await key1.extractBytes();
        final bytes2 = await key2.extractBytes();
        expect(bytes1, isNot(equals(bytes2)));
      });

      test('different contexts produce different keys', () async {
        final key1 = await KeyDerivation.deriveSessionKey(
          sharedSecret: sharedSecret,
          context: Uint8List.fromList('contextA'.codeUnits),
        );
        final key2 = await KeyDerivation.deriveSessionKey(
          sharedSecret: sharedSecret,
          context: Uint8List.fromList('contextB'.codeUnits),
        );
        final bytes1 = await key1.extractBytes();
        final bytes2 = await key2.extractBytes();
        expect(bytes1, isNot(equals(bytes2)));
      });

      test('respects custom output length', () async {
        final key = await KeyDerivation.deriveSessionKey(
          sharedSecret: sharedSecret,
          outputLength: 16,
        );
        final bytes = await key.extractBytes();
        expect(bytes.length, 16);
      });

      test('rejects zero output length', () async {
        expect(
          () => KeyDerivation.deriveSessionKey(
            sharedSecret: sharedSecret,
            outputLength: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects output length > 255', () async {
        expect(
          () => KeyDerivation.deriveSessionKey(
            sharedSecret: sharedSecret,
            outputLength: 256,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('works with empty context', () async {
        final key = await KeyDerivation.deriveSessionKey(
          sharedSecret: sharedSecret,
          context: Uint8List(0),
        );
        final bytes = await key.extractBytes();
        expect(bytes.length, 32);
      });

      test('works with null context', () async {
        final key = await KeyDerivation.deriveSessionKey(
          sharedSecret: sharedSecret,
          context: null,
        );
        final bytes = await key.extractBytes();
        expect(bytes.length, 32);
      });
    });

    group('deriveSessionKeyBytes', () {
      test('returns raw bytes', () async {
        final bytes = await KeyDerivation.deriveSessionKeyBytes(
          sharedSecret: sharedSecret,
        );
        expect(bytes, isA<Uint8List>());
        expect(bytes.length, 32);
      });

      test('is deterministic', () async {
        final bytes1 = await KeyDerivation.deriveSessionKeyBytes(
          sharedSecret: sharedSecret,
        );
        final bytes2 = await KeyDerivation.deriveSessionKeyBytes(
          sharedSecret: sharedSecret,
        );
        expect(bytes1, equals(bytes2));
      });
    });

    group('X25519 + HKDF integration', () {
      test('symmetric derivation — A↔B produce same key', () async {
        final algorithm = X25519();

        // Generate key pairs for A and B
        final keyPairA = await algorithm.newKeyPair();
        final keyPairB = await algorithm.newKeyPair();

        // Extract public keys
        final publicKeyA = await keyPairA.extractPublicKey();
        final publicKeyB = await keyPairB.extractPublicKey();

        // A computes shared secret with B's public key
        final sharedSecretAB = await algorithm.sharedSecretKey(
          keyPair: keyPairA,
          remotePublicKey: publicKeyB,
        );

        // B computes shared secret with A's public key
        final sharedSecretBA = await algorithm.sharedSecretKey(
          keyPair: keyPairB,
          remotePublicKey: publicKeyA,
        );

        // Both shared secrets should be identical
        final secretBytesAB = await sharedSecretAB.extractBytes();
        final secretBytesBA = await sharedSecretBA.extractBytes();
        expect(secretBytesAB, equals(secretBytesBA));

        // Derive session keys from both shared secrets
        final sessionKeyAB = await KeyDerivation.deriveSessionKeyBytes(
          sharedSecret: sharedSecretAB,
        );
        final sessionKeyBA = await KeyDerivation.deriveSessionKeyBytes(
          sharedSecret: sharedSecretBA,
        );

        // Both derived keys should be identical
        expect(sessionKeyAB, equals(sessionKeyBA));
      });

      test('different peer pairs produce different keys', () async {
        final algorithm = X25519();

        // Three key pairs: A, B, C
        final keyPairA = await algorithm.newKeyPair();
        final keyPairB = await algorithm.newKeyPair();
        final keyPairC = await algorithm.newKeyPair();

        final publicKeyB = await keyPairB.extractPublicKey();
        final publicKeyC = await keyPairC.extractPublicKey();

        // A↔B shared secret
        final sharedSecretAB = await algorithm.sharedSecretKey(
          keyPair: keyPairA,
          remotePublicKey: publicKeyB,
        );

        // A↔C shared secret
        final sharedSecretAC = await algorithm.sharedSecretKey(
          keyPair: keyPairA,
          remotePublicKey: publicKeyC,
        );

        // Derive session keys
        final sessionKeyAB = await KeyDerivation.deriveSessionKeyBytes(
          sharedSecret: sharedSecretAB,
        );
        final sessionKeyAC = await KeyDerivation.deriveSessionKeyBytes(
          sharedSecret: sharedSecretAC,
        );

        // Keys for different peers should be different
        expect(sessionKeyAB, isNot(equals(sessionKeyAC)));
      });
    });

    group('Security properties', () {
      test('derived key is not the same as shared secret', () async {
        final sharedSecretBytes = await sharedSecret.extractBytes();
        final derivedKey = await KeyDerivation.deriveSessionKeyBytes(
          sharedSecret: sharedSecret,
        );
        expect(derivedKey, isNot(equals(sharedSecretBytes)));
      });

      test('no secret in exception message', () async {
        try {
          await KeyDerivation.deriveSessionKey(
            sharedSecret: SecretKey(Uint8List(0)),
          );
        } catch (e) {
          expect(e.toString(), isNot(contains('sharedSecret')));
          expect(e.toString(), isNot(contains('key')));
        }
      });
    });

    group('Repeatability', () {
      test('multiple derivations produce same result', () async {
        final results = <Uint8List>[];
        for (var i = 0; i < 10; i++) {
          results.add(
            await KeyDerivation.deriveSessionKeyBytes(
              sharedSecret: sharedSecret,
            ),
          );
        }
        // All results should be identical
        for (final result in results) {
          expect(result, equals(results.first));
        }
      });
    });
  });

  group('KeyDerivationException', () {
    test('has message', () {
      const exception = KeyDerivationException('test error');
      expect(exception.message, 'test error');
      expect(exception.toString(), 'KeyDerivationException: test error');
    });
  });
}
