import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';

/// Wraps the [StatefulNavigationShell] body with directional slide transitions.
///
/// When the user switches tabs, content slides horizontally toward the
/// selected destination:
/// * Forward navigation (lower index → higher index): content slides left.
/// * Backward navigation (higher index → lower index): content slides right.
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

class _DirectionalShellBodyState extends State<DirectionalShellBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  bool _isForward = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: OneBitMotion.pageSlide,
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: OneBitMotion.pageCurve,
    );
    _fadeAnimation = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: OneBitMotion.pageCurve,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant DirectionalShellBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIndex = widget.navigationShell.currentIndex;
    final oldIdx = oldWidget.navigationShell.currentIndex;
    if (newIndex != oldIdx) {
      _isForward = newIndex > oldIdx;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: widget.navigationShell,
      );
    }

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        final offset = _isForward
            ? Offset(1.0 - _slideAnimation.value, 0)
            : Offset(-1.0 + _slideAnimation.value, 0);
        return FractionalTranslation(
          translation: offset,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: widget.navigationShell,
          ),
        );
      },
    );
  }
}
