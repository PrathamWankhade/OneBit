import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// X25519 + HKDF-SHA256 + AES-256-GCM building blocks for confidential
/// payloads (QR identity transfer, encrypted message pre-keys in later
/// phases).
///
/// The design splits *raw shared secret derivation* (needs private key
/// material, may be delegated to the Android Keystore) from *key derivation
/// and symmetric encryption* (pure symmetric math, always runs in Dart).
abstract final class ExchangeCrypto {
  /// X25519 implementation (pure Dart on the VM).
  static final X25519 _x25519 = X25519();

  /// Derives the 32-byte X25519 public key from [seed].
  static Future<Uint8List> publicKeyFromSeed(Uint8List seed) async {
    final keyPair = await _x25519.newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    return Uint8List.fromList(publicKey.bytes);
  }

  /// Computes the X25519 shared secret between [keyPairSeed] and
  /// [remotePublicKey] (32 bytes).
  static Future<Uint8List> sharedSecret({
    required Uint8List keyPairSeed,
    required List<int> remotePublicKey,
  }) async {
    final keyPair = await _x25519.newKeyPairFromSeed(keyPairSeed);
    final remote = SimplePublicKey(
      Uint8List.fromList(remotePublicKey),
      type: KeyPairType.x25519,
    );
    final secret = await _x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: remote,
    );
    final bytes = await secret.extractBytes();
    return Uint8List.fromList(bytes);
  }

  /// Derives a 32-byte AES key from [sharedSecret] via HKDF-SHA256.
  ///
  /// [salt] must be present and bound to the conversation (typically the
  /// concatenation of both X25519 public keys); [info] names the protocol
  /// context so keys from different flows never collide.
  static Future<Uint8List> deriveKey({
    required List<int> sharedSecret,
    required List<int> salt,
    required String info,
  }) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final key = await hkdf.deriveKey(
      secretKey: SecretKey(Uint8List.fromList(sharedSecret)),
      nonce: salt,
      info: utf8.encode(info),
    );
    return Uint8List.fromList(key.bytes);
  }

  /// Encrypts [clearText] with AES-256-GCM under [key] and a fresh [nonce].
  ///
  /// The returned [SecretBox] carries the 16-byte authentication tag; tamper
  /// detection is therefore built in.
  static Future<SecretBox> encrypt({
    required List<int> key,
    required List<int> clearText,
    required List<int> nonce,
    List<int> aad = const <int>[],
  }) {
    final aesGcm = AesGcm.with256bits();
    return aesGcm.encrypt(
      Uint8List.fromList(clearText),
      secretKey: SecretKey(Uint8List.fromList(key)),
      nonce: nonce,
      aad: aad,
    );
  }

  /// Decrypts [box] with AES-256-GCM under [key].
  ///
  /// Throws [SecretBoxAuthenticationError] when the tag does not verify.
  static Future<List<int>> decrypt({
    required List<int> key,
    required SecretBox box,
    List<int> aad = const <int>[],
  }) async {
    final aesGcm = AesGcm.with256bits();
    return aesGcm.decrypt(
      box,
      secretKey: SecretKey(Uint8List.fromList(key)),
      aad: aad,
    );
  }
}
