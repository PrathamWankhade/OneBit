import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/crypto/aead_cipher.dart';
import 'package:onebit/features/crypto/key_derivation.dart';

void main() {
  group('AeadCipher', () {
    late SecretKey testKey;

    setUp(() {
      // Create a realistic 32-byte key (simulating I5.4 derived key)
      testKey = SecretKey(
        Uint8List.fromList(List.generate(32, (i) => i + 1)),
      );
    });

    group('encrypt', () {
      test('encrypts plaintext successfully', () async {
        final plaintext = Uint8List.fromList('hello world'.codeUnits);
        final encrypted = await AeadCipher.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        expect(encrypted.nonce.length, AeadCipher.nonceLength);
        expect(encrypted.ciphertext.length, plaintext.length);
        expect(encrypted.mac.length, AeadCipher.tagLength);
      });

      test('produces different ciphertext each time (fresh nonce)', () async {
        final plaintext = Uint8List.fromList('test'.codeUnits);
        final enc1 = await AeadCipher.encrypt(key: testKey, plaintext: plaintext);
        final enc2 = await AeadCipher.encrypt(key: testKey, plaintext: plaintext);

        // Different nonces
        expect(enc1.nonce, isNot(equals(enc2.nonce)));
        // Different ciphertext
        expect(enc1.ciphertext, isNot(equals(enc2.ciphertext)));
      });

      test('rejects empty plaintext', () async {
        expect(
          () => AeadCipher.encrypt(
            key: testKey,
            plaintext: Uint8List(0),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('works with associated data', () async {
        final plaintext = Uint8List.fromList('data'.codeUnits);
        final aad = Uint8List.fromList('metadata'.codeUnits);
        final encrypted = await AeadCipher.encrypt(
          key: testKey,
          plaintext: plaintext,
          associatedData: aad,
        );

        expect(encrypted.ciphertext.isNotEmpty, isTrue);
      });
    });

    group('decrypt', () {
      test('decrypts ciphertext successfully', () async {
        final plaintext = Uint8List.fromList('hello world'.codeUnits);
        final encrypted = await AeadCipher.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        final decrypted = await AeadCipher.decrypt(
          key: testKey,
          encrypted: encrypted,
        );

        expect(decrypted, equals(plaintext));
      });

      test('round trip preserves empty-ish content', () async {
        final plaintext = Uint8List.fromList([0x00, 0x01, 0x02]);
        final encrypted = await AeadCipher.encrypt(
          key: testKey,
          plaintext: plaintext,
        );
        final decrypted = await AeadCipher.decrypt(
          key: testKey,
          encrypted: encrypted,
        );

        expect(decrypted, equals(plaintext));
      });

      test('round trip with associated data', () async {
        final plaintext = Uint8List.fromList('secure data'.codeUnits);
        final aad = Uint8List.fromList('context'.codeUnits);
        final encrypted = await AeadCipher.encrypt(
          key: testKey,
          plaintext: plaintext,
          associatedData: aad,
        );

        final decrypted = await AeadCipher.decrypt(
          key: testKey,
          encrypted: encrypted,
          associatedData: aad,
        );

        expect(decrypted, equals(plaintext));
      });

      test('unicode plaintext round trip', () async {
        final plaintext = Uint8List.fromList('Hello \u00e4\u00f6\u00fc \u4e16\u754c'.codeUnits);
        final encrypted = await AeadCipher.encrypt(
          key: testKey,
          plaintext: plaintext,
        );
        final decrypted = await AeadCipher.decrypt(
          key: testKey,
          encrypted: encrypted,
        );

        expect(decrypted, equals(plaintext));
      });

      test('binary plaintext round trip', () async {
        final plaintext = Uint8List.fromList(List.generate(256, (i) => i));
        final encrypted = await AeadCipher.encrypt(
          key: testKey,
          plaintext: plaintext,
        );
        final decrypted = await AeadCipher.decrypt(
          key: testKey,
          encrypted: encrypted,
        );

        expect(decrypted, equals(plaintext));
      });

      test('larger plaintext round trip', () async {
        final plaintext = Uint8List.fromList(
          List.generate(1024, (i) => i % 256),
        );
        final encrypted = await AeadCipher.encrypt(
          key: testKey,
          plaintext: plaintext,
        );
        final decrypted = await AeadCipher.decrypt(
          key: testKey,
          encrypted: encrypted,
        );

        expect(decrypted, equals(plaintext));
      });
    });

    group('Authentication', () {
      test('wrong key fails decryption', () async {
        final plaintext = Uint8List.fromList('secret'.codeUnits);
        final encrypted = await AeadCipher.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        final wrongKey = SecretKey(
          Uint8List.fromList(List.generate(32, (i) => i + 100)),
        );

        expect(
          () => AeadCipher.decrypt(key: wrongKey, encrypted: encrypted),
          throwsA(isA<AeadCipherException>()),
        );
      });

      test('modified ciphertext fails decryption', () async {
        final plaintext = Uint8List.fromList('data'.codeUnits);
        final encrypted = await AeadCipher.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        // Modify one ciphertext byte
        final modifiedCiphertext = Uint8List.fromList(encrypted.ciphertext);
        modifiedCiphertext[0] ^= 0xFF;

        final modifiedPayload = EncryptedPayload(
          nonce: encrypted.nonce,
          ciphertext: modifiedCiphertext,
          mac: encrypted.mac,
        );

        expect(
          () => AeadCipher.decrypt(key: testKey, encrypted: modifiedPayload),
          throwsA(isA<AeadCipherException>()),
        );
      });

      test('modified MAC fails decryption', () async {
        final plaintext = Uint8List.fromList('data'.codeUnits);
        final encrypted = await AeadCipher.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        // Modify one MAC byte
        final modifiedMac = Uint8List.fromList(encrypted.mac);
        modifiedMac[0] ^= 0xFF;

        final modifiedPayload = EncryptedPayload(
          nonce: encrypted.nonce,
          ciphertext: encrypted.ciphertext,
          mac: modifiedMac,
        );

        expect(
          () => AeadCipher.decrypt(key: testKey, encrypted: modifiedPayload),
          throwsA(isA<AeadCipherException>()),
        );
      });

      test('wrong nonce fails decryption', () async {
        final plaintext = Uint8List.fromList('data'.codeUnits);
        final encrypted = await AeadCipher.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        // Use a different nonce
        final wrongNonce = Uint8List.fromList(
          List.generate(AeadCipher.nonceLength, (i) => i + 50),
        );

        final modifiedPayload = EncryptedPayload(
          nonce: wrongNonce,
          ciphertext: encrypted.ciphertext,
          mac: encrypted.mac,
        );

        expect(
          () => AeadCipher.decrypt(key: testKey, encrypted: modifiedPayload),
          throwsA(isA<AeadCipherException>()),
        );
      });

      test('wrong AAD fails decryption', () async {
        final plaintext = Uint8List.fromList('data'.codeUnits);
        final aad = Uint8List.fromList('correct'.codeUnits);
        final encrypted = await AeadCipher.encrypt(
          key: testKey,
          plaintext: plaintext,
          associatedData: aad,
        );

        final wrongAad = Uint8List.fromList('wrong'.codeUnits);

        expect(
          () => AeadCipher.decrypt(
            key: testKey,
            encrypted: encrypted,
            associatedData: wrongAad,
          ),
          throwsA(isA<AeadCipherException>()),
        );
      });

      test('correct AAD succeeds', () async {
        final plaintext = Uint8List.fromList('data'.codeUnits);
        final aad = Uint8List.fromList('context'.codeUnits);
        final encrypted = await AeadCipher.encrypt(
          key: testKey,
          plaintext: plaintext,
          associatedData: aad,
        );

        final decrypted = await AeadCipher.decrypt(
          key: testKey,
          encrypted: encrypted,
          associatedData: aad,
        );

        expect(decrypted, equals(plaintext));
      });
    });

    group('Deterministic decryption', () {
      test('same encrypted payload decrypts to same plaintext', () async {
        final plaintext = Uint8List.fromList('deterministic'.codeUnits);
        final encrypted = await AeadCipher.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        final dec1 = await AeadCipher.decrypt(key: testKey, encrypted: encrypted);
        final dec2 = await AeadCipher.decrypt(key: testKey, encrypted: encrypted);

        expect(dec1, equals(dec2));
        expect(dec1, equals(plaintext));
      });
    });

    group('Key isolation', () {
      test('different key cannot decrypt', () async {
        final plaintext = Uint8List.fromList('isolated'.codeUnits);
        final encrypted = await AeadCipher.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        final otherKey = SecretKey(
          Uint8List.fromList(List.generate(32, (i) => i + 200)),
        );

        expect(
          () => AeadCipher.decrypt(key: otherKey, encrypted: encrypted),
          throwsA(isA<AeadCipherException>()),
        );
      });
    });

    group('Full crypto chain', () {
      test('X25519 → HKDF → AES-GCM round trip', () async {
        final algorithm = X25519();

        // Generate key pairs for A and B
        final keyPairA = await algorithm.newKeyPair();
        final keyPairB = await algorithm.newKeyPair();

        final publicKeyA = await keyPairA.extractPublicKey();
        final publicKeyB = await keyPairB.extractPublicKey();

        // Both compute the same shared secret
        final sharedSecretAB = await algorithm.sharedSecretKey(
          keyPair: keyPairA,
          remotePublicKey: publicKeyB,
        );
        final sharedSecretBA = await algorithm.sharedSecretKey(
          keyPair: keyPairB,
          remotePublicKey: publicKeyA,
        );

        // Both derive the same session key via HKDF
        final sessionKeyAB = await KeyDerivation.deriveSessionKey(
          sharedSecret: sharedSecretAB,
        );
        final sessionKeyBA = await KeyDerivation.deriveSessionKey(
          sharedSecret: sharedSecretBA,
        );

        // A encrypts a message
        final plaintext = Uint8List.fromList('Hello from A to B'.codeUnits);
        final encrypted = await AeadCipher.encrypt(
          key: sessionKeyAB,
          plaintext: plaintext,
        );

        // B decrypts using the same derived key
        final decrypted = await AeadCipher.decrypt(
          key: sessionKeyBA,
          encrypted: encrypted,
        );

        expect(decrypted, equals(plaintext));
      });

      test('peer isolation — A→B key cannot decrypt A→C data', () async {
        final algorithm = X25519();

        final keyPairA = await algorithm.newKeyPair();
        final keyPairB = await algorithm.newKeyPair();
        final keyPairC = await algorithm.newKeyPair();

        final publicKeyB = await keyPairB.extractPublicKey();
        final publicKeyC = await keyPairC.extractPublicKey();

        // A→B session key
        final sharedSecretAB = await algorithm.sharedSecretKey(
          keyPair: keyPairA,
          remotePublicKey: publicKeyB,
        );
        final sessionKeyAB = await KeyDerivation.deriveSessionKey(
          sharedSecret: sharedSecretAB,
        );

        // A→C session key
        final sharedSecretAC = await algorithm.sharedSecretKey(
          keyPair: keyPairA,
          remotePublicKey: publicKeyC,
        );
        final sessionKeyAC = await KeyDerivation.deriveSessionKey(
          sharedSecret: sharedSecretAC,
        );

        // A encrypts for B
        final plaintext = Uint8List.fromList('For B only'.codeUnits);
        final encrypted = await AeadCipher.encrypt(
          key: sessionKeyAB,
          plaintext: plaintext,
        );

        // C cannot decrypt with their key
        expect(
          () => AeadCipher.decrypt(
            key: sessionKeyAC,
            encrypted: encrypted,
          ),
          throwsA(isA<AeadCipherException>()),
        );
      });
    });

    group('Security properties', () {
      test('EncryptedPayload contains all required fields', () async {
        final plaintext = Uint8List.fromList('test'.codeUnits);
        final encrypted = await AeadCipher.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        expect(encrypted.nonce.length, AeadCipher.nonceLength);
        expect(encrypted.mac.length, AeadCipher.tagLength);
        expect(encrypted.ciphertext.isNotEmpty, isTrue);
        expect(encrypted.totalLength, greaterThan(plaintext.length));
      });

      test('no secret in exception message', () async {
        try {
          await AeadCipher.decrypt(
            key: testKey,
            encrypted: EncryptedPayload(
              nonce: Uint8List(12),
              ciphertext: Uint8List(16),
              mac: Uint8List(16),
            ),
          );
        } catch (e) {
          expect(e.toString(), isNot(contains('secret')));
          expect(e.toString(), isNot(contains('key')));
        }
      });
    });
  });

  group('EncryptedPayload', () {
    test('holds all fields', () {
      final payload = EncryptedPayload(
        nonce: Uint8List(12),
        ciphertext: Uint8List(32),
        mac: Uint8List(16),
      );

      expect(payload.nonce.length, 12);
      expect(payload.ciphertext.length, 32);
      expect(payload.mac.length, 16);
      expect(payload.totalLength, 60);
    });
  });

  group('AeadCipherException', () {
    test('has message', () {
      const exception = AeadCipherException('test error');
      expect(exception.message, 'test error');
      expect(exception.toString(), 'AeadCipherException: test error');
    });
  });
}
