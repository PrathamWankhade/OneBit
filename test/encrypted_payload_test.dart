import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/crypto/aead_cipher.dart';
import 'package:onebit/features/crypto/encrypted_payload.dart';
import 'package:onebit/features/crypto/key_derivation.dart';

void main() {
  group('OneBitEncryptedPayload', () {
    late SecretKey testKey;

    setUp(() {
      testKey = SecretKey(
        Uint8List.fromList(List.generate(32, (i) => i + 1)),
      );
    });

    group('encrypt', () {
      test('encrypts plaintext to valid payload', () async {
        final plaintext = Uint8List.fromList('hello'.codeUnits);
        final payload = await OneBitEncryptedPayload.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        expect(payload.version, encryptedPayloadVersion);
        expect(payload.nonce.isNotEmpty, isTrue);
        expect(payload.ciphertext.isNotEmpty, isTrue);
        expect(payload.authenticationTag.length, 16);
      });

      test('produces different payloads each time (fresh nonce)', () async {
        final plaintext = Uint8List.fromList('test'.codeUnits);
        final p1 = await OneBitEncryptedPayload.encrypt(
          key: testKey,
          plaintext: plaintext,
        );
        final p2 = await OneBitEncryptedPayload.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        expect(p1.nonce, isNot(equals(p2.nonce)));
        expect(p1.ciphertext, isNot(equals(p2.ciphertext)));
      });
    });

    group('decrypt', () {
      test('decrypts payload successfully', () async {
        final plaintext = Uint8List.fromList('hello world'.codeUnits);
        final payload = await OneBitEncryptedPayload.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        final decrypted = await OneBitEncryptedPayload.decrypt(
          key: testKey,
          payload: payload,
        );

        expect(decrypted, equals(plaintext));
      });

      test('round trip with associated data', () async {
        final plaintext = Uint8List.fromList('secure'.codeUnits);
        final aad = Uint8List.fromList('context'.codeUnits);
        final payload = await OneBitEncryptedPayload.encrypt(
          key: testKey,
          plaintext: plaintext,
          associatedData: aad,
        );

        final decrypted = await OneBitEncryptedPayload.decrypt(
          key: testKey,
          payload: payload,
          associatedData: aad,
        );

        expect(decrypted, equals(plaintext));
      });

      test('wrong key fails', () async {
        final plaintext = Uint8List.fromList('secret'.codeUnits);
        final payload = await OneBitEncryptedPayload.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        final wrongKey = SecretKey(
          Uint8List.fromList(List.generate(32, (i) => i + 100)),
        );

        expect(
          () => OneBitEncryptedPayload.decrypt(
            key: wrongKey,
            payload: payload,
          ),
          throwsA(isA<AeadCipherException>()),
        );
      });

      test('wrong AAD fails', () async {
        final plaintext = Uint8List.fromList('data'.codeUnits);
        final aad = Uint8List.fromList('correct'.codeUnits);
        final payload = await OneBitEncryptedPayload.encrypt(
          key: testKey,
          plaintext: plaintext,
          associatedData: aad,
        );

        final wrongAad = Uint8List.fromList('wrong'.codeUnits);

        expect(
          () => OneBitEncryptedPayload.decrypt(
            key: testKey,
            payload: payload,
            associatedData: wrongAad,
          ),
          throwsA(isA<AeadCipherException>()),
        );
      });
    });

    group('serialize / deserialize', () {
      test('round trip preserves all fields', () async {
        final plaintext = Uint8List.fromList('serialize me'.codeUnits);
        final original = await OneBitEncryptedPayload.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        final bytes = original.serialize();
        final parsed = OneBitEncryptedPayload.deserialize(bytes);

        expect(parsed.version, original.version);
        expect(parsed.nonce, equals(original.nonce));
        expect(parsed.ciphertext, equals(original.ciphertext));
        expect(parsed.authenticationTag, equals(original.authenticationTag));
      });

      test('full round trip: encrypt → serialize → deserialize → decrypt',
          () async {
        final plaintext = Uint8List.fromList('full round trip'.codeUnits);
        final payload = await OneBitEncryptedPayload.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        final bytes = payload.serialize();
        final parsed = OneBitEncryptedPayload.deserialize(bytes);
        final decrypted = await OneBitEncryptedPayload.decrypt(
          key: testKey,
          payload: parsed,
        );

        expect(decrypted, equals(plaintext));
      });

      test('unicode plaintext round trip', () async {
        final plaintext = Uint8List.fromList(
          'Hello \u00e4\u00f6\u00fc \u4e16\u754c'.codeUnits,
        );
        final payload = await OneBitEncryptedPayload.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        final bytes = payload.serialize();
        final parsed = OneBitEncryptedPayload.deserialize(bytes);
        final decrypted = await OneBitEncryptedPayload.decrypt(
          key: testKey,
          payload: parsed,
        );

        expect(decrypted, equals(plaintext));
      });

      test('binary plaintext round trip', () async {
        final plaintext = Uint8List.fromList(List.generate(256, (i) => i));
        final payload = await OneBitEncryptedPayload.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        final bytes = payload.serialize();
        final parsed = OneBitEncryptedPayload.deserialize(bytes);
        final decrypted = await OneBitEncryptedPayload.decrypt(
          key: testKey,
          payload: parsed,
        );

        expect(decrypted, equals(plaintext));
      });

      test('larger payload round trip', () async {
        final plaintext = Uint8List.fromList(
          List.generate(1024, (i) => i % 256),
        );
        final payload = await OneBitEncryptedPayload.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        final bytes = payload.serialize();
        final parsed = OneBitEncryptedPayload.deserialize(bytes);
        final decrypted = await OneBitEncryptedPayload.decrypt(
          key: testKey,
          payload: parsed,
        );

        expect(decrypted, equals(plaintext));
      });

      test('serialization is deterministic', () async {
        final plaintext = Uint8List.fromList('deterministic'.codeUnits);
        final payload = await OneBitEncryptedPayload.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        final bytes1 = payload.serialize();
        final bytes2 = payload.serialize();

        expect(bytes1, equals(bytes2));
      });
    });

    group('deserialization validation', () {
      test('rejects empty payload', () {
        expect(
          () => OneBitEncryptedPayload.deserialize(Uint8List(0)),
          throwsA(isA<PayloadDeserializationException>()),
        );
      });

      test('rejects unsupported version', () {
        final data = Uint8List.fromList([0xFF, 12, ...List.filled(12, 0), 0, 4, ...List.filled(4, 0), ...List.filled(16, 0)]);
        expect(
          () => OneBitEncryptedPayload.deserialize(data),
          throwsA(isA<PayloadDeserializationException>()),
        );
      });

      test('rejects truncated nonce', () {
        // Version 1, nonceLen=20 but only 5 bytes of nonce
        final data = Uint8List.fromList([1, 20, ...List.filled(5, 0)]);
        expect(
          () => OneBitEncryptedPayload.deserialize(data),
          throwsA(isA<PayloadDeserializationException>()),
        );
      });

      test('rejects truncated ciphertext length', () {
        final data = Uint8List.fromList([1, 12, ...List.filled(12, 0)]);
        expect(
          () => OneBitEncryptedPayload.deserialize(data),
          throwsA(isA<PayloadDeserializationException>()),
        );
      });

      test('rejects truncated ciphertext', () {
        final data = Uint8List.fromList([
          1,
          12,
          ...List.filled(12, 0), // nonce
          0,
          100, // ciphertextLen=100
          ...List.filled(10, 0), // only 10 bytes
        ]);
        expect(
          () => OneBitEncryptedPayload.deserialize(data),
          throwsA(isA<PayloadDeserializationException>()),
        );
      });

      test('rejects missing MAC', () {
        final data = Uint8List.fromList([
          1,
          12,
          ...List.filled(12, 0), // nonce
          0,
          4,
          ...List.filled(4, 0), // ciphertext
          // no MAC
        ]);
        expect(
          () => OneBitEncryptedPayload.deserialize(data),
          throwsA(isA<PayloadDeserializationException>()),
        );
      });

      test('rejects trailing data', () async {
        final inner = await OneBitEncryptedPayload.encrypt(
          key: testKey,
          plaintext: Uint8List.fromList('test'.codeUnits),
        );
        final bytes = inner.serialize();
        final extra = Uint8List(bytes.length + 1);
        extra.setRange(0, bytes.length, bytes);
        extra[bytes.length] = 0xFF;

        expect(
          () => OneBitEncryptedPayload.deserialize(extra),
          throwsA(isA<PayloadDeserializationException>()),
        );
      });
    });

    group('tamper detection', () {
      test('modified ciphertext fails decryption', () async {
        final plaintext = Uint8List.fromList('tamper test'.codeUnits);
        final payload = await OneBitEncryptedPayload.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        final bytes = payload.serialize();
        // Modify a byte inside the ciphertext body (after nonceLen + nonce + ciphertextLen)
        final modified = Uint8List.fromList(bytes);
        modified[17] ^= 0xFF; // ciphertext starts at offset 16 (1+1+12+2)

        // Deserialize may succeed (parsing) but decryption should fail
        final parsed = OneBitEncryptedPayload.deserialize(modified);
        expect(
          () => OneBitEncryptedPayload.decrypt(
            key: testKey,
            payload: parsed,
          ),
          throwsA(isA<AeadCipherException>()),
        );
      });

      test('modified MAC fails decryption', () async {
        final plaintext = Uint8List.fromList('tamper mac'.codeUnits);
        final payload = await OneBitEncryptedPayload.encrypt(
          key: testKey,
          plaintext: plaintext,
        );

        final bytes = payload.serialize();
        final modified = Uint8List.fromList(bytes);
        modified[modified.length - 1] ^= 0xFF; // modify last MAC byte

        final parsed = OneBitEncryptedPayload.deserialize(modified);
        expect(
          () => OneBitEncryptedPayload.decrypt(
            key: testKey,
            payload: parsed,
          ),
          throwsA(isA<AeadCipherException>()),
        );
      });
    });

    group('Full crypto chain', () {
      test('X25519 → HKDF → AES-GCM → OneBit payload round trip', () async {
        final algorithm = X25519();

        final keyPairA = await algorithm.newKeyPair();
        final keyPairB = await algorithm.newKeyPair();

        final publicKeyA = await keyPairA.extractPublicKey();
        final publicKeyB = await keyPairB.extractPublicKey();

        // Both compute same shared secret
        final sharedSecretAB = await algorithm.sharedSecretKey(
          keyPair: keyPairA,
          remotePublicKey: publicKeyB,
        );
        final sharedSecretBA = await algorithm.sharedSecretKey(
          keyPair: keyPairB,
          remotePublicKey: publicKeyA,
        );

        // Both derive same session key
        final sessionKeyAB = await KeyDerivation.deriveSessionKey(
          sharedSecret: sharedSecretAB,
        );
        final sessionKeyBA = await KeyDerivation.deriveSessionKey(
          sharedSecret: sharedSecretBA,
        );

        // A encrypts
        final plaintext = Uint8List.fromList('Hello from A'.codeUnits);
        final payload = await OneBitEncryptedPayload.encrypt(
          key: sessionKeyAB,
          plaintext: plaintext,
        );

        // Serialize
        final bytes = payload.serialize();

        // Deserialize
        final parsed = OneBitEncryptedPayload.deserialize(bytes);

        // B decrypts
        final decrypted = await OneBitEncryptedPayload.decrypt(
          key: sessionKeyBA,
          payload: parsed,
        );

        expect(decrypted, equals(plaintext));
      });

      test('peer isolation — A→B cannot decrypt with A→C key', () async {
        final algorithm = X25519();

        final keyPairA = await algorithm.newKeyPair();
        final keyPairB = await algorithm.newKeyPair();
        final keyPairC = await algorithm.newKeyPair();

        final publicKeyB = await keyPairB.extractPublicKey();
        final publicKeyC = await keyPairC.extractPublicKey();

        // A→B key
        final sharedSecretAB = await algorithm.sharedSecretKey(
          keyPair: keyPairA,
          remotePublicKey: publicKeyB,
        );
        final sessionKeyAB = await KeyDerivation.deriveSessionKey(
          sharedSecret: sharedSecretAB,
        );

        // A→C key
        final sharedSecretAC = await algorithm.sharedSecretKey(
          keyPair: keyPairA,
          remotePublicKey: publicKeyC,
        );
        final sessionKeyAC = await KeyDerivation.deriveSessionKey(
          sharedSecret: sharedSecretAC,
        );

        // A encrypts for B
        final plaintext = Uint8List.fromList('For B'.codeUnits);
        final payload = await OneBitEncryptedPayload.encrypt(
          key: sessionKeyAB,
          plaintext: plaintext,
        );

        // C cannot decrypt
        expect(
          () => OneBitEncryptedPayload.decrypt(
            key: sessionKeyAC,
            payload: payload,
          ),
          throwsA(isA<AeadCipherException>()),
        );
      });
    });

    group('Version', () {
      test('version constant is defined', () {
        expect(encryptedPayloadVersion, 1);
      });

      test('payload uses current version', () async {
        final plaintext = Uint8List.fromList('v'.codeUnits);
        final payload = await OneBitEncryptedPayload.encrypt(
          key: testKey,
          plaintext: plaintext,
        );
        expect(payload.version, encryptedPayloadVersion);
      });
    });

    group('PayloadDeserializationException', () {
      test('has message', () {
        const exception = PayloadDeserializationException('test error');
        expect(exception.message, 'test error');
        expect(
          exception.toString(),
          'PayloadDeserializationException: test error',
        );
      });
    });
  });
}
