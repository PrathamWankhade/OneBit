import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';

/// Wraps a child with a fade-in + slide-up entrance animation.
///
/// Use this to give list items, cards and panels a consistent, staggered
/// entrance when they appear on screen. Under reduced-motion settings the
/// animation collapses to zero duration.
///
/// ## Usage
///
/// ```dart
/// OneBitAnimatedEntrance(
///   index: index,
///   child: OneBitCard(child: ...),
/// )
/// ```
class OneBitAnimatedEntrance extends StatefulWidget {
  const OneBitAnimatedEntrance({
    required this.child,
    this.index = 0,
    this.delay = const Duration(milliseconds: 50),
    this.duration,
    super.key,
  });

  /// The widget to animate in.
  final Widget child;

  /// Stagger index (0-based). Each subsequent item delays by [delay].
  final int index;

  /// Additional delay per index step.
  final Duration delay;

  /// Total animation duration. Defaults to [OneBitMotion.medium].
  final Duration? duration;

  @override
  State<OneBitAnimatedEntrance> createState() => _OneBitAnimatedEntranceState();
}

class _OneBitAnimatedEntranceState extends State<OneBitAnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _hasPlayed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? OneBitMotion.medium,
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: OneBitMotion.emphasized,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: OneBitMotion.emphasized,
      ),
    );

    // Stagger the start based on index.
    final staggerDelay = widget.delay * widget.index;
    Future.delayed(staggerDelay, () {
      if (mounted && !_hasPlayed) {
        _hasPlayed = true;
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(covariant OneBitAnimatedEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Do not replay animation on rebuild — only play once.
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
      return widget.child;
    }

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

/// A [ListView] builder that wraps each item with [OneBitAnimatedEntrance].
///
/// Drop-in replacement for `ListView.builder` when staggered entrance
/// animations are desired.
class OneBitAnimatedListView extends StatelessWidget {
  const OneBitAnimatedListView({
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.separatorBuilder,
    this.scrollDirection = Axis.vertical,
    super.key,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry? padding;
  final IndexedWidgetBuilder? separatorBuilder;
  final Axis scrollDirection;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      scrollDirection: scrollDirection,
      itemCount: itemCount,
      separatorBuilder: (context, index) =>
          separatorBuilder?.call(context, index) ?? const SizedBox.shrink(),
      itemBuilder: (context, index) {
        final child = itemBuilder(context, index);
        if (child == null) return const SizedBox.shrink();
        return OneBitAnimatedEntrance(
          index: index,
          child: child,
        );
      },
    );
  }
}
