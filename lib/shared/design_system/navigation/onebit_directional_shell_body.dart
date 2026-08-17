import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';

/// Wraps the [StatefulNavigationShell] body with directional slide transitions.
///
/// When the user switches tabs, the incoming page slides in from the
/// corresponding direction:
/// * Forward navigation (lower index → higher index): incoming slides from
///   the right.
/// * Backward navigation (higher index → lower index): incoming slides from
///   the left.
///
/// Under reduced motion the slide is replaced by a short cross-fade.
///
/// State is preserved because [StatefulShellRoute.indexedStack] manages
/// the branch stacks independently — this widget only handles the visual
/// transition between the visible branches.
class DirectionalShellBody extends StatefulWidget {
  const DirectionalShellBody({required this.navigationShell, super.key});

  /// The stateful navigation shell providing the current branch.
  final StatefulNavigationShell navigationShell;

  @override
  State<DirectionalShellBody> createState() => _DirectionalShellBodyState();
}

class _DirectionalShellBodyState extends State<DirectionalShellBody> {
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.navigationShell.currentIndex;
  }

  @override
  void didUpdateWidget(covariant DirectionalShellBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIdx = oldWidget.navigationShell.currentIndex;
    final newIndex = widget.navigationShell.currentIndex;
    if (newIndex != oldIdx) {
      _previousIndex = oldIdx;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final currentIndex = widget.navigationShell.currentIndex;
    final isForward = currentIndex > _previousIndex;

    if (reduceMotion) {
      return widget.navigationShell;
    }

    return AnimatedSwitcher(
      duration: OneBitMotion.pageSlide,
      switchInCurve: OneBitMotion.pageCurve,
      switchOutCurve: OneBitMotion.accelerate,
      transitionBuilder: (child, animation) {
        final isIncoming = child.key == ValueKey('shell-$currentIndex');
        final slideAnim = Tween<Offset>(
          begin: Offset(
            isIncoming ? (isForward ? 0.4 : -0.4) : (isForward ? -0.15 : 0.15),
            0,
          ),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: OneBitMotion.pageCurve,
        ));
        final fadeAnim = Tween<double>(
          begin: isIncoming ? 0.0 : 1.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: isIncoming
              ? const Interval(0.0, 0.6, curve: Curves.easeOut)
              : const Interval(0.4, 1.0, curve: Curves.easeIn),
        ));
        return SlideTransition(
          position: slideAnim,
          child: FadeTransition(
            opacity: fadeAnim,
            child: child,
          ),
        );
      },
      child: _KeyedShell(
        key: ValueKey('shell-$currentIndex'),
        navigationShell: widget.navigationShell,
      ),
    );
  }
}

/// Wrapper that renders the [StatefulNavigationShell].
///
/// The [Key] changes with the navigation index, causing [AnimatedSwitcher]
/// to treat the old and new instances as different children, which triggers
/// the directional slide transition.
class _KeyedShell extends StatelessWidget {
  const _KeyedShell({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => navigationShell;
}
