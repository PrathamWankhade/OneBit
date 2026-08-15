import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:onebit/core/crypto/backup/backup_format.dart';
import 'package:onebit/core/crypto/identity/exchange_crypto.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/core/utils/secure_random_util.dart';

/// Symmetric protection of a backup document.
///
/// Flow:
/// 1. A random 16-byte [BackupFormat#salt] is generated per export.
/// 2. The AES-256-GCM key is HKDF-SHA256(master: passphrase, salt: salt,
///    info: `onebit/backup/v1`).
/// 3. The plaintext (a JSON map) is authenticated with the header AAD so
///    header fields cannot be swapped between backups.
///
/// The cipher returns `Result` values — a failed authentication surfaces as
/// a [BackupFailure], never a raw platform exception.
abstract final class BackupCipher {
  static const String _info = 'onebit/backup/v1';
  static const int _saltLength = 16;
  static const int _nonceLength = 12;

  /// Encrypts [plaintextJson] (a JSON map) into a full backup envelope.
  static Future<Result<BackupEnvelope>> encrypt({
    required String passphrase,
    required Map<String, Object?> plaintext,
    required BackupAad aad,
  }) async {
    try {
      final salt = SecureRandomUtil.randomBytes(_saltLength);
      final key = await _deriveKey(passphrase, salt);
      final nonce = SecureRandomUtil.randomBytes(_nonceLength);
      final box = await ExchangeCrypto.encrypt(
        key: key,
        clearText: utf8.encode(jsonEncode(plaintext)),
        nonce: nonce,
        aad: utf8.encode(jsonEncode(aad.toJson())),
      );
      return Ok(
        BackupEnvelope(
          aad: aad,
          salt: salt,
          nonce: nonce,
          cipherText: Uint8List.fromList(box.cipherText),
          mac: Uint8List.fromList(box.mac.bytes),
        ),
      );
    } on Object catch (error, stackTrace) {
      return Err(
        BackupFailure(
          operation: 'encrypt',
          message: error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Decrypts [envelope] with [passphrase], returning the plaintext JSON map.
  static Future<Result<Map<String, Object?>>> decrypt({
    required String passphrase,
    required BackupEnvelope envelope,
  }) async {
    try {
      final key = await _deriveKey(passphrase, envelope.salt);
      final aad = utf8.encode(jsonEncode(envelope.aad.toJson()));
      final box = SecretBox(
        envelope.cipherText,
        nonce: envelope.nonce,
        mac: Mac(envelope.mac),
      );
      // Throws SecretBoxAuthenticationError on a wrong passphrase/tamper.
      final cleared = await ExchangeCrypto.decrypt(
        key: key,
        box: box,
        aad: aad,
      );
      final parsed = jsonDecode(utf8.decode(cleared));
      if (parsed is! Map) {
        throw const FormatException('Backup plaintext is not an object');
      }
      return Ok(parsed.cast<String, Object?>());
    } on Object catch (error, stackTrace) {
      return Err(
        BackupFailure(
          operation: 'decrypt',
          message: error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Derives the 32-byte AES key from [passphrase] and [salt].
  static Future<List<int>> _deriveKey(String passphrase, List<int> salt) async {
    return ExchangeCrypto.deriveKey(
      sharedSecret: utf8.encode(passphrase),
      salt: salt,
      info: _info,
    );
  }
}
