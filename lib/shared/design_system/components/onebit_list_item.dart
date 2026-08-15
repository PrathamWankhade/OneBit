import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Tokenized list row: leading glyph, title, optional subtitle and trailing
/// widget, with a guaranteed ≥48dp target.
///
/// The standard unit for simple lists; richer rows compose cards instead.
class OneBitListItem extends StatelessWidget {
  const OneBitListItem({
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.showChevron = false,
    super.key,
  });

  /// Row title; callers localize.
  final String title;

  /// Optional leading glyph.
  final IconData? leading;

  /// Optional supporting text.
  final String? subtitle;

  /// Optional trailing widget (badge, chip, value text).
  final Widget? trailing;

  /// Tap action; `null` renders the row non-interactive.
  final VoidCallback? onTap;

  /// Disables the row: dims content and blocks taps.
  final bool enabled;

  /// Renders the chevron glyph at the end of the row.
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final label = subtitle != null ? '$title. $subtitle' : title;

    return Semantics(
      button: onTap != null,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.38,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OneBitSpacing.s,
                vertical: OneBitSpacing.s,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    ExcludeSemantics(
                      child: Icon(
                        leading,
                        size: OneBitIconSize.s,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: OneBitSpacing.m),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: textTheme.titleSmall),
                        if (subtitle != null) ...[
                          const SizedBox(height: OneBitSpacing.xs),
                          Text(subtitle!, style: textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: OneBitSpacing.m),
                    trailing!,
                  ],
                  if (showChevron) ...[
                    const SizedBox(width: OneBitSpacing.xs),
                    ExcludeSemantics(
                      child: Icon(
                        OneBitIcons.chevronRight,
                        size: OneBitIconSize.s,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
