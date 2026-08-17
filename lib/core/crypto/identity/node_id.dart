import 'package:flutter/foundation.dart';

/// A human-readable short identifier for a OneBit node.
///
/// Format: `NODE-XXXX-XXXX` where each group is exactly four uppercase hex
/// characters (`NODE-7A3F-91D2`). The eight hex digits are the leading bytes
/// of the node's [Fingerprint] hash, which gives them collision-resistance
/// for display purposes while the fingerprint remains the authoritative,
/// full-strength identifier.
///
/// The value is always normalized to uppercase; parsing tolerates lowercase
/// and surrounding whitespace but nothing else.
@immutable
final class NodeId {
  const NodeId._(this.value);

  /// Parses and validates [raw] into a [NodeId].
  ///
  /// Throws [FormatException] when [raw] is not a valid node identifier.
  factory NodeId.parse(String raw) {
    final upper = raw.trim().toUpperCase();
    if (!_pattern.hasMatch(upper)) {
      throw FormatException('Invalid node id: "$raw"', raw);
    }
    return NodeId._(upper);
  }

  /// Builds the node id from the first eight hex characters of [fingerprintHex].
  ///
  /// [fingerprintHex] must be a 64-character lowercase hex fingerprint,
  /// exactly as produced by `Fingerprint.hex`.
  factory NodeId.fromFingerprintHex(String fingerprintHex) {
    if (!_hexPattern.hasMatch(fingerprintHex) || fingerprintHex.length != 64) {
      throw FormatException('Invalid fingerprint: "$fingerprintHex"');
    }
    final head = fingerprintHex.substring(0, 8).toUpperCase();
    return NodeId._('$_prefix-${head.substring(0, 4)}-${head.substring(4, 8)}');
  }

  /// True when [raw] is a syntactically valid node id.
  static bool isValid(String raw) {
    return _pattern.hasMatch(raw.trim().toUpperCase());
  }

  static final RegExp _pattern = RegExp('^$_prefix-[0-9A-F]{4}-[0-9A-F]{4}\$');
  static final RegExp _hexPattern = RegExp('^[0-9a-f]+\$');
  static const String _prefix = 'NODE';

  /// The canonical, normalized identifier (e.g. `NODE-7A3F-91D2`).
  final String value;

  /// First hex group, e.g. `7A3F`.
  String get firstGroup => value.substring(5, 9);

  /// Second hex group, e.g. `91D2`.
  String get secondGroup => value.substring(10, 14);

  @override
  bool operator ==(Object other) => other is NodeId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
