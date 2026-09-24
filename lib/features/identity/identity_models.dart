import 'dart:typed_data';

/// Identity format version — bumped when serialization format changes.
const int identityFormatVersion = 1;

/// Protocol version — incremented when wire protocol changes.
const int protocolVersion = 1;

/// Local identity metadata for this OneBit installation.
///
/// There should be only one active local identity.
/// The identityId is derived from the public key (hex-encoded).
class IdentityInfo {
  IdentityInfo({
    required this.id,
    this.identityId,
    required this.displayName,
    this.about,
    required this.createdAt,
    this.publicKeyBytes,
  });

  /// Database primary key. Always 1 for the single local identity.
  final int id;

  /// Cryptographic identity identifier (hex-encoded public key).
  final String? identityId;

  /// Human-readable display name chosen by the user.
  final String displayName;

  /// Optional bio/about text (max 140 characters).
  final String? about;

  /// When this identity was created.
  final DateTime createdAt;

  /// Raw Ed25519 public key bytes (32 bytes).
  final Uint8List? publicKeyBytes;
}

/// Public identity of a remote OneBit peer.
///
/// A peer represents another OneBit identity encountered via BLE or QR.
/// The identityId will be populated when the peer's cryptographic identity is known.
class PeerInfo {
  PeerInfo({
    required this.id,
    this.identityId,
    this.publicKeyHex,
    required this.displayName,
    this.about,
    required this.createdAt,
    this.lastSeenAt,
    this.keyAgreementPublicKeyHex,
    this.lastSeenBleAddress,
  });

  /// Database primary key (auto-increment).
  final int id;

  /// Cryptographic identity identifier (hex-encoded public key).
  final String? identityId;

  /// Hex-encoded Ed25519 public key bytes.
  final String? publicKeyHex;

  /// Human-readable display name chosen by the peer.
  final String displayName;

  /// Optional bio/about text shared by the peer.
  final String? about;

  /// When this identity was first discovered.
  final DateTime createdAt;

  /// When this identity was last seen via BLE.
  final DateTime? lastSeenAt;

  /// Hex-encoded X25519 key-agreement public key (32 bytes).
  final String? keyAgreementPublicKeyHex;

  /// Last BLE address (MAC) seen for this peer identity.
  final String? lastSeenBleAddress;
}
