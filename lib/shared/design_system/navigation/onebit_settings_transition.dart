import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';

/// Custom page transition for settings subpages.
///
/// Slides content in from the right with a subtle fade, matching the
/// technical, precise OneBit motion identity. Under reduced motion,
/// falls back to a short cross-fade.
class SettingsSlideTransition extends PageTransitionsBuilder {
  const SettingsSlideTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: child,
      );
    }

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: OneBitMotion.pageCurve,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.15, 0),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.92, end: 1).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}
