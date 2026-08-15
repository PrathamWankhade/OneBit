import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/crypto/backup/backup_cipher.dart';
import 'package:onebit/core/crypto/backup/backup_format.dart';
import 'package:onebit/core/errors/failure.dart';

void main() {
  const aad = BackupAad(
    nodeId: 'NODE-7A3F-91D2',
    createdAt: '2026-01-01T00:00:00Z',
  );
  const plaintext = <String, Object?>{
    'v': 1,
    'uuid': '550e8400-e29b-41d4-a716-446655440000',
    'displayName': 'Alice',
  };

  group('BackupCipher', () {
    test('encrypt produces a decodable envelope document', () async {
      final result = await BackupCipher.encrypt(
        passphrase: 'correct horse battery staple',
        plaintext: plaintext,
        aad: aad,
      );
      expect(result.isOk, isTrue, reason: result.failure?.toString());
      final envelope = result.value!;
      expect(envelope.salt, hasLength(16));
      expect(envelope.nonce, hasLength(12));
      expect(envelope.mac, hasLength(16));
      expect(envelope.cipherText, isNotEmpty);

      final document = BackupFormat.encodeDocument(envelope);
      final decoded = BackupFormat.decodeDocument(document);
      expect(decoded.aad.nodeId, aad.nodeId);
    });

    test(
      'decrypt returns the original plaintext with the right passphrase',
      () async {
        final envelopeResult = await BackupCipher.encrypt(
          passphrase: 'correct horse battery staple',
          plaintext: plaintext,
          aad: aad,
        );
        final decrypted = await BackupCipher.decrypt(
          passphrase: 'correct horse battery staple',
          envelope: envelopeResult.value!,
        );
        expect(decrypted.isOk, isTrue, reason: decrypted.failure?.toString());
        expect(decrypted.value!['uuid'], plaintext['uuid']);
        expect(decrypted.value!['displayName'], 'Alice');
      },
    );

    test('wrong passphrase fails with a BackupFailure', () async {
      final envelopeResult = await BackupCipher.encrypt(
        passphrase: 'correct horse battery staple',
        plaintext: plaintext,
        aad: aad,
      );
      final decrypted = await BackupCipher.decrypt(
        passphrase: 'wrong-passphrase',
        envelope: envelopeResult.value!,
      );
      expect(decrypted.isErr, isTrue);
      final failure = decrypted.failure!;
      expect(failure, isA<BackupFailure>());
      expect((failure as BackupFailure).operation, 'decrypt');
    });

    test('tampered ciphertext fails with a BackupFailure', () async {
      final envelopeResult = await BackupCipher.encrypt(
        passphrase: 'correct horse battery staple',
        plaintext: plaintext,
        aad: aad,
      );
      final tamperedEnvelope = BackupEnvelope(
        aad: envelopeResult.value!.aad,
        salt: envelopeResult.value!.salt,
        nonce: envelopeResult.value!.nonce,
        cipherText: Uint8List.fromList(envelopeResult.value!.cipherText)
          ..[0] ^= 0x01,
        mac: envelopeResult.value!.mac,
      );
      final decrypted = await BackupCipher.decrypt(
        passphrase: 'correct horse battery staple',
        envelope: tamperedEnvelope,
      );
      expect(decrypted.isErr, isTrue);
      expect(decrypted.failure, isA<BackupFailure>());
    });

    test('swapped header (AAD) fails authentication', () async {
      final envelopeResult = await BackupCipher.encrypt(
        passphrase: 'correct horse battery staple',
        plaintext: plaintext,
        aad: aad,
      );
      final forged = BackupEnvelope(
        aad: const BackupAad(
          nodeId: 'NODE-1111-2222',
          createdAt: '2025-01-01T00:00:00Z',
        ),
        salt: envelopeResult.value!.salt,
        nonce: envelopeResult.value!.nonce,
        cipherText: envelopeResult.value!.cipherText,
        mac: envelopeResult.value!.mac,
      );
      final decrypted = await BackupCipher.decrypt(
        passphrase: 'correct horse battery staple',
        envelope: forged,
      );
      expect(decrypted.isErr, isTrue);
    });

    test(
      'two exports of the same plaintext produce distinct documents',
      () async {
        final first = await BackupCipher.encrypt(
          passphrase: 'pass',
          plaintext: plaintext,
          aad: aad,
        );
        final second = await BackupCipher.encrypt(
          passphrase: 'pass',
          plaintext: plaintext,
          aad: aad,
        );
        expect(first.value!.salt, isNot(second.value!.salt));
        expect(first.value!.cipherText, isNot(second.value!.cipherText));
      },
    );

    test('plaintext may be any JSON-serializable map', () async {
      final result = await BackupCipher.encrypt(
        passphrase: 'pass',
        plaintext: const <String, Object?>{
          'seed': <int>[1, 2, 3],
          'contacts': 'none',
        },
        aad: aad,
      );
      expect(result.isOk, isTrue, reason: result.failure?.toString());
      final decrypted = await BackupCipher.decrypt(
        passphrase: 'pass',
        envelope: result.value!,
      );
      expect(decrypted.isOk, isTrue);
      expect((decrypted.value!['seed']! as List).map((e) => e as int), [
        1,
        2,
        3,
      ]);
    });
  });
}
