import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Monospace technical block (logs, console output, serialized payloads).
///
/// Renders on a dark mono surface in both identities; content is a raw
/// string with selectable text. No parsing or syntax highlighting.
class OneBitTechnicalCard extends StatelessWidget {
  const OneBitTechnicalCard({
    required this.content,
    this.title,
    this.maxLines,
    super.key,
  });

  /// Raw technical content.
  final String content;

  /// Optional header label.
  final String? title;

  /// Maximum visible lines; content scrolls vertically when exceeded.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.oneBitColors;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.monoBackground,
        borderRadius: BorderRadius.circular(OneBitCardTokens.cornerRadius),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      padding: const EdgeInsets.all(OneBitSpacing.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: OneBitTypography.technicalStyle(
                fontSize: OneBitTypography.caption,
                color: scheme.onSurfaceVariant,
                weight: OneBitTypography.semibold,
              ),
            ),
            const SizedBox(height: OneBitSpacing.s),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: OneBitTypography.technicalStyle(color: scheme.onSurface),
                maxLines: maxLines,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
