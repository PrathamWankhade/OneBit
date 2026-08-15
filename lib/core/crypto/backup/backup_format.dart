import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Header metadata bound to a backup's ciphertext (authenticated via AAD).
@immutable
final class BackupAad {
  const BackupAad({required this.nodeId, required this.createdAt});

  /// `NODE-XXXX-XXXX` of the identity that produced the backup.
  final String nodeId;

  /// ISO-8601 timestamp at export time.
  final String createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': nodeId,
    'created': createdAt,
  };

  static BackupAad fromJson(Map<String, Object?> json) => BackupAad(
    nodeId: json['id']! as String,
    createdAt: json['created']! as String,
  );
}

/// Versioned, self-describing encrypted backup document.
///
/// A byte-oriented representation is used on disk/transfer: a fixed magic
/// header, a version byte, then the UTF-8 JSON envelope. The envelope
/// carries the KDF parameters (salt) plus the AES-256-GCM nonce,
/// ciphertext and tag.
@immutable
class BackupEnvelope {
  const BackupEnvelope({
    required this.aad,
    required this.salt,
    required this.nonce,
    required this.cipherText,
    required this.mac,
    this.version = 1,
  });

  /// Header metadata (authenticated against the ciphertext).
  final BackupAad aad;

  /// 16-byte HKDF salt.
  final Uint8List salt;

  /// 12-byte AES-GCM nonce.
  final Uint8List nonce;

  /// Encrypted payload bytes.
  final Uint8List cipherText;

  /// 16-byte AES-GCM authentication tag.
  final Uint8List mac;

  /// Format version (currently `1`).
  final int version;
}

/// Static helpers for the on-disk / on-wire backup representation.
///
/// Supported format:
/// ```text
/// [8-byte magic: "ONEBITBC"][1-byte version][envelope JSON (UTF-8)]
/// ```
/// The whole document is then base64url-encoded for transport/storage.
abstract final class BackupFormat {
  static const String magic = 'ONEBITBC';
  static const int version = 1;

  /// Base64 (URL-safe) full-document encoding of [envelope].
  static String encodeDocument(BackupEnvelope envelope) {
    final body = _encodeBytes(envelope);
    return base64Url.encode(body).replaceAll('=', '');
  }

  /// Raw byte layout of [envelope] (magic + version + JSON body).
  static Uint8List encodeEnvelope(BackupEnvelope envelope) =>
      _encodeBytes(envelope);

  /// Parses raw envelope bytes (see [encodeEnvelope]).
  static BackupEnvelope decodeEnvelope(List<int> body) => _decodeBytes(body);

  /// Decodes a base64url [document] into an envelope.
  ///
  /// Throws [FormatException] on any structural mismatch.
  static BackupEnvelope decodeDocument(String document) {
    final padding = (4 - document.length % 4) % 4;
    final body = Uint8List.fromList(
      base64Url.decode(document.padRight(document.length + padding, '=')),
    );
    return _decodeBytes(body);
  }

  /// Lays out the envelope as raw bytes.
  static Uint8List _encodeBytes(BackupEnvelope envelope) {
    final jsonPart = utf8.encode(_envelopeJson(envelope));
    final out = Uint8List(8 + 1 + jsonPart.length);
    out.setAll(0, utf8.encode(magic));
    out[8] = envelope.version;
    out.setAll(9, jsonPart);
    return out;
  }

  /// Parses raw bytes into an envelope.
  static BackupEnvelope _decodeBytes(List<int> body) {
    if (body.length < 9) {
      throw const FormatException('Backup document is too short');
    }
    final header = ascii.decode(body.sublist(0, 8));
    if (header != magic) {
      throw const FormatException('Not a OneBit backup document');
    }
    final parsedVersion = body[8];
    if (parsedVersion != BackupFormat.version) {
      throw FormatException('Unsupported backup version: $parsedVersion');
    }
    final parsed = jsonDecode(utf8.decode(body.sublist(9)));
    if (parsed is! Map) {
      throw const FormatException('Backup envelope must be an object');
    }
    final fields = parsed.cast<String, Object?>();
    final kdf = fields['kdf'];
    if (kdf is! Map) {
      throw const FormatException('Backup envelope missing kdf');
    }
    final kdfFields = kdf.cast<String, Object?>();
    return BackupEnvelope(
      version: parsedVersion,
      aad: BackupAad.fromJson((fields['aad']! as Map).cast<String, Object?>()),
      salt: _unb64(kdfFields['salt']! as String),
      nonce: _unb64(fields['nonce']! as String),
      cipherText: _unb64(fields['ct']! as String),
      mac: _unb64(fields['mac']! as String),
    );
  }

  static String _envelopeJson(BackupEnvelope envelope) =>
      jsonEncode(<String, Object?>{
        'kdf': <String, Object?>{
          'alg': 'HKDF-SHA256',
          'salt': _b64(envelope.salt),
          'iterations': 1,
        },
        'aad': envelope.aad.toJson(),
        'nonce': _b64(envelope.nonce),
        'ct': _b64(envelope.cipherText),
        'mac': _b64(envelope.mac),
      });

  static String _b64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _unb64(String encoded) {
    final padding = (4 - encoded.length % 4) % 4;
    return Uint8List.fromList(
      base64Url.decode(encoded.padRight(encoded.length + padding, '=')),
    );
  }
}
