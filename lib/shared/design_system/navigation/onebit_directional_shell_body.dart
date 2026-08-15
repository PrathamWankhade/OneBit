import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';
import 'package:onebit/shared/design_system/navigation/onebit_navigation_direction.dart';

/// Wraps the [StatefulNavigationShell] body with directional slide transitions.
///
/// When the user switches tabs, the outgoing page slides out and the incoming
/// page slides in from the appropriate direction based on tab order. State
/// is preserved because [StatefulShellRoute.indexedStack] manages the branch
/// stacks independently.
///
/// Under reduced motion, a subtle cross-fade replaces the slide.
class DirectionalShellBody extends StatefulWidget {
  const DirectionalShellBody({
    required this.navigationShell,
    required this.child,
    super.key,
  });

  /// The stateful navigation shell providing the current branch.
  final Widget navigationShell;

  /// The child widget (typically the navigation shell itself).
  final Widget child;

  @override
  State<DirectionalShellBody> createState() => _DirectionalShellBodyState();
}

class _DirectionalShellBodyState extends State<DirectionalShellBody>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  int _previousIndex = 0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: OneBitMotion.medium,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onIndexChanged(int newIndex) {
    if (newIndex == _previousIndex || _isAnimating) return;

    final direction = navigationDirection(_previousIndex, newIndex);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    _previousIndex = newIndex;

    if (reduceMotion) {
      // Under reduced motion, just skip animation.
      return;
    }

    _isAnimating = true;

    final beginOffset = slideOffsetForDirection(direction, isIncoming: true);

    _slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    _controller.forward(from: 0).then((_) {
      _isAnimating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex =
        (widget.navigationShell as dynamic).currentIndex as int? ?? 0;

    // Trigger animation when index changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onIndexChanged(currentIndex);
    });

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
