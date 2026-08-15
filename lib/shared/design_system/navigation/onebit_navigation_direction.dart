import 'package:flutter/material.dart';

/// Direction of navigation transition between tabs.
enum NavigationDirection {
  /// New index is greater than old index (moving right in the tab order).
  /// Content slides left, new content enters from right.
  forward,

  /// New index is less than old index (moving left in the tab order).
  /// Content slides right, new content enters from left.
  backward,
}

/// Calculates navigation direction from old and new tab indices.
NavigationDirection navigationDirection(int oldIndex, int newIndex) {
  return newIndex > oldIndex
      ? NavigationDirection.forward
      : NavigationDirection.backward;
}

/// Returns the slide offset for a page transition based on direction.
///
/// For forward navigation: incoming page starts at (1, 0) and exits to (-1, 0).
/// For backward navigation: incoming page starts at (-1, 0) and exits to (1, 0).
Offset slideOffsetForDirection(NavigationDirection direction, {required bool isIncoming}) {
  if (isIncoming) {
    return direction == NavigationDirection.forward
        ? const Offset(1, 0)
        : const Offset(-1, 0);
  }
  return direction == NavigationDirection.forward
      ? const Offset(-1, 0)
      : const Offset(1, 0);
}

/// A page transition that slides content directionally based on tab order.
///
/// Used with [GoRouter] via [CustomTransitionPage] to provide spatial
/// navigation feedback when switching between primary destinations.
class DirectionalSlideTransition extends StatefulWidget {
  const DirectionalSlideTransition({
    required this.child,
    required this.direction,
    this.duration = const Duration(milliseconds: 270),
    this.curve = Curves.easeInOutCubic,
    super.key,
  });

  /// The page content.
  final Widget child;

  /// Navigation direction determining slide direction.
  final NavigationDirection direction;

  /// Animation duration.
  final Duration duration;

  /// Animation curve.
  final Curve curve;

  @override
  State<DirectionalSlideTransition> createState() =>
      _DirectionalSlideTransitionState();
}

class _DirectionalSlideTransitionState extends State<DirectionalSlideTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final beginOffset = slideOffsetForDirection(
      widget.direction,
      isIncoming: true,
    );

    _slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    // Subtle opacity: 0.96 → 1.0
    _fadeAnimation = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _controller.forward();
  }

  @override
  void didUpdateWidget(DirectionalSlideTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.direction != widget.direction) {
      _controller.reset();
      final beginOffset = slideOffsetForDirection(
        widget.direction,
        isIncoming: true,
      );
      _slideAnimation = Tween<Offset>(
        begin: beginOffset,
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ));
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}
