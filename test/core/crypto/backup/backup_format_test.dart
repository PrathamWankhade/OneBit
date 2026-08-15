import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/crypto/backup/backup_format.dart';

void main() {
  BackupEnvelope envelope() => BackupEnvelope(
    aad: const BackupAad(
      nodeId: 'NODE-7A3F-91D2',
      createdAt: '2026-01-01T00:00:00Z',
    ),
    salt: Uint8List.fromList([
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
    ]),
    nonce: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]),
    cipherText: Uint8List.fromList([1, 2, 3]),
    mac: Uint8List.fromList([9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9]),
  );

  group('BackupFormat', () {
    test('encode/decode round-trips every field', () {
      final document = BackupFormat.encodeDocument(envelope());
      final decoded = BackupFormat.decodeDocument(document);

      expect(decoded.aad.nodeId, 'NODE-7A3F-91D2');
      expect(decoded.aad.createdAt, '2026-01-01T00:00:00Z');
      expect(decoded.salt, envelope().salt);
      expect(decoded.nonce, envelope().nonce);
      expect(decoded.cipherText, envelope().cipherText);
      expect(decoded.mac, envelope().mac);
      expect(decoded.version, 1);
    });

    test('document uses the url-safe base64 alphabet without padding', () {
      final document = BackupFormat.encodeDocument(envelope());
      expect(document.contains('='), isFalse);
      expect(document.contains('+'), isFalse);
      expect(document.contains('/'), isFalse);
    });

    test('rejects a document with the wrong magic', () {
      final document = BackupFormat.encodeDocument(envelope());
      final bytes = base64Url.decode(
        document.padRight(document.length + (4 - document.length % 4) % 4, '='),
      );
      bytes[0] = 'X'.codeUnitAt(0);
      final forged = base64Url.encode(bytes).replaceAll('=', '');
      expect(() => BackupFormat.decodeDocument(forged), throwsFormatException);
    });

    test('rejects an unsupported version', () {
      final document = BackupFormat.encodeDocument(envelope());
      final bytes = base64Url.decode(
        document.padRight(document.length + (4 - document.length % 4) % 4, '='),
      );
      bytes[8] = 2;
      final bumped = base64Url.encode(bytes).replaceAll('=', '');
      expect(() => BackupFormat.decodeDocument(bumped), throwsFormatException);
    });

    test('rejects truncated or invalid documents', () {
      expect(() => BackupFormat.decodeDocument(''), throwsFormatException);
      expect(
        () => BackupFormat.decodeDocument('!!not-base64!!'),
        throwsFormatException,
      );
    });
  });
}
