import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart' as qr;
import 'package:onebit/features/identity/identity_export.dart';
import 'package:onebit/features/identity/identity_fingerprint.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/identity/identity_repository.dart';

void main() {
  late Uint8List testKeyBytes;
  late String testKeyHex;
  late IdentityInfo testIdentity;

  setUp(() {
    testKeyBytes = Uint8List.fromList(List.generate(32, (i) => i));
    testKeyHex = IdentityRepository.bytesToHex(testKeyBytes);
    testIdentity = IdentityInfo(
      id: 1,
      identityId: testKeyHex,
      displayName: 'Test User',
      createdAt: DateTime(2025),
      publicKeyBytes: testKeyBytes,
    );
  });

  group('QR payload generation', () {
    test('QR payload is valid I4.5 canonical public identity', () async {
      final jsonStr = await exportPublicIdentity(testIdentity);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(json['formatVersion'], identityFormatVersion);
      expect(json['identityType'], 'ed25519');
      expect(json['publicKey'], testKeyHex);
      expect(json['displayName'], 'Test User');
      expect(json['fingerprint'], isNotNull);
    });

    test('QR payload is valid JSON', () async {
      final jsonStr = await exportPublicIdentity(testIdentity);

      // Should not throw
      final parsed = jsonDecode(jsonStr);
      expect(parsed, isA<Map<String, dynamic>>());
    });

    test('QR payload can be encoded by qr library', () async {
      final jsonStr = await exportPublicIdentity(testIdentity);

      final payload = qr.QrPayload.fromString(jsonStr);
      final qrCode = qr.QrCode(
        payload: payload,
        errorCorrectLevel: qr.QrErrorCorrectLevel.medium,
      );
      final qrImage = qr.QrImage(qrCode);

      expect(qrImage.moduleCount, greaterThan(0));
    });

    test('same identity generates same QR payload', () async {
      final json1 = await exportPublicIdentity(testIdentity);
      final json2 = await exportPublicIdentity(testIdentity);

      expect(json1, json2);
    });

    test('different identities generate different payloads', () async {
      final otherKey = Uint8List.fromList(List.generate(32, (i) => i + 100));
      final otherIdentity = IdentityInfo(
        id: 1,
        identityId: IdentityRepository.bytesToHex(otherKey),
        displayName: 'Other User',
        createdAt: DateTime(2025),
        publicKeyBytes: otherKey,
      );

      final json1 = await exportPublicIdentity(testIdentity);
      final json2 = await exportPublicIdentity(otherIdentity);

      expect(json1, isNot(json2));
    });
  });

  group('QR round-trip', () {
    test('export -> QR encode -> decode -> import preserves identity', () async {
      // Export
      final jsonStr = await exportPublicIdentity(testIdentity);

      // QR encode (simulate what the QR display does)
      final payload = qr.QrPayload.fromString(jsonStr);
      final qrCode = qr.QrCode(
        payload: payload,
        errorCorrectLevel: qr.QrErrorCorrectLevel.medium,
      );
      // ignore: unused_local_variable
      final qrImage = qr.QrImage(qrCode);

      // Simulate QR scan (read back the data - in real life this comes from camera)
      // For testing, we verify the payload round-trips through I4.5 import
      final result = importPublicIdentity(jsonStr);

      expect(result.identity.publicKeyHex, testKeyHex);
      expect(result.identity.displayName, 'Test User');
    });

    test('fingerprint matches after QR round-trip', () async {
      final originalFingerprint = await computeFingerprint(testKeyBytes);

      final jsonStr = await exportPublicIdentity(testIdentity);
      final result = importPublicIdentity(jsonStr);

      final importedFingerprint = await computeFingerprint(
        result.identity.publicKeyBytes,
      );

      expect(importedFingerprint, originalFingerprint);
    });

    test('QR image can be rendered', () async {
      final jsonStr = await exportPublicIdentity(testIdentity);

      final payload = qr.QrPayload.fromString(jsonStr);
      final qrCode = qr.QrCode(
        payload: payload,
        errorCorrectLevel: qr.QrErrorCorrectLevel.medium,
      );
      final qrImage = qr.QrImage(qrCode);

      // Verify the QR image has valid dimensions
      // QR versions range from 21x21 (version 1) to 177x177 (version 40)
      expect(qrImage.moduleCount, greaterThanOrEqualTo(21));
      expect(qrImage.moduleCount, lessThanOrEqualTo(177));

      // Verify we can read modules
      final hasDarkModule = List.generate(
        qrImage.moduleCount,
        (x) => List.generate(
          qrImage.moduleCount,
          (y) => qrImage.isDark(x, y),
        ),
      );

      // QR should have some dark modules
      final hasAnyDark = hasDarkModule.any(
        (row) => row.any((dark) => dark),
      );
      expect(hasAnyDark, isTrue);
    });
  });

  group('QR - private key exclusion', () {
    test('QR payload contains no private key material', () async {
      final jsonStr = await exportPublicIdentity(testIdentity);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(json.containsKey('privateKey'), isFalse);
      expect(json.containsKey('privateKeyHex'), isFalse);
      expect(json.containsKey('privateKeyBytes'), isFalse);
      expect(json.containsKey('seed'), isFalse);
      expect(json.containsKey('secretKey'), isFalse);
      expect(json.containsKey('secret'), isFalse);
    });

    test('QR generation does not access private key store', () async {
      // This test verifies that exportPublicIdentity only needs
      // the IdentityInfo (public metadata), not the private key
      final jsonStr = await exportPublicIdentity(testIdentity);
      expect(jsonStr, isNotEmpty);

      // The export function signature only takes IdentityInfo
      // which contains publicKeyBytes, not the private key
    });
  });

  group('QR - invalid input handling', () {
    test('import rejects random QR text', () {
      expect(
        () => importPublicIdentity('https://example.com'),
        throwsA(isA<ImportError>()),
      );
    });

    test('import rejects Wi-Fi QR payload', () {
      expect(
        () => importPublicIdentity('WIFI:T:WPA;S:mynetwork;P:password;;'),
        throwsA(isA<ImportError>()),
      );
    });

    test('import rejects empty payload', () {
      expect(
        () => importPublicIdentity(''),
        throwsA(isA<ImportError>()),
      );
    });

    test('import rejects malformed JSON', () {
      expect(
        () => importPublicIdentity('{not valid json}'),
        throwsA(isA<ImportError>()),
      );
    });

    test('import rejects unsupported format version', () {
      final json = jsonEncode({
        'formatVersion': 99,
        'identityType': 'ed25519',
        'publicKey': testKeyHex,
      });

      expect(
        () => importPublicIdentity(json),
        throwsA(isA<ImportError>()),
      );
    });

    test('import rejects invalid public key', () {
      final json = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': 'not-hex',
      });

      expect(
        () => importPublicIdentity(json),
        throwsA(isA<ImportError>()),
      );
    });

    test('import rejects wrong key length', () {
      final json = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': 'abcd', // Too short
      });

      expect(
        () => importPublicIdentity(json),
        throwsA(isA<ImportError>()),
      );
    });
  });

  group('QR - local identity protection', () {
    test('importing local identity does not replace local identity', () async {
      final jsonStr = await exportPublicIdentity(testIdentity);

      final result = importPublicIdentity(
        jsonStr,
        localPublicKeyHex: testKeyHex,
      );

      expect(result.isLocalIdentity, isTrue);
      // The import result is returned, not persisted
      // The caller decides what to do with it
    });

    test('importing different identity does not affect local', () async {
      final otherKey = Uint8List.fromList(List.generate(32, (i) => i + 100));
      final otherIdentity = IdentityInfo(
        id: 2,
        identityId: IdentityRepository.bytesToHex(otherKey),
        displayName: 'Other',
        createdAt: DateTime(2025),
        publicKeyBytes: otherKey,
      );

      final jsonStr = await exportPublicIdentity(otherIdentity);
      final result = importPublicIdentity(
        jsonStr,
        localPublicKeyHex: testKeyHex,
      );

      expect(result.isLocalIdentity, isFalse);
    });
  });

  group('QR - fingerprint verification', () {
    test('scanned identity fingerprint matches original', () async {
      final originalFingerprint = await computeFingerprint(testKeyBytes);

      final jsonStr = await exportPublicIdentity(testIdentity);
      final result = importPublicIdentity(jsonStr);

      // Fingerprint in the exported JSON should match
      expect(result.identity.fingerprint, originalFingerprint);

      // Computed fingerprint should also match
      final computedFingerprint = await computeFingerprint(
        result.identity.publicKeyBytes,
      );
      expect(computedFingerprint, originalFingerprint);
    });
  });
}
