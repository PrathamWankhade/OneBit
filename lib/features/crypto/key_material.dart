import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:onebit/features/identity/identity_repository.dart';

/// Derives or retrieves the local X25519 key-agreement keypair.
///
/// The X25519 keypair is deterministically derived from the Ed25519 identity
/// seed using SHA-256, ensuring a stable key for the lifetime of the
/// identity without requiring separate storage.
///
/// ## Security properties
///
/// - The X25519 private key is never stored in Drift, logs, or UI.
/// - The public key can be freely shared with peers.
/// - Key derivation is deterministic: same Ed25519 seed → same X25519 keypair.
class KeyMaterial {
  /// Domain separation tag for X25519 key derivation.
  static final Uint8List _domainTag = Uint8List.fromList(
    'onebit.x25519.key_derivation'.codeUnits,
  );

  /// Derive the X25519 keypair from an Ed25519 seed.
  ///
  /// Uses SHA-256 with a domain-specific tag to separate
  /// the derived key from other uses of the same seed.
  static Future<SimpleKeyPair> deriveLocalKeyAgreementKey({
    required Uint8List ed25519Seed,
  }) async {
    if (ed25519Seed.length != 32) {
      throw ArgumentError('Ed25519 seed must be 32 bytes');
    }

    // Combine seed with domain tag and hash to get 32-byte X25519 seed
    final input = Uint8List(32 + _domainTag.length);
    input.setRange(0, 32, ed25519Seed);
    input.setRange(32, input.length, _domainTag);

    final sha256 = Sha256();
    final hash = await sha256.hash(input);
    final derivedSeed = Uint8List.fromList(hash.bytes);

    return X25519().newKeyPairFromSeed(derivedSeed);
  }

  /// Get the local X25519 public key bytes (32 bytes).
  static Future<Uint8List> getLocalPublicKey({
    required Uint8List ed25519Seed,
  }) async {
    final keyPair = await deriveLocalKeyAgreementKey(
      ed25519Seed: ed25519Seed,
    );
    final publicKey = await keyPair.extract();
    return Uint8List.fromList(publicKey.bytes);
  }

  /// Validate a remote X25519 public key.
  ///
  /// Returns true if the key is a valid 32-byte X25519 public key.
  static bool validateRemotePublicKey(Uint8List keyBytes) {
    if (keyBytes.length != 32) return false;
    // Check that the key is not all zeros
    return keyBytes.any((b) => b != 0);
  }
}

/// Represents a peer's key-agreement public material.
class PeerKeyMaterial {
  const PeerKeyMaterial({
    required this.peerId,
    required this.keyAgreementPublicKey,
  });

  /// The peer's identity ID (hex-encoded Ed25519 public key).
  final String peerId;

  /// The peer's X25519 public key bytes (32 bytes).
  final Uint8List keyAgreementPublicKey;

  /// Hex-encoded X25519 public key.
  String get keyAgreementPublicKeyHex =>
      IdentityRepository.bytesToHex(keyAgreementPublicKey);
}
