import 'package:flutter/foundation.dart';
import 'package:onebit/core/crypto/identity/node_id.dart';
import 'package:onebit/features/identity/domain/trust_level.dart';

/// A peer node this device knows about.
///
/// [TrustContact] holds only *public* identity material; private keys never
/// enter this model. The fingerprint and public keys come from the peer's
/// identity card (QR) or mesh announcements.
@immutable
final class TrustContact {
  const TrustContact({
    required this.nodeId,
    required this.displayName,
    required this.fingerprintHex,
    required this.ed25519PublicKey,
    required this.x25519PublicKey,
    this.trustLevel = TrustLevel.known,
    this.firstSeenAt,
    this.lastSeenAt,
    this.note = '',
  });

  /// Unique stable identifier of the peer.
  final NodeId nodeId;

  /// Name reported by the peer.
  final String displayName;

  /// 64-character lowercase hex fingerprint of the peer's identity key.
  final String fingerprintHex;

  /// 32-byte Ed25519 public key.
  final Uint8List ed25519PublicKey;

  /// 32-byte X25519 public key.
  final Uint8List x25519PublicKey;

  /// Current trust posture.
  final TrustLevel trustLevel;

  /// When this contact was first added.
  final DateTime? firstSeenAt;

  /// When this contact was last seen on the mesh.
  final DateTime? lastSeenAt;

  /// Free-form user note.
  final String note;

  TrustContact copyWith({
    String? displayName,
    String? fingerprintHex,
    Uint8List? ed25519PublicKey,
    Uint8List? x25519PublicKey,
    TrustLevel? trustLevel,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
    String? note,
  }) {
    return TrustContact(
      nodeId: nodeId,
      displayName: displayName ?? this.displayName,
      fingerprintHex: fingerprintHex ?? this.fingerprintHex,
      ed25519PublicKey: ed25519PublicKey ?? this.ed25519PublicKey,
      x25519PublicKey: x25519PublicKey ?? this.x25519PublicKey,
      trustLevel: trustLevel ?? this.trustLevel,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'nodeId': nodeId.value,
    'displayName': displayName,
    'fingerprintHex': fingerprintHex,
    'ed': _hex(ed25519PublicKey),
    'x': _hex(x25519PublicKey),
    'trustLevel': trustLevel.key,
    'firstSeenAt': firstSeenAt?.toIso8601String(),
    'lastSeenAt': lastSeenAt?.toIso8601String(),
    'note': note,
  };

  static TrustContact fromJson(Map<String, Object?> json) => TrustContact(
    nodeId: NodeId.parse(json['nodeId']! as String),
    displayName: json['displayName']! as String,
    fingerprintHex: json['fingerprintHex']! as String,
    ed25519PublicKey: _fromHex(json['ed']! as String),
    x25519PublicKey: _fromHex(json['x']! as String),
    trustLevel: TrustLevel.values.firstWhere(
      (level) => level.key == json['trustLevel'],
      orElse: () => TrustLevel.known,
    ),
    firstSeenAt: json['firstSeenAt'] == null
        ? null
        : DateTime.tryParse(json['firstSeenAt']! as String),
    lastSeenAt: json['lastSeenAt'] == null
        ? null
        : DateTime.tryParse(json['lastSeenAt']! as String),
    note: json['note'] as String? ?? '',
  );

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _fromHex(String hex) {
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  @override
  bool operator ==(Object other) =>
      other is TrustContact && other.nodeId == nodeId;

  @override
  int get hashCode => nodeId.hashCode;

  @override
  String toString() => 'TrustContact($nodeId, $displayName, $trustLevel)';
}
