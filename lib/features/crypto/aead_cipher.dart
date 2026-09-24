import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM authenticated encryption for OneBit.
///
/// Provides encryption and decryption using AES-256-GCM with the
/// 256-bit key derived by HKDF (I5.4).
///
/// ## Usage
///
/// ```dart
/// final key = SecretKey(derivedKeyBytes); // from I5.4
/// final encrypted = await AeadCipher.encrypt(
///   key: key,
///   plaintext: plaintextBytes,
/// );
/// final decrypted = await AeadCipher.decrypt(
///   key: key,
///   encrypted: encrypted,
/// );
/// ```
///
/// ## Security properties
///
/// - Fresh random nonce for each encryption (no nonce reuse)
/// - Authentication tag preserved and verified on decryption
/// - Wrong key / wrong nonce / modified ciphertext → decryption failure
/// - Uses `package:cryptography` AES-256-GCM implementation
class AeadCipher {
  AeadCipher._();

  /// The AES-GCM algorithm instance.
  static final AesGcm _algorithm = AesGcm.with256bits();

  /// Nonce length in bytes (12 for AES-GCM).
  static const int nonceLength = 12;

  /// Authentication tag (MAC) length in bytes (16 for AES-GCM).
  static const int tagLength = 16;

  /// Encrypt plaintext using AES-256-GCM.
  ///
  /// [key] is the 256-bit derived session key from I5.4.
  /// [plaintext] is the data to encrypt.
  /// [associatedData] is optional authenticated-but-not-encrypted data.
  ///
  /// Returns an [EncryptedPayload] containing nonce, ciphertext, and MAC.
  ///
  /// Throws [ArgumentError] if the key is empty.
  /// Throws [AeadCipherException] if encryption fails.
  static Future<EncryptedPayload> encrypt({
    required SecretKey key,
    required Uint8List plaintext,
    Uint8List? associatedData,
  }) async {
    if (plaintext.isEmpty) {
      throw ArgumentError('Plaintext must not be empty');
    }

    try {
      final secretBox = await _algorithm.encrypt(
        plaintext,
        secretKey: key,
        aad: associatedData ?? Uint8List(0),
      );

      return EncryptedPayload(
        nonce: Uint8List.fromList(secretBox.nonce),
        ciphertext: Uint8List.fromList(secretBox.cipherText),
        mac: Uint8List.fromList(secretBox.mac.bytes),
      );
    } catch (e) {
      throw AeadCipherException('Encryption failed: $e');
    }
  }

  /// Decrypt ciphertext using AES-256-GCM.
  ///
  /// [key] is the 256-bit derived session key from I5.4.
  /// [encrypted] is the [EncryptedPayload] to decrypt.
  /// [associatedData] must match the AAD used during encryption.
  ///
  /// Returns the decrypted plaintext bytes.
  ///
  /// Throws [AeadCipherException] if decryption or authentication fails.
  static Future<Uint8List> decrypt({
    required SecretKey key,
    required EncryptedPayload encrypted,
    Uint8List? associatedData,
  }) async {
    try {
      final secretBox = SecretBox(
        encrypted.ciphertext,
        nonce: encrypted.nonce,
        mac: Mac(encrypted.mac),
      );

      return Uint8List.fromList(
        await _algorithm.decrypt(
          secretBox,
          secretKey: key,
          aad: associatedData ?? Uint8List(0),
        ),
      );
    } catch (e) {
      throw AeadCipherException('Decryption failed: $e');
    }
  }
}

/// Encrypted payload containing all material needed for decryption.
///
/// This is the output of [AeadCipher.encrypt] and input to [AeadCipher.decrypt].
/// It contains the nonce, ciphertext, and authentication tag (MAC).
class EncryptedPayload {
  const EncryptedPayload({
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  /// The nonce used for encryption (12 bytes for AES-GCM).
  final Uint8List nonce;

  /// The encrypted data.
  final Uint8List ciphertext;

  /// The authentication tag (MAC) (16 bytes for AES-GCM).
  final Uint8List mac;

  /// Total size in bytes (nonce + ciphertext + MAC).
  int get totalLength => nonce.length + ciphertext.length + mac.length;
}

/// Exception for AES-GCM encryption/decryption failures.
class AeadCipherException implements Exception {
  const AeadCipherException(this.message);
  final String message;

  @override
  String toString() => 'AeadCipherException: $message';
}
