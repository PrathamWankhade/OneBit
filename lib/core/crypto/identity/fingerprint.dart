import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Full-strength derived identifier for a key pair.
///
/// `fingerprint = SHA-256(Ed25519 public key)`, held as 32 raw bytes and
/// rendered in three forms:
/// - [hex]: 64 lowercase hex characters (canonical, used on the wire),
/// - [formatted]: `XXXX-XXXX-…` groups of four, uppercase (shown to humans
///   for out-of-band comparison),
/// - [shortCode]: leading bytes, uppercased.
@immutable
final class Fingerprint {
  const Fingerprint._(this.bytes);

  /// Wraps exactly 32 raw bytes, the output of SHA-256.
  factory Fingerprint(Uint8List bytes) {
    if (bytes.length != 32) {
      throw ArgumentError('Fingerprint must be 32 bytes (got ${bytes.length})');
    }
    return Fingerprint._(bytes);
  }

  /// Computes the fingerprint of an Ed25519 public key.
  static Future<Fingerprint> fromPublicKey(List<int> publicKey) async {
    final hash = await Sha256().hash(publicKey);
    return Fingerprint(Uint8List.fromList(hash.bytes));
  }

  /// Parses a canonical 64-character lowercase hex fingerprint.
  factory Fingerprint.fromHex(String hex) {
    final normalized = hex.trim().toLowerCase();
    if (!RegExp('^[0-9a-f]{64}\$').hasMatch(normalized)) {
      throw FormatException('Fingerprint must be 64 hex characters', hex);
    }
    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      bytes[i] = int.parse(normalized.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return Fingerprint(bytes);
  }

  /// Validates a canonical 64-character lowercase hex fingerprint string.
  static bool isValidHex(String hex) =>
      RegExp('^[0-9a-f]{64}\$').hasMatch(hex.trim().toLowerCase());

  /// Raw 32-byte digest.
  final Uint8List bytes;

  /// Canonical lowercase hex form (64 characters).
  String get hex {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Uppercase, hyphen-grouped form for human comparison:
  /// `7A3F-91D2-…`.
  String get formatted {
    final buffer = StringBuffer();
    final hexString = hex;
    for (var i = 0; i < hexString.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write('-');
      }
      buffer.write(hexString[i]);
    }
    return buffer.toString().toUpperCase();
  }

  /// The first eight hex characters (first four bytes).
  String get headHex => hex.substring(0, 8);

  /// A stable, human-readable short code for the node, e.g. `7A3F91D2`.
  String get shortCode => headHex.toUpperCase();

  @override
  bool operator ==(Object other) =>
      other is Fingerprint &&
      (identical(bytes, other.bytes) ||
          _constantTimeEquals(bytes, other.bytes));

  @override
  int get hashCode => Object.hashAll(bytes);

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  @override
  String toString() => 'Fingerprint(${hex.substring(0, 12)}…)';
}
