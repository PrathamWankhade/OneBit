/// Corner-radius scale.
///
/// Radius tokens map to Material 3 default radii where sensible (small ≙ the
/// M3 12dp rounded corner scheme for medium widgets, pill for chips).
abstract final class OneBitRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  /// Fully rounded (chips, pills).
  static const double pill = 999;

  /// Perfect circle (avatars, dots).
  static const double circular = 1000;

  const OneBitRadius._();
}
