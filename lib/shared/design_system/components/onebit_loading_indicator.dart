import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Standard indeterminate loading state.
class OneBitLoadingIndicator extends StatelessWidget {
  const OneBitLoadingIndicator({super.key, this.label, this.size = 28});

  /// Optional caption under the spinner.
  final String? label;

  /// Diameter of the spinner.
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label ?? 'Loading',
      liveRegion: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: scheme.primary,
                strokeCap: StrokeCap.round,
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: OneBitSpacing.md),
              Text(
                label!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: OneBitTypography.medium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Progress container that fades content in/out per [OneBitMotion].
///
/// The transition collapses to zero duration under reduced-motion settings.
class OneBitAnimatedProgress extends StatelessWidget {
  const OneBitAnimatedProgress({
    required this.inProgress,
    required this.child,
    this.label,
    super.key,
  });

  final bool inProgress;

  final Widget child;

  final String? label;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: context.motionDuration(OneBitMotion.medium),
      switchInCurve: OneBitMotion.emphasized,
      switchOutCurve: OneBitMotion.standard,
      child: inProgress
          ? OneBitLoadingIndicator(key: const ValueKey('loading'), label: label)
          : KeyedSubtree(key: const ValueKey('content'), child: child),
    );
  }
}
