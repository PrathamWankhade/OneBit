import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:onebit/features/crypto/aead_cipher.dart';

/// Current encrypted payload protocol version.
const int encryptedPayloadVersion = 1;

/// OneBit-level authenticated encrypted payload.
///
/// Wraps the AES-256-GCM primitive from I5.5 with OneBit-specific
/// versioning and binary serialization for future packet integration.
///
/// ## Wire format (big-endian)
///
/// ```
/// [version: 1 byte]
/// [nonceLen: 1 byte] [nonce: nonceLen bytes]
/// [ciphertextLen: 2 bytes] [ciphertext: ciphertextLen bytes]
/// [mac: 16 bytes]
/// ```
///
/// ## Usage
///
/// ```dart
/// final key = SecretKey(derivedKeyBytes); // from I5.4
/// final payload = await OneBitEncryptedPayload.encrypt(
///   key: key,
///   plaintext: plaintextBytes,
/// );
/// final bytes = payload.serialize();
/// // ... transport ...
/// final parsed = OneBitEncryptedPayload.deserialize(bytes);
/// final plaintext = await OneBitEncryptedPayload.decrypt(
///   key: key,
///   payload: parsed,
/// );
/// ```
class OneBitEncryptedPayload {
  const OneBitEncryptedPayload({
    required this.version,
    required this.nonce,
    required this.ciphertext,
    required this.authenticationTag,
  });

  /// Protocol version.
  final int version;

  /// AES-GCM nonce.
  final Uint8List nonce;

  /// Encrypted data.
  final Uint8List ciphertext;

  /// AES-GCM authentication tag (MAC).
  final Uint8List authenticationTag;

  /// Serialize to bytes.
  ///
  /// Wire format (big-endian):
  /// ```
  /// [version: 1 byte]
  /// [nonceLen: 1 byte] [nonce: nonceLen bytes]
  /// [ciphertextLen: 2 bytes] [ciphertext: ciphertextLen bytes]
  /// [mac: 16 bytes]
  /// ```
  Uint8List serialize() {
    final buffer = BytesBuilder();

    // Version (1 byte)
    buffer.addByte(version);

    // Nonce (1 byte length prefix + nonce bytes)
    buffer.addByte(nonce.length);
    buffer.add(nonce);

    // Ciphertext (2 byte length prefix + ciphertext bytes)
    buffer.addByte((ciphertext.length >> 8) & 0xFF);
    buffer.addByte(ciphertext.length & 0xFF);
    buffer.add(ciphertext);

    // Authentication tag (MAC) — fixed 16 bytes, no length prefix
    buffer.add(authenticationTag);

    return buffer.toBytes();
  }

  /// Deserialize from bytes.
  ///
  /// Throws [PayloadDeserializationException] if the data is malformed.
  factory OneBitEncryptedPayload.deserialize(Uint8List data) {
    if (data.isEmpty) {
      throw const PayloadDeserializationException('Empty payload');
    }

    var offset = 0;

    // Version (1 byte)
    final version = data[offset++];
    if (version != encryptedPayloadVersion) {
      throw PayloadDeserializationException(
        'Unsupported version: $version (expected $encryptedPayloadVersion)',
      );
    }

    // Nonce (1 byte length + bytes)
    if (offset >= data.length) {
      throw const PayloadDeserializationException('Missing nonce length');
    }
    final nonceLen = data[offset++];
    if (offset + nonceLen > data.length) {
      throw const PayloadDeserializationException('Truncated nonce');
    }
    final nonce = Uint8List.fromList(data.sublist(offset, offset + nonceLen));
    offset += nonceLen;

    // Ciphertext (2 byte length + bytes)
    if (offset + 2 > data.length) {
      throw const PayloadDeserializationException('Missing ciphertext length');
    }
    final ciphertextLen = (data[offset] << 8) | data[offset + 1];
    offset += 2;
    if (offset + ciphertextLen > data.length) {
      throw const PayloadDeserializationException('Truncated ciphertext');
    }
    final ciphertext = Uint8List.fromList(
      data.sublist(offset, offset + ciphertextLen),
    );
    offset += ciphertextLen;

    // Authentication tag (MAC) — fixed 16 bytes
    const macLen = 16;
    if (offset + macLen > data.length) {
      throw const PayloadDeserializationException('Missing or truncated MAC');
    }
    final mac = Uint8List.fromList(data.sublist(offset, offset + macLen));
    offset += macLen;

    // Reject unexpected trailing data
    if (offset < data.length) {
      throw const PayloadDeserializationException('Unexpected trailing data');
    }

    // Validate lengths
    if (nonce.isEmpty) {
      throw const PayloadDeserializationException('Empty nonce');
    }
    if (mac.length != 16) {
      throw const PayloadDeserializationException('Invalid MAC length');
    }

    return OneBitEncryptedPayload(
      version: version,
      nonce: nonce,
      ciphertext: ciphertext,
      authenticationTag: mac,
    );
  }

  /// Encrypt plaintext using AES-256-GCM and wrap in OneBit payload.
  ///
  /// [key] is the 256-bit derived session key from I5.4.
  /// [plaintext] is the data to encrypt.
  /// [associatedData] is optional authenticated-but-not-encrypted data.
  static Future<OneBitEncryptedPayload> encrypt({
    required SecretKey key,
    required Uint8List plaintext,
    Uint8List? associatedData,
  }) async {
    final encrypted = await AeadCipher.encrypt(
      key: key,
      plaintext: plaintext,
      associatedData: associatedData,
    );

    return OneBitEncryptedPayload(
      version: encryptedPayloadVersion,
      nonce: encrypted.nonce,
      ciphertext: encrypted.ciphertext,
      authenticationTag: encrypted.mac,
    );
  }

  /// Decrypt OneBit payload using AES-256-GCM.
  ///
  /// [key] is the 256-bit derived session key from I5.4.
  /// [payload] is the [OneBitEncryptedPayload] to decrypt.
  /// [associatedData] must match the AAD used during encryption.
  ///
  /// Returns the decrypted plaintext bytes.
  ///
  /// Throws [AeadCipherException] if decryption or authentication fails.
  static Future<Uint8List> decrypt({
    required SecretKey key,
    required OneBitEncryptedPayload payload,
    Uint8List? associatedData,
  }) async {
    final encrypted = EncryptedPayload(
      nonce: payload.nonce,
      ciphertext: payload.ciphertext,
      mac: payload.authenticationTag,
    );

    return AeadCipher.decrypt(
      key: key,
      encrypted: encrypted,
      associatedData: associatedData,
    );
  }
}

/// Exception for payload deserialization failures.
class PayloadDeserializationException implements Exception {
  const PayloadDeserializationException(this.message);
  final String message;

  @override
  String toString() => 'PayloadDeserializationException: $message';
}
