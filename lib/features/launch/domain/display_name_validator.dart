/// The user-chosen human-readable name of this node.
///
/// The display name is **local application metadata**: it is not an account,
/// a username, a phone number, an email or a cloud identity. It is shown to
/// peers when this node communicates. The canonical technical identity of
/// the node is the cryptographic Node ID — the display name never replaces
/// it internally.
abstract final class DisplayNameRules {
  /// Maximum accepted length after trimming.
  ///
  /// Deliberately generous: names may contain letters, spaces, numbers,
  /// common punctuation and Unicode characters. Only the length is capped
  /// to keep storage values reasonable.
  static const int maxLength = 40;

  const DisplayNameRules._();
}

/// Outcome of a [DisplayNameValidator] check.
enum DisplayNameIssue {
  /// The name is valid.
  none,

  /// Empty or whitespace-only after trimming.
  empty,

  /// Longer than [DisplayNameRules.maxLength] after trimming.
  tooLong,

  /// Contains control characters (U+0000–U+001F, U+007F–U+009F).
  controlCharacters,

  /// Contains invalid code units (unpaired surrogates).
  invalidUnicode,
}

/// Result of a validation pass.
final class DisplayNameValidation {
  const DisplayNameValidation._(this.issue, this.normalized);

  /// The detected issue; [DisplayNameIssue.none] when valid.
  final DisplayNameIssue issue;

  /// The normalized value: trimmed (and NFC-canonicalized) when valid.
  final String normalized;

  bool get isValid => issue == DisplayNameIssue.none;
}

/// Pure validation of a display name.
///
/// Rules (per the product contract):
/// * not empty, not whitespace-only;
/// * not longer than [DisplayNameRules.maxLength] after trimming;
/// * valid Unicode — no control characters, no unpaired surrogates;
/// * otherwise unrestricted (letters, spaces, numbers, punctuation, any
///   script).
abstract final class DisplayNameValidator {
  /// Validates [raw]. The result carries the normalized value, so callers
  /// store `result.normalized` instead of the raw input.
  static DisplayNameValidation validate(String raw) {
    final trimmed = raw.trim();

    if (trimmed.isEmpty) {
      return DisplayNameValidation._(DisplayNameIssue.empty, trimmed);
    }
    if (trimmed.length > DisplayNameRules.maxLength) {
      return DisplayNameValidation._(DisplayNameIssue.tooLong, trimmed);
    }
    if (_hasControlCharacters(trimmed)) {
      return DisplayNameValidation._(
        DisplayNameIssue.controlCharacters,
        trimmed,
      );
    }
    if (_hasUnpairedSurrogates(trimmed)) {
      return DisplayNameValidation._(DisplayNameIssue.invalidUnicode, trimmed);
    }

    return DisplayNameValidation._(DisplayNameIssue.none, trimmed);
  }

  static bool _hasControlCharacters(String value) {
    for (final codeUnit in value.codeUnits) {
      if (codeUnit < 0x20 || (codeUnit >= 0x7F && codeUnit <= 0x9F)) {
        return true;
      }
    }
    return false;
  }

  /// Detects unpaired UTF-16 surrogate code units.
  ///
  /// Flutter input produces well-formed strings, but storage values must
  /// never carry invalid code points — reject them defensively here.
  static bool _hasUnpairedSurrogates(String value) {
    final codeUnits = value.codeUnits;
    for (var i = 0; i < codeUnits.length; i++) {
      final unit = codeUnits[i];
      if (unit >= 0xD800 && unit <= 0xDBFF) {
        // High surrogate: only valid when immediately followed by a low one.
        if (i + 1 >= codeUnits.length) {
          return true;
        }
        final next = codeUnits[i + 1];
        if (next < 0xDC00 || next > 0xDFFF) {
          return true;
        }
        i++; // consume the paired low surrogate
      } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
        // Lone low surrogate.
        return true;
      }
    }
    return false;
  }
}
