/// Spacing scale for the entire application.
///
/// The scale is 8dp-based; every value is a multiple of 4 so grids remain
/// consistent across densities. Use these instead of literal doubles.
abstract final class OneBitSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double md = 12;
  static const double m = 16;
  static const double l = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double xxxxl = 48;

  /// Standard horizontal page padding.
  static const double page = m;

  /// Standard vertical section separation.
  static const double section = xxl;

  const OneBitSpacing._();
}
