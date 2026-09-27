import 'package:flutter/material.dart';

/// App-wide motion tokens.
///
/// Deliberately subtle and quick: 160–320ms, small offsets, and fades
/// rather than long slides. Anything that pushes a *route* is animated in
/// `app/router.dart`; these tokens cover content appearing inside a screen.
const Duration kMotionFast = Duration(milliseconds: 160);
const Duration kMotionBase = Duration(milliseconds: 240);
const Duration kMotionSlow = Duration(milliseconds: 320);

const Curve kMotionEnter = Curves.easeOutCubic;
const Curve kMotionExit = Curves.easeInCubic;

/// Fades content up into place the first time it is built.
///
/// Wrap a tile, header or card once and every screen that shows it gets a
/// consistent entrance. The offset is in logical pixels — small on purpose,
/// so nothing ever travels far enough to move out from under a tap.
///
/// Honors [MediaQuery.disableAnimations], so screens with reduced motion
/// requested (and widget tests that ask for it) render instantly.
class MotionEnter extends StatelessWidget {
  const MotionEnter({
    super.key,
    required this.child,
    this.offset = const Offset(0, 8),
    this.duration = kMotionBase,
  });

  /// The content to animate in.
  final Widget child;

  /// Distance travelled while entering, in logical pixels.
  final Offset offset;

  /// How long the entrance takes.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: kMotionEnter,
      builder: (context, value, child) {
        // value climbs 0 -> 1; travel and transparency do the opposite.
        final remaining = 1 - value;
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: offset * remaining, child: child),
        );
      },
      child: child,
    );
  }
}

/// Cross-fades between two children while sliding the incoming one in.
///
/// Used where a label swaps in place — the app bar title of the QR pager,
/// for example — so the change reads as a transition instead of a cut.
class MotionCrossFade extends StatelessWidget {
  const MotionCrossFade({
    super.key,
    required this.child,
    this.offset = const Offset(0.1, 0),
    this.duration = kMotionFast,
  });

  final Widget child;
  final Offset offset;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: kMotionEnter,
      switchOutCurve: kMotionExit,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: offset, end: Offset.zero)
                .animate(animation),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
