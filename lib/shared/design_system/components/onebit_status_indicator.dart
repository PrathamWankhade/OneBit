import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/accessibility/onebit_accessibility.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';
import 'package:onebit/shared/design_system/colors/onebit_color_schemes.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Semantic status for [OneBitStatusIndicator].
enum OneBitIndicatorStatus {
  /// Positive / connected / verified.
  success,

  /// Warning / pending / degraded.
  warning,

  /// Error / failed / disconnected.
  error,

  /// Informational / discovery.
  info,

  /// Neutral / offline / unknown.
  neutral,
}

/// Compact status indicator: a colored dot or icon with optional label.
///
/// Use [OneBitStatusIndicator] for inline status feedback in list items,
/// navigation destinations, and compact UI where [OneBitStatusChip] would
/// be too wide. The indicator is purely visual — status semantics are
/// carried by the parent widget or explicit [Semantics] wrappers.
///
/// The indicator respects [OneBitAccessibility.minInteractiveSize] when
/// used inside tappable containers.
class OneBitStatusIndicator extends StatelessWidget {
  const OneBitStatusIndicator({
    required this.status,
    this.size = OneBitStatusTokens.dotSize,
    this.label,
    this.showLabel = false,
    this.pulsing = false,
    super.key,
  });

  /// Semantic status that determines the color.
  final OneBitIndicatorStatus status;

  /// Dot diameter; defaults to [OneBitStatusTokens.dotSize].
  final double size;

  /// Optional label text rendered beside the dot.
  final String? label;

  /// Whether to show the label (default false — dot-only mode).
  final bool showLabel;

  /// Whether the dot pulses (e.g. for "connecting" states).
  final bool pulsing;

  Color _color(BuildContext context) {
    final colors = context.oneBitColors;
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      OneBitIndicatorStatus.success => colors.success,
      OneBitIndicatorStatus.warning => colors.warning,
      OneBitIndicatorStatus.error => scheme.error,
      OneBitIndicatorStatus.info => colors.info,
      OneBitIndicatorStatus.neutral => scheme.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);

    final dot = OneBitSemantics.decorative(
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: pulsing ? _PulsingDot(color: color, size: size) : null,
      ),
    );

    if (!showLabel || label == null) {
      return Semantics(
        label: switch (status) {
          OneBitIndicatorStatus.success => 'Connected',
          OneBitIndicatorStatus.warning => 'Warning',
          OneBitIndicatorStatus.error => 'Error',
          OneBitIndicatorStatus.info => 'Information',
          OneBitIndicatorStatus.neutral => 'Unknown',
        },
        child: dot,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        SizedBox(width: size),
        Text(
          label!,
          style: TextStyle(color: color, fontSize: size),
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: OneBitMotion.resolve(
        context,
        const Duration(milliseconds: 1200),
      ),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
