/// Numeric formatting helpers that avoid scattering logic in widgets.
extension NumX on num {
  /// Clamps into an inclusive [min]..[max] range.
  num clampTo(num min, num max) => this < min ? min : (this > max ? max : this);

  /// True when the value falls inside an inclusive range.
  bool inRange(num min, num max) => this >= min && this <= max;
}

/// Double-precision conveniences.
extension DoubleX on double {
  /// Rounds to [decimals] decimal places and returns the string.
  String toStringAsDecimals(int decimals) => toStringAsFixed(decimals);
}
