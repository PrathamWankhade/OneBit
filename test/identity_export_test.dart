import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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

  group('PublicIdentity', () {
    test('toJson includes required fields', () {
      final public = PublicIdentity(
        formatVersion: 1,
        identityType: 'ed25519',
        publicKeyHex: testKeyHex,
      );

      final json = public.toJson();

      expect(json['formatVersion'], 1);
      expect(json['identityType'], 'ed25519');
      expect(json['publicKey'], testKeyHex);
    });

    test('toJson includes optional fields when present', () {
      final public = PublicIdentity(
        formatVersion: 1,
        identityType: 'ed25519',
        publicKeyHex: testKeyHex,
        displayName: 'Alice',
        fingerprint: 'ABCD 1234',
      );

      final json = public.toJson();

      expect(json['displayName'], 'Alice');
      expect(json['fingerprint'], 'ABCD 1234');
    });

    test('toJson omits null optional fields', () {
      final public = PublicIdentity(
        formatVersion: 1,
        identityType: 'ed25519',
        publicKeyHex: testKeyHex,
      );

      final json = public.toJson();

      expect(json.containsKey('displayName'), isFalse);
      expect(json.containsKey('fingerprint'), isFalse);
    });

    test('fromJson round-trip', () {
      final original = PublicIdentity(
        formatVersion: 1,
        identityType: 'ed25519',
        publicKeyHex: testKeyHex,
        displayName: 'Bob',
        fingerprint: 'ABCD 1234',
      );

      final restored = PublicIdentity.fromJson(original.toJson());

      expect(restored.formatVersion, original.formatVersion);
      expect(restored.identityType, original.identityType);
      expect(restored.publicKeyHex, original.publicKeyHex);
      expect(restored.displayName, original.displayName);
      expect(restored.fingerprint, original.fingerprint);
    });

    test('publicKeyBytes derives from hex', () {
      final public = PublicIdentity(
        formatVersion: 1,
        identityType: 'ed25519',
        publicKeyHex: testKeyHex,
      );

      expect(public.publicKeyBytes, testKeyBytes);
    });
  });

  group('exportPublicIdentity', () {
    test('exports public identity with fingerprint', () async {
      final jsonStr = await exportPublicIdentity(testIdentity);

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(json['formatVersion'], identityFormatVersion);
      expect(json['identityType'], 'ed25519');
      expect(json['publicKey'], testKeyHex);
      expect(json['displayName'], 'Test User');
      expect(json['fingerprint'], isNotNull);
      expect(json['fingerprint'], isA<String>());
    });

    test('fingerprint matches computeFingerprint', () async {
      final jsonStr = await exportPublicIdentity(testIdentity);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final exportedFingerprint = json['fingerprint'] as String;

      final expectedFingerprint = await computeFingerprint(testKeyBytes);

      expect(exportedFingerprint, expectedFingerprint);
    });

    test('export is deterministic', () async {
      final json1 = await exportPublicIdentity(testIdentity);
      final json2 = await exportPublicIdentity(testIdentity);

      expect(json1, json2);
    });

    test('does not contain private key', () async {
      final jsonStr = await exportPublicIdentity(testIdentity);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(json.containsKey('privateKey'), isFalse);
      expect(json.containsKey('privateKeyHex'), isFalse);
      expect(json.containsKey('seed'), isFalse);
      expect(json.containsKey('secret'), isFalse);
    });

    test('throws on identity without cryptographic material', () async {
      final noCrypto = IdentityInfo(
        id: 1,
        displayName: 'No Crypto',
        createdAt: DateTime(2025),
      );

      expect(
        () => exportPublicIdentity(noCrypto),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('valid JSON output', () async {
      final jsonStr = await exportPublicIdentity(testIdentity);

      // Should not throw
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(parsed, isA<Map<String, dynamic>>());
    });
  });

  group('importPublicIdentity', () {
    test('imports valid public identity', () async {
      final jsonStr = await exportPublicIdentity(testIdentity);

      final result = importPublicIdentity(jsonStr);

      expect(result.identity.formatVersion, identityFormatVersion);
      expect(result.identity.identityType, 'ed25519');
      expect(result.identity.publicKeyHex, testKeyHex);
      expect(result.identity.displayName, 'Test User');
      expect(result.isLocalIdentity, isFalse); // No local key provided
    });

    test('round-trip preserves identity', () async {
      final exported = await exportPublicIdentity(testIdentity);
      final imported = importPublicIdentity(exported);

      expect(imported.identity.publicKeyHex, testKeyHex);
      expect(imported.identity.displayName, 'Test User');

      // Fingerprint should match
      final expectedFingerprint = await computeFingerprint(testKeyBytes);
      expect(imported.identity.fingerprint, expectedFingerprint);
    });

    test('detects local identity when key matches', () async {
      final exported = await exportPublicIdentity(testIdentity);

      final result = importPublicIdentity(
        exported,
        localPublicKeyHex: testKeyHex,
      );

      expect(result.isLocalIdentity, isTrue);
    });

    test('does not detect local identity when key differs', () async {
      final exported = await exportPublicIdentity(testIdentity);
      final otherKey = IdentityRepository.bytesToHex(
        Uint8List.fromList(List.generate(32, (i) => i + 100)),
      );

      final result = importPublicIdentity(
        exported,
        localPublicKeyHex: otherKey,
      );

      expect(result.isLocalIdentity, isFalse);
    });
  });

  group('importPublicIdentity - validation', () {
    test('rejects empty string', () {
      expect(
        () => importPublicIdentity(''),
        throwsA(isA<ImportError>()),
      );
    });

    test('rejects invalid JSON', () {
      expect(
        () => importPublicIdentity('not json'),
        throwsA(isA<ImportError>()),
      );
    });

    test('rejects JSON array instead of object', () {
      expect(
        () => importPublicIdentity('[]'),
        throwsA(isA<ImportError>()),
      );
    });

    test('rejects missing formatVersion', () {
      final json = jsonEncode({
        'identityType': 'ed25519',
        'publicKey': testKeyHex,
      });

      expect(
        () => importPublicIdentity(json),
        throwsA(isA<ImportError>()),
      );
    });

    test('rejects missing identityType', () {
      final json = jsonEncode({
        'formatVersion': 1,
        'publicKey': testKeyHex,
      });

      expect(
        () => importPublicIdentity(json),
        throwsA(isA<ImportError>()),
      );
    });

    test('rejects missing publicKey', () {
      final json = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
      });

      expect(
        () => importPublicIdentity(json),
        throwsA(isA<ImportError>()),
      );
    });

    test('rejects wrong formatVersion type', () {
      final json = jsonEncode({
        'formatVersion': 'one',
        'identityType': 'ed25519',
        'publicKey': testKeyHex,
      });

      expect(
        () => importPublicIdentity(json),
        throwsA(isA<ImportError>()),
      );
    });

    test('rejects unsupported formatVersion', () {
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

    test('rejects unsupported identityType', () {
      final json = jsonEncode({
        'formatVersion': 1,
        'identityType': 'rsa',
        'publicKey': testKeyHex,
      });

      expect(
        () => importPublicIdentity(json),
        throwsA(isA<ImportError>()),
      );
    });

    test('rejects empty publicKey', () {
      final json = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': '',
      });

      expect(
        () => importPublicIdentity(json),
        throwsA(isA<ImportError>()),
      );
    });

    test('rejects non-hex publicKey', () {
      final json = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': 'not-hex-at-all',
      });

      expect(
        () => importPublicIdentity(json),
        throwsA(isA<ImportError>()),
      );
    });

    test('rejects wrong-length publicKey', () {
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

    test('rejects publicKey that is too long', () {
      final json = jsonEncode({
        'formatVersion': 1,
        'identityType': 'ed25519',
        'publicKey': '${testKeyHex}ab', // 66 chars
      });

      expect(
        () => importPublicIdentity(json),
        throwsA(isA<ImportError>()),
      );
    });
  });

  group('importPublicIdentity - private key exclusion', () {
    test('public export contains no private key field', () async {
      final exported = await exportPublicIdentity(testIdentity);
      final json = jsonDecode(exported) as Map<String, dynamic>;

      // Ensure no private key variants are present
      expect(json.containsKey('privateKey'), isFalse);
      expect(json.containsKey('privateKeyHex'), isFalse);
      expect(json.containsKey('privateKeyBytes'), isFalse);
      expect(json.containsKey('seed'), isFalse);
      expect(json.containsKey('secretKey'), isFalse);
      expect(json.containsKey('secret'), isFalse);
    });

    test('imported identity has no private key access', () async {
      final exported = await exportPublicIdentity(testIdentity);
      final result = importPublicIdentity(exported);

      // PublicIdentity class has no private key field
      expect(result.identity.toJson().containsKey('privateKey'), isFalse);
    });
  });

  group('importPublicIdentity - peer compatibility', () {
    test('works with hex-derived bytes from peer', () async {
      // Simulate: export from device A, import on device B
      final exported = await exportPublicIdentity(testIdentity);

      // Device B parses the JSON
      final result = importPublicIdentity(exported);

      // Device B can compute fingerprint from the imported public key
      final importedFingerprint = await computeFingerprint(
        result.identity.publicKeyBytes,
      );

      expect(importedFingerprint, result.identity.fingerprint);
    });

    test('imported identity produces same fingerprint as original', () async {
      final originalFingerprint = await computeFingerprint(testKeyBytes);

      final exported = await exportPublicIdentity(testIdentity);
      final result = importPublicIdentity(exported);

      final importedFingerprint = await computeFingerprint(
        result.identity.publicKeyBytes,
      );

      expect(importedFingerprint, originalFingerprint);
    });
  });

  group('ImportError', () {
    test('toString includes message', () {
      final error = ImportError('test error');
      expect(error.toString(), 'ImportError: test error');
    });
  });
}
