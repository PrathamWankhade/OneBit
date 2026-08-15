import 'package:flutter/foundation.dart';

/// Public keys and identity of a node, safe to share (used by QR cards).
@immutable
final class QrIdentityCard {
  const QrIdentityCard({
    required this.nodeId,
    required this.displayName,
    required this.fingerprintHex,
    required this.ed25519PublicKey,
    required this.x25519PublicKey,
    required this.timestamp,
    required this.signature,
  });

  /// `NODE-XXXX-XXXX` identifier.
  final String nodeId;

  /// Human-readable name chosen by the owner.
  final String displayName;

  /// 64-character lowercase hex fingerprint.
  final String fingerprintHex;

  /// 32-byte Ed25519 public key.
  final List<int> ed25519PublicKey;

  /// 32-byte X25519 public key.
  final List<int> x25519PublicKey;

  /// Unix seconds at which the card was produced.
  final int timestamp;

  /// 64-byte Ed25519 signature over the card's canonical JSON.
  final Uint8List signature;
}

/// Secret identity material carried by a QR identity transfer.
///
/// This is the only payload type that contains private seeds; it is always
/// wrapped in an ECDH-sealed envelope so only the intended recipient's
/// X25519 key can open it.
@immutable
final class QrTransferContent {
  const QrTransferContent({
    required this.nodeId,
    required this.displayName,
    required this.fingerprintHex,
    required this.ed25519Seed,
    required this.x25519Seed,
  });

  /// `NODE-XXXX-XXXX` identifier being transferred.
  final String nodeId;

  /// Human-readable name.
  final String displayName;

  /// 64-character lowercase hex fingerprint.
  final String fingerprintHex;

  /// 32-byte Ed25519 signing seed.
  final List<int> ed25519Seed;

  /// 32-byte X25519 key-agreement seed.
  final List<int> x25519Seed;
}

/// The sealed, wire-encoded form of a QR payload (both kinds).
@immutable
final class QrPayloadEnvelope {
  const QrPayloadEnvelope({required this.type, required this.text});

  /// `id` for identity cards, `xfer` for encrypted transfers.
  final String type;

  /// Full wire text: `OB1:<base64url json>`.
  final String text;
}
