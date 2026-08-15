import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:onebit/core/crypto/identity/fingerprint.dart';

/// Six-digit out-of-band verification codes (Signal-style safety numbers).
///
/// Both parties derive the **same** code by ordering the two fingerprints
/// canonically (lexicographically) before hashing, so "mine + theirs" and
/// "theirs + mine" produce identical output. The code is
///
/// ```text
/// code = first 6 decimal digits of SHA-256(sorted(ourFP || theirFP || context))
/// ```
///
/// [context] separates flows (e.g. `'onebit/verify-contact'`) so a code
/// derived for one purpose never validates another.
@immutable
final class VerificationCode {
  const VerificationCode._(this.value);

  /// Derives the mutual verification code for two fingerprints.
  static Future<VerificationCode> derive({
    required String ourFingerprintHex,
    required String theirFingerprintHex,
    String context = _defaultContext,
  }) async {
    final ours = ourFingerprintHex.trim().toLowerCase();
    final theirs = theirFingerprintHex.trim().toLowerCase();
    if (!Fingerprint.isValidHex(ours) || !Fingerprint.isValidHex(theirs)) {
      throw ArgumentError('Both inputs must be 64-character hex fingerprints');
    }
    final ordered = [ours, theirs]..sort();
    final material = utf8.encode('${ordered[0]}${ordered[1]}$context');
    final hash = await Sha256().hash(material);
    return VerificationCode._(_digits(hash.bytes));
  }

  static const String _defaultContext = 'onebit/verify-contact/v1';

  /// The six decimal digits, e.g. `482913`.
  final String value;

  /// True when [candidate] is a syntactically valid code.
  static bool isValid(String candidate) =>
      RegExp(r'^\d{6}$').hasMatch(candidate);

  /// Reads digits from [digest] bytes; each byte contributes two decimal
  /// digits, and the first six are kept.
  static String _digits(List<int> digest) {
    final buffer = StringBuffer();
    for (final byte in digest) {
      buffer
        ..write(byte ~/ 10)
        ..write(byte % 10);
      if (buffer.length >= 6) {
        return buffer.toString().substring(0, 6);
      }
    }
    return buffer.toString().padRight(6, '0');
  }

  @override
  String toString() => value;
}
