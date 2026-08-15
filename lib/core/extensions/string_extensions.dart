/// Common string helpers used across the code base.
extension StringX on String {
  /// True when the string is either `null` after trimming. Used with `?.`.
  bool get isBlank => trim().isEmpty;

  /// The reverse of [isBlank].
  bool get isNotBlank => !isBlank;

  /// First letter uppercased, rest unchanged (locale-independent).
  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  /// Null-safe abbreviation for a string that may be empty.
  String? get nullIfEmpty => isEmpty ? null : this;
}

/// Null-safe helpers for optional strings.
extension StringOrNullX on String? {
  /// `value ?? ''` with the receiver kept as a single expression.
  String orEmpty() => this ?? '';
}
