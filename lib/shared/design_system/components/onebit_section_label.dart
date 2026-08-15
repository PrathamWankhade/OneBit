import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Consolas-styled section label for grouping settings and content.
///
/// Uses the Consolas monospace font at 13sp with 0.5sp letter spacing
/// and muted color to clearly separate sections from their content.
class OneBitSectionLabel extends StatelessWidget {
  const OneBitSectionLabel({required this.title, this.padding, super.key});

  /// Section label text.
  final String title;

  /// Optional custom padding; defaults to standard section spacing.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding:
          padding ??
          const EdgeInsets.only(
            top: OneBitSpacing.xxl,
            bottom: OneBitSpacing.m,
            left: OneBitSpacing.xs,
            right: OneBitSpacing.xs,
          ),
      child: Text(
        title.toUpperCase(),
        style: OneBitTypography.technicalStyle(color: scheme.onSurfaceVariant)
            .copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}
