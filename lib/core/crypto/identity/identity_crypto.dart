import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Ed25519 signing primitives for the node identity.
///
/// OneBit signs with a deterministic 32-byte seed. The seed never travels in
/// a `Result` or model: it is produced by the key store bridge, used here in
/// memory, and handed back to the bridge for at-rest protection.
abstract final class IdentityCrypto {
  /// The single Ed25519 implementation used by the app.
  ///
  /// `Ed25519()` resolves to the pure-Dart implementation on the Dart VM and
  /// (if the platform browser build ever runs) WebCrypto in browsers; the
  /// deterministic seed API behaves identically everywhere.
  static final Ed25519 _algorithm = Ed25519();

  /// Derives the 32-byte Ed25519 public key from [seed].
  static Future<Uint8List> publicKeyFromSeed(Uint8List seed) async {
    final keyPair = await _algorithm.newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    return Uint8List.fromList(publicKey.bytes);
  }

  /// Signs [message] with [seed] and returns the 64-byte signature.
  static Future<Uint8List> sign({
    required Uint8List seed,
    required List<int> message,
  }) async {
    final keyPair = await _algorithm.newKeyPairFromSeed(seed);
    final signature = await _algorithm.sign(message, keyPair: keyPair);
    return Uint8List.fromList(signature.bytes);
  }

  /// Verifies [signature] against [message] with a 32-byte [publicKey].
  static Future<bool> verify({
    required List<int> publicKey,
    required List<int> message,
    required List<int> signature,
  }) async {
    final algorithm = _algorithm;
    final signatureObject = Signature(
      Uint8List.fromList(signature),
      publicKey: SimplePublicKey(
        Uint8List.fromList(publicKey),
        type: KeyPairType.ed25519,
      ),
    );
    return algorithm.verify(message, signature: signatureObject);
  }
}
