import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Technical key/value rows (device console, diagnostics surfaces).
///
/// Values render in the technical family; labels in [labelMedium]. Use for
/// read-only inspection rows that benefit from aligned `key : value`.
class OneBitDiagnosticCard extends StatelessWidget {
  const OneBitDiagnosticCard({
    required this.title,
    required this.rows,
    super.key,
  });

  /// Section title.
  final String title;

  /// Ordered key/value pairs rendered as mono rows.
  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return OneBitCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleSmall),
          const SizedBox(height: OneBitSpacing.s),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: OneBitSpacing.s),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  child: Text(
                    rows[i].key,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: OneBitSpacing.m),
                Expanded(
                  child: Text(
                    rows[i].value,
                    style: OneBitTypography.technicalStyle(
                      fontSize: OneBitTypography.technical,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
