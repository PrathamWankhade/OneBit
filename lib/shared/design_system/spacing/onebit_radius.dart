/// Corner-radius scale.
///
/// Radius tokens map to Material 3 default radii where sensible. The scale
/// follows the same naming convention as [OneBitSpacing] for consistency.
///
/// Naming convention:
/// * `xs` (4) — micro rounding (inline badges, small chips)
/// * `sm` (8) — small rounding (buttons, inputs)
/// * `md` (12) — medium rounding (cards, sheets)
/// * `lg` (16) — large rounding (dialogs, modals)
/// * `xl` (24) — extra large rounding (floating surfaces)
/// * `xxl` (28) — floating navigation bar
/// * `xxxl` (32) — large floating surfaces
abstract final class OneBitRadius {
  /// 4dp — micro rounding (inline badges, small chips).
  static const double xs = 4;

  /// 8dp — small rounding (buttons, inputs).
  static const double sm = 8;

  /// 12dp — medium rounding (cards, sheets).
  static const double md = 12;

  /// 16dp — large rounding (dialogs, modals).
  static const double lg = 16;

  /// 24dp — extra large rounding (floating surfaces).
  static const double xl = 24;

  /// 28dp — floating navigation bar.
  static const double xxl = 28;

  /// 32dp — large floating surfaces.
  static const double xxxl = 32;

  /// Fully rounded (chips, pills).
  static const double pill = 999;

  /// Perfect circle (avatars, dots).
  static const double circular = 1000;

  const OneBitRadius._();
}
