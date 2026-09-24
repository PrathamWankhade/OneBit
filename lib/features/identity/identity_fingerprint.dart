import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Canonical groups-per-line for the full fingerprint display.
const int _groupSize = 4;
const int _groupsPerLine = 4;

/// Compute a deterministic human-readable fingerprint from public key bytes.
///
/// The fingerprint is the SHA-256 hash of the canonical Ed25519 public key,
/// formatted as uppercase hexadecimal in groups of 4 characters.
///
/// This is a pure function — no database, secure storage, or network access.
/// Works for both local identity and peer identity public keys.
///
/// Throws [ArgumentError] if [publicKeyBytes] is empty.
Future<String> computeFingerprint(Uint8List publicKeyBytes) async {
  if (publicKeyBytes.isEmpty) {
    throw ArgumentError('publicKeyBytes must not be empty');
  }
  final sha256 = Sha256();
  final hash = await sha256.hash(publicKeyBytes);
  return _formatFingerprint(Uint8List.fromList(hash.bytes));
}

/// Format raw hash bytes into a grouped human-readable fingerprint.
///
/// Example output: "AB12 CD34 EF56 7890 1234 5678 ABCD EF01 2345 6789 ABCD EF01 2345 6789 ABCD"
String _formatFingerprint(Uint8List hashBytes) {
  final hex = hashBytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();

  final buffer = StringBuffer();
  for (var i = 0; i < hex.length; i += _groupSize) {
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(hex.substring(i, i + _groupSize));
  }
  return buffer.toString();
}

/// Format a fingerprint for compact display (first 8 groups / 32 hex chars).
///
/// Example: "AB12 CD34 EF56 7890 1234 5678 ABCD EF01"
String fingerprintCompact(String fullFingerprint) {
  final groups = fullFingerprint.split(' ');
  final compact = groups.take(8).join(' ');
  return '$compact …';
}

/// Format a fingerprint as grouped lines (4 groups per line).
///
/// Example:
/// ```
/// AB12 CD34 EF56 7890
/// 1234 5678 ABCD EF01
/// 2345 6789 ABCD EF01
/// 2345 6789 ABCD EF01
/// ```
String fingerprintLines(String fullFingerprint) {
  final groups = fullFingerprint.split(' ');
  final lines = <String>[];
  for (var i = 0; i < groups.length; i += _groupsPerLine) {
    final end = (i + _groupsPerLine).clamp(0, groups.length);
    lines.add(groups.sublist(i, end).join(' '));
  }
  return lines.join('\n');
}

/// Normalize a fingerprint to a canonical form for comparison.
///
/// Strips spaces, hyphens, and converts to uppercase.
/// Returns the raw hex characters only (no separators).
///
/// Example:
/// ```dart
/// normalizeFingerprint('ABCD 1234') == 'ABCD1234'
/// normalizeFingerprint('abcd-1234') == 'ABCD1234'
/// normalizeFingerprint('ABCD1234')  == 'ABCD1234'
/// ```
String normalizeFingerprint(String fingerprint) {
  return fingerprint.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
}

/// Compare two fingerprints for exact match after canonical normalization.
///
/// Both fingerprints are normalized (spaces/hyphens stripped, uppercased)
/// before comparison. This is a strict exact match — no fuzzy matching.
///
/// Returns `true` only if both fingerprints represent the same
/// cryptographic identity after normalization.
///
/// Example:
/// ```dart
/// compareFingerprint('ABCD 1234', 'abcd-1234') == true
/// compareFingerprint('ABCD 1234', 'ABCD 1235') == false
/// ```
bool compareFingerprint(String a, String b) {
  return normalizeFingerprint(a) == normalizeFingerprint(b);
}
