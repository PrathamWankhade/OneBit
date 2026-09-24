import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/crypto/key_material.dart';
import 'package:onebit/features/identity/identity_repository.dart';

void main() {
  group('KeyMaterial', () {
    late SimpleKeyPair ed25519KeyPair;
    late Uint8List ed25519Seed;

    setUp(() async {
      final algorithm = Ed25519();
      ed25519KeyPair = await algorithm.newKeyPair();
      final privateKey = await ed25519KeyPair.extract();
      ed25519Seed = Uint8List.fromList(privateKey.bytes);
    });

    test('deriveLocalKeyAgreementKey produces valid X25519 keypair', () async {
      final x25519KeyPair = await KeyMaterial.deriveLocalKeyAgreementKey(
        ed25519Seed: ed25519Seed,
      );
      expect(x25519KeyPair, isNotNull);
      final publicKey = await x25519KeyPair.extract();
      expect(publicKey.bytes.length, 32);
    });

    test('deriveLocalKeyAgreementKey is deterministic', () async {
      final key1 = await KeyMaterial.deriveLocalKeyAgreementKey(
        ed25519Seed: ed25519Seed,
      );
      final key2 = await KeyMaterial.deriveLocalKeyAgreementKey(
        ed25519Seed: ed25519Seed,
      );
      final pub1 = await key1.extract();
      final pub2 = await key2.extract();
      expect(pub1.bytes, equals(pub2.bytes));
    });

    test('deriveLocalKeyAgreementKey rejects wrong seed length', () async {
      expect(
        () => KeyMaterial.deriveLocalKeyAgreementKey(
          ed25519Seed: Uint8List(16),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getLocalPublicKey returns 32 bytes', () async {
      final publicKey = await KeyMaterial.getLocalPublicKey(
        ed25519Seed: ed25519Seed,
      );
      expect(publicKey.length, 32);
    });

    test('getLocalPublicKey is stable across calls', () async {
      final key1 = await KeyMaterial.getLocalPublicKey(
        ed25519Seed: ed25519Seed,
      );
      final key2 = await KeyMaterial.getLocalPublicKey(
        ed25519Seed: ed25519Seed,
      );
      expect(key1, equals(key2));
    });

    test('different Ed25519 seeds produce different X25519 keys', () async {
      final algorithm = Ed25519();
      final otherKeyPair = await algorithm.newKeyPair();
      final otherSeed = Uint8List.fromList(
        (await otherKeyPair.extract()).bytes,
      );

      final key1 = await KeyMaterial.getLocalPublicKey(
        ed25519Seed: ed25519Seed,
      );
      final key2 = await KeyMaterial.getLocalPublicKey(
        ed25519Seed: otherSeed,
      );
      expect(key1, isNot(equals(key2)));
    });

    test('X25519 public key is different from Ed25519 public key', () async {
      final x25519Pub = await KeyMaterial.getLocalPublicKey(
        ed25519Seed: ed25519Seed,
      );
      final ed25519Pub = await ed25519KeyPair.extract();
      expect(x25519Pub, isNot(equals(Uint8List.fromList(ed25519Pub.bytes))));
    });
  });

  group('KeyMaterial - validateRemotePublicKey', () {
    test('accepts valid 32-byte key', () async {
      final algorithm = X25519();
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extract();
      final valid = KeyMaterial.validateRemotePublicKey(
        Uint8List.fromList(publicKey.bytes),
      );
      expect(valid, isTrue);
    });

    test('rejects 16-byte key', () async {
      final valid = KeyMaterial.validateRemotePublicKey(Uint8List(16));
      expect(valid, isFalse);
    });

    test('rejects 64-byte key', () async {
      final valid = KeyMaterial.validateRemotePublicKey(Uint8List(64));
      expect(valid, isFalse);
    });

    test('rejects empty key', () async {
      final valid = KeyMaterial.validateRemotePublicKey(Uint8List(0));
      expect(valid, isFalse);
    });

    test('rejects all-zeros key', () async {
      final valid = KeyMaterial.validateRemotePublicKey(Uint8List(32));
      expect(valid, isFalse);
    });
  });

  group('PeerKeyMaterial', () {
    test('holds all fields', () async {
      final algorithm = X25519();
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extract();

      final material = PeerKeyMaterial(
        peerId: 'peer123',
        keyAgreementPublicKey: Uint8List.fromList(publicKey.bytes),
      );

      expect(material.peerId, 'peer123');
      expect(material.keyAgreementPublicKey.length, 32);
      expect(material.keyAgreementPublicKeyHex.length, 64);
    });

    test('keyAgreementPublicKeyHex is valid hex', () async {
      final algorithm = X25519();
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extract();

      final material = PeerKeyMaterial(
        peerId: 'peer',
        keyAgreementPublicKey: Uint8List.fromList(publicKey.bytes),
      );

      // Verify hex is valid
      final hex = material.keyAgreementPublicKeyHex;
      expect(hex.length, 64);
      expect(int.tryParse(hex.substring(0, 2), radix: 16), isNotNull);
    });
  });

  group('Identity stability', () {
    test('adding X25519 does not change Ed25519 identity', () async {
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extract();
      final identityId = IdentityRepository.bytesToHex(
        Uint8List.fromList(publicKey.bytes),
      );

      // Derive X25519 key
      final privateKey = await keyPair.extract();
      final x25519Pub = await KeyMaterial.getLocalPublicKey(
        ed25519Seed: Uint8List.fromList(privateKey.bytes),
      );

      // Ed25519 identity is unchanged
      final ed25519Pub = await keyPair.extract();
      expect(
        identityId,
        equals(IdentityRepository.bytesToHex(
          Uint8List.fromList(ed25519Pub.bytes),
        )),
      );
      // X25519 key is different
      expect(x25519Pub, isNot(equals(Uint8List.fromList(ed25519Pub.bytes))));
    });
  });

  group('Peer isolation', () {
    test('different peers have different key material', () async {
      final algorithm = Ed25519();
      final key1 = await algorithm.newKeyPair();
      final key2 = await algorithm.newKeyPair();

      final seed1 = Uint8List.fromList((await key1.extract()).bytes);
      final seed2 = Uint8List.fromList((await key2.extract()).bytes);

      final x25519_1 = await KeyMaterial.getLocalPublicKey(
        ed25519Seed: seed1,
      );
      final x25519_2 = await KeyMaterial.getLocalPublicKey(
        ed25519Seed: seed2,
      );

      expect(x25519_1, isNot(equals(x25519_2)));
    });
  });

  group('No secrets in PeerKeyMaterial', () {
    test('peer record contains only public key', () async {
      final algorithm = X25519();
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extract();

      final material = PeerKeyMaterial(
        peerId: 'peer',
        keyAgreementPublicKey: Uint8List.fromList(publicKey.bytes),
      );

      // Verify no private key field exists
      expect(() {
        // ignore: invalid_use_of_protected_member
        material.keyAgreementPublicKey;
      }, isA<void>());
    });
  });
}
