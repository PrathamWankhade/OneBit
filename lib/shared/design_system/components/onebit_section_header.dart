import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Standard section header: overline-style title, optional supporting text
/// and an optional trailing action.
///
/// Uses Consolas monospace font at 13sp with 0.5sp letter spacing for
/// clear section separation.
class OneBitSectionHeader extends StatelessWidget {
  const OneBitSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  /// Header title.
  final String title;

  /// Optional supporting text under the title.
  final String? subtitle;

  /// Optional action widget (usually an icon button) pinned to the right.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OneBitSpacing.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style:
                      OneBitTypography.technicalStyle(
                        color: scheme.onSurfaceVariant,
                      ).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: OneBitSpacing.xs),
                  Text(subtitle!, style: textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: OneBitSpacing.s),
            trailing!,
          ],
        ],
      ),
    );
  }
}
