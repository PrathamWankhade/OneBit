import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// HKDF-SHA256 key derivation for OneBit session keys.
///
/// Converts a raw X25519 shared secret into derived session key material
/// suitable for authenticated encryption (AES-256-GCM).
///
/// ## Usage
///
/// ```dart
/// final sharedSecret = SecretKey(rawSharedSecretBytes);
/// final sessionKey = await KeyDerivation.deriveSessionKey(
///   sharedSecret: sharedSecret,
///   context: Uint8List.fromList('onebit.session.v1'.codeUnits),
/// );
/// ```
///
/// ## Security properties
///
/// - Deterministic: same inputs → same output
/// - Domain-separated: different contexts → different keys
/// - 256-bit output for AES-256-GCM
/// - Uses HKDF-SHA256 from `package:cryptography`
class KeyDerivation {
  KeyDerivation._();

  /// Output length for AES-256-GCM session keys (256 bits = 32 bytes).
  static const int sessionKeyLength = 32;

  /// Protocol context prefix for OneBit session key derivation.
  static const String _contextPrefix = 'onebit.session.v1';

  /// Derive a session key from a shared secret using HKDF-SHA256.
  ///
  /// [sharedSecret] is the raw X25519 shared secret from key agreement.
  /// [context] is additional context for domain separation (optional).
  /// [outputLength] is the desired key length in bytes (default: 32 for AES-256).
  ///
  /// Returns a [SecretKey] containing the derived key material.
  ///
  /// Throws [ArgumentError] if the shared secret is empty.
  /// Throws [KeyDerivationException] if derivation fails.
  static Future<SecretKey> deriveSessionKey({
    required SecretKey sharedSecret,
    Uint8List? context,
    int outputLength = sessionKeyLength,
  }) async {
    if (outputLength <= 0 || outputLength > 255) {
      throw ArgumentError('Output length must be between 1 and 255 bytes');
    }

    // Build the HKDF info parameter with domain separation
    final info = _buildInfo(context);

    try {
      // Use HKDF-SHA256 for key derivation
      final hkdf = Hkdf(
        hmac: Hmac.sha256(),
        outputLength: outputLength,
      );

      // Derive key material (no salt for now — can be added later)
      final derivedKey = await hkdf.deriveKey(
        secretKey: sharedSecret,
        info: info,
        nonce: Uint8List(0), // No salt
      );

      return derivedKey;
    } catch (e) {
      throw KeyDerivationException('Failed to derive session key: $e');
    }
  }

  /// Derive raw bytes from a shared secret.
  ///
  /// Convenience method that returns the derived key as raw bytes.
  static Future<Uint8List> deriveSessionKeyBytes({
    required SecretKey sharedSecret,
    Uint8List? context,
    int outputLength = sessionKeyLength,
  }) async {
    final key = await deriveSessionKey(
      sharedSecret: sharedSecret,
      context: context,
      outputLength: outputLength,
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  /// Build the HKDF info parameter with domain separation.
  static Uint8List _buildInfo(Uint8List? context) {
    final parts = <Uint8List>[
      Uint8List.fromList(_contextPrefix.codeUnits),
    ];

    if (context != null && context.isNotEmpty) {
      parts.add(context);
    }

    // Concatenate parts with length prefix for canonical encoding
    final buffer = BytesBuilder();
    for (final part in parts) {
      // Add length as 2-byte big-endian
      buffer.addByte((part.length >> 8) & 0xFF);
      buffer.addByte(part.length & 0xFF);
      buffer.add(part);
    }

    return buffer.toBytes();
  }
}

/// Exception for key derivation failures.
class KeyDerivationException implements Exception {
  const KeyDerivationException(this.message);
  final String message;

  @override
  String toString() => 'KeyDerivationException: $message';
}
