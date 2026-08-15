import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Compact offline banner for lists that remain usable while disconnected.
///
/// Graphical state only — connectivity is never probed here. Callers localize
/// the strings.
class OneBitOfflineBanner extends StatelessWidget {
  const OneBitOfflineBanner({
    required this.title,
    required this.message,
    super.key,
  });

  /// Headline; callers localize.
  final String title;

  /// Supporting text; callers localize.
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
        horizontal: OneBitSpacing.m,
        vertical: OneBitSpacing.s,
      ),
      child: Row(
        children: [
          Icon(OneBitIcons.cloudOff, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: OneBitSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(message, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
