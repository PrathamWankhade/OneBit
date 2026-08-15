import 'package:flutter/material.dart';

/// Central animation tokens: durations and easing curves.
///
/// Every transition in the app must source its timing from here — no literal
/// `Duration(milliseconds: ...)` scattered in widgets. Screen-specific
/// choreography (shared axis, container transform, hero) builds on these
/// tokens in the motion phase; none of it is hardcoded outside this file.
abstract final class OneBitMotion {
  // Durations (ms). The normal animation window is 150–250ms.
  static const Duration fastest = Duration(milliseconds: 75);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration verySlow = Duration(milliseconds: 600);

  /// Total brand opening animation (~1.4s: fade in, hold, fade out).
  static const Duration opening = Duration(milliseconds: 1400);

  /// The logo fade-in window of the opening animation.
  static const Duration openingFade = Duration(milliseconds: 350);

  // Curves
  /// Default for most in/out animations.
  static const Curve standard = Curves.easeInOutCubic;

  /// Snappier entrance for emphasis.
  static const Curve emphasized = Curves.easeOutCubic;

  /// Linear for mechanical motion (indeterminate progress).
  static const Curve linearCurve = Curves.linear;

  /// Resolves [duration] against the platform's reduced-motion setting.
  ///
  /// When the user requests reduced motion the animation collapses to
  /// [Duration.zero]; when animations are allowed the token passes through.
  /// Every widget that animates should route its durations through this.
  static Duration resolve(BuildContext context, Duration duration) {
    if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;
    return duration;
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
