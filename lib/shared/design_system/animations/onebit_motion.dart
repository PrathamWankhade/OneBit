import 'package:flutter/material.dart';

/// Central animation tokens: durations and easing curves.
///
/// Every transition in the app must source its timing from here — no literal
/// `Duration(milliseconds: ...)` scattered in widgets.
///
/// Duration scale:
/// * `fastest` (75ms) — micro interactions (hover, focus)
/// * `fast` (150ms) — quick responses (tap, toggle)
/// * `medium` (250ms) — standard transitions (panel open, card expand)
/// * `slow` (350ms) — deliberate transitions (modal, drawer)
/// * `verySlow` (600ms) — complex choreography (shared axis, container transform)
/// * `pageSlide` (200ms) — tab switching horizontal slide
/// * `settingsSlide` (240ms) — settings subpage slide-from-right
///
/// Curve tokens:
/// * `standard` — default for most in/out animations
/// * `emphasized` — snappier entrance for emphasis
/// * `pageCurve` — restrained curve for page transitions (easeOutCubic)
/// * `decelerate` — elements entering from off-screen
/// * `accelerate` — elements exiting off-screen
/// * `linear` — mechanical motion (indeterminate progress)
abstract final class OneBitMotion {
  // ─── Durations ──────────────────────────────────────────────────────────

  /// 75ms — micro interactions (hover, focus ring).
  static const Duration fastest = Duration(milliseconds: 75);

  /// 150ms — quick responses (tap feedback, toggle, icon swap).
  static const Duration fast = Duration(milliseconds: 150);

  /// 300ms — tab switching horizontal slide.
  static const Duration pageSlide = Duration(milliseconds: 300);

  /// 240ms — settings subpage slide-from-right.
  static const Duration settingsSlide = Duration(milliseconds: 240);

  /// 250ms — standard transitions (panel open, card expand).
  static const Duration medium = Duration(milliseconds: 250);

  /// 350ms — deliberate transitions (modal, drawer, sheet).
  static const Duration slow = Duration(milliseconds: 350);

  /// 600ms — complex choreography (shared axis, container transform).
  static const Duration verySlow = Duration(milliseconds: 600);

  /// Total brand opening animation (~1.4s: fade in, hold, fade out).
  static const Duration opening = Duration(milliseconds: 1400);

  /// The logo fade-in window of the opening animation.
  static const Duration openingFade = Duration(milliseconds: 350);

  // ─── Extended durations (for components that need longer timing) ─────────

  /// 1200ms — status indicator pulse cycle.
  static const Duration pulse = Duration(milliseconds: 1200);

  /// 1500ms — progress bar shimmer cycle.
  static const Duration shimmer = Duration(milliseconds: 1500);

  /// 2000ms — long-running status dot pulse.
  static const Duration statusPulse = Duration(milliseconds: 2000);

  // ─── Snackbar durations ─────────────────────────────────────────────────

  /// Standard snackbar display duration.
  static const Duration snackbar = Duration(seconds: 4);

  /// Extended snackbar display duration (for errors, important messages).
  static const Duration snackbarExtended = Duration(seconds: 6);

  // ─── Curves ─────────────────────────────────────────────────────────────

  /// Default for most in/out animations.
  static const Curve standard = Curves.easeInOutCubic;

  /// Snappier entrance for emphasis.
  static const Curve emphasized = Curves.easeOutCubic;

  /// Restrained curve for page transitions (tab switching, settings).
  static const Curve pageCurve = Curves.easeOutCubic;

  /// Elements entering from off-screen.
  static const Curve decelerate = Curves.easeOut;

  /// Elements exiting off-screen.
  static const Curve accelerate = Curves.easeIn;

  /// Linear for mechanical motion (indeterminate progress).
  static const Curve linear = Curves.linear;

  // ─── Legacy aliases ─────────────────────────────────────────────────────

  /// @deprecated Use [linear] instead.
  static const Curve linearCurve = linear;

  // ─── Helpers ────────────────────────────────────────────────────────────

  /// Resolves [duration] against the platform's reduced-motion setting.
  ///
  /// When the user requests reduced motion the animation collapses to
  /// [Duration.zero]; when animations are allowed the token passes through.
  static Duration resolve(BuildContext context, Duration duration) {
    if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;
    return duration;
  }

  /// Returns a short fade duration for reduced-motion contexts.
  ///
  /// Used as a fallback when slide transitions are disabled but a brief
  /// visual transition is still desirable.
  static Duration reducedMotionFade(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const Duration(milliseconds: 150);
    }
    return Duration.zero;
  }

  const OneBitMotion._();
}

/// Motion helpers mounted on [BuildContext].
extension OneBitMotionContextX on BuildContext {
  /// Whether the platform requests reduced motion.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  /// [OneBitMotion.resolve] as an extension for ergonomic call sites.
  Duration motionDuration(Duration duration) =>
      OneBitMotion.resolve(this, duration);
}
