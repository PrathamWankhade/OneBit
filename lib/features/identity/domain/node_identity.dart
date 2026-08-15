import 'package:flutter/foundation.dart';
import 'package:onebit/core/crypto/identity/fingerprint.dart';
import 'package:onebit/core/crypto/identity/node_id.dart';
import 'package:onebit/features/identity/domain/user_profile.dart';

/// Public identity material of this node.
///
/// This is the only identity object that flows into presentation state: it
/// deliberately carries **no private key bytes**. Seeds live in the Android
/// Keystore vault and are materialized by the repository only for the
/// duration of a signing or key-agreement call.
@immutable
final class NodeIdentity {
  const NodeIdentity({
    required this.uuid,
    required this.nodeId,
    required this.fingerprint,
    required this.ed25519PublicKey,
    required this.x25519PublicKey,
    required this.profile,
    required this.createdAt,
  });

  /// Version-4 UUID assigned at creation (stable for life of the identity).
  final String uuid;

  /// Human-readable short identifier derived from the fingerprint.
  final NodeId nodeId;

  /// Full-strength fingerprint of the Ed25519 identity key.
  final Fingerprint fingerprint;

  /// 32-byte Ed25519 public key (identity/signing key).
  final List<int> ed25519PublicKey;

  /// 32-byte X25519 public key (key-agreement/exchange key).
  final List<int> x25519PublicKey;

  /// User-editable profile (name, avatar).
  final UserProfile profile;

  /// UTC instant the identity was first created.
  final DateTime createdAt;

  /// Convenience getter for the fingerprint hex.
  String get fingerprintHex => fingerprint.hex;

  @override
  String toString() =>
      'NodeIdentity($nodeId, ${fingerprint.hex.substring(0, 8)}…)';
}
