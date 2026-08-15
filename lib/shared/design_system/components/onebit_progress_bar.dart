import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';
import 'package:onebit/shared/design_system/colors/onebit_color_schemes.dart';
import 'package:onebit/shared/design_system/spacing/onebit_radius.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Tokenized progress bar for file transfers, downloads, and indeterminate
/// operations.
///
/// [OneBitProgressBar] renders a thin, monospace-styled progress track with
/// optional label, percentage, and speed information. For indeterminate
/// loading states, use [OneBitLoadingIndicator] instead.
///
/// The bar height is intentionally thin (4dp) to match the terminal aesthetic.
class OneBitProgressBar extends StatelessWidget {
  const OneBitProgressBar({
    this.value,
    this.label,
    this.percentage,
    this.speed,
    this.height = 4,
    this.showBackground = true,
    super.key,
  });

  /// Progress value from 0.0 to 1.0; null for indeterminate.
  final double? value;

  /// Optional label text (e.g. "filename.txt").
  final String? label;

  /// Optional percentage text override (e.g. "72%").
  final String? percentage;

  /// Optional speed text (e.g. "1.2 MB/s").
  final String? speed;

  /// Bar height; defaults to 4dp.
  final double height;

  /// Whether to show the background track.
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final colors = context.oneBitColors;
    final scheme = Theme.of(context).colorScheme;
    final effectiveValue = value?.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null || percentage != null || speed != null)
          Padding(
            padding: const EdgeInsets.only(bottom: OneBitSpacing.xs),
            child: Row(
              children: [
                if (label != null)
                  Expanded(
                    child: Text(
                      label!,
                      style: OneBitTypography.technicalStyle(
                        color: colors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (speed != null) ...[
                  const SizedBox(width: OneBitSpacing.s),
                  Text(
                    speed!,
                    style: OneBitTypography.technicalStyle(
                      color: colors.textMuted,
                    ),
                  ),
                ],
                if (percentage != null) ...[
                  const SizedBox(width: OneBitSpacing.s),
                  Text(
                    percentage!,
                    style: OneBitTypography.technicalStyle(
                      color: colors.textPrimary,
                    ).copyWith(fontWeight: OneBitTypography.medium),
                  ),
                ],
              ],
            ),
          ),
        // Track
        Container(
          height: height,
          decoration: BoxDecoration(
            color: showBackground
                ? scheme.surfaceContainerHighest
                : Colors.transparent,
            borderRadius: BorderRadius.circular(OneBitRadius.xs),
          ),
          child: effectiveValue != null
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: effectiveValue,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _progressColor(effectiveValue, colors, scheme),
                        borderRadius: BorderRadius.circular(OneBitRadius.xs),
                      ),
                    ),
                  ),
                )
              : _IndeterminateTrack(height: height, color: colors.info),
        ),
      ],
    );
  }

  Color _progressColor(
    double value,
    OneBitThemeExtension colors,
    ColorScheme scheme,
  ) {
    if (value < 0.3) return colors.warning;
    if (value < 0.9) return colors.info;
    return colors.success;
  }
}

/// Animated indeterminate track segment.
class _IndeterminateTrack extends StatefulWidget {
  const _IndeterminateTrack({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  State<_IndeterminateTrack> createState() => _IndeterminateTrackState();
}

class _IndeterminateTrackState extends State<_IndeterminateTrack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: OneBitMotion.resolve(
        context,
        const Duration(milliseconds: 1500),
      ),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Align(
          alignment: Alignment(-1.0 + _controller.value * 2, 0),
          child: FractionallySizedBox(
            widthFactor: 0.3,
            child: Container(
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(OneBitRadius.xs),
              ),
            ),
          ),
        );
      },
    );
  }
}
