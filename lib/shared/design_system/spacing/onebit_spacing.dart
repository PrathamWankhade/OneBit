/// Spacing scale for the entire application.
///
/// The scale follows a 4dp base grid. Every value is a multiple of 4 so
/// grids remain consistent across densities. Use these tokens instead of
/// literal doubles.
///
/// Naming convention:
/// * `xxs` (2) — sub-pixel gaps, decorative separators
/// * `xs` (4) — micro spacing, inline icon gaps
/// * `sm` (8) — small spacing, card internals
/// * `md` (12) — medium spacing, section gaps
/// * `lg` (16) — standard spacing, page padding
/// * `xl` (20) — large spacing, section separation
/// * `xxl` (24) — extra large spacing
/// * `xxxl` (32) — prominent section gaps
/// * `xxxxl` (40) — hero spacing, empty state padding
/// * `xxxxxl` (48) — maximum spacing
/// * `xxxxxxl` (56) — extended spacing
/// * `xxxxxxxl` (64) — page-level hero spacing
abstract final class OneBitSpacing {
  // ─── Canonical names ────────────────────────────────────────────────────

  /// 2dp — sub-pixel gaps, decorative separators.
  static const double xxs = 2;

  /// 4dp — micro spacing, inline icon gaps.
  static const double xs = 4;

  /// 8dp — small spacing, card internals.
  static const double sm = 8;

  /// 12dp — medium spacing, section gaps.
  static const double md = 12;

  /// 16dp — standard spacing, page padding.
  static const double lg = 16;

  /// 20dp — large spacing, section separation.
  static const double xl = 20;

  /// 24dp — extra large spacing.
  static const double xxl = 24;

  /// 32dp — prominent section gaps.
  static const double xxxl = 32;

  /// 40dp — hero spacing, empty state padding.
  static const double xxxxl = 40;

  /// 48dp — maximum spacing.
  static const double xxxxxl = 48;

  /// 56dp — extended spacing.
  static const double xxxxxxl = 56;

  /// 64dp — page-level hero spacing.
  static const double xxxxxxxl = 64;

  // ─── Backward-compatible aliases ────────────────────────────────────────
  //
  // These aliases keep the old naming convention working. New code should
  // use the canonical names above.

  /// @deprecated Use [sm] instead.
  static const double s = sm;

  /// @deprecated Use [lg] instead.
  static const double m = lg;

  /// @deprecated Use [xl] instead.
  static const double l = xl;

  // ─── Semantic aliases ───────────────────────────────────────────────────

  /// Standard horizontal page padding.
  static const double page = lg;

  /// Standard vertical section separation.
  static const double section = xxxl;

  /// Border width for subtle borders.
  static const double borderWidth = 1;

  /// Border width for emphasized borders (focused, error).
  static const double borderWidthStrong = 2;

  const OneBitSpacing._();
}
