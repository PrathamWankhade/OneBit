import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Settings-style row: leading icon, title, optional subtitle and trailing
/// control or action.
///
/// The settings presentation composes these rows directly; the widget owns
/// no preference state.
class OneBitSettingsCard extends StatelessWidget {
  const OneBitSettingsCard({
    required this.title,
    this.icon,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    super.key,
  });

  /// Row title.
  final String title;

  /// Optional leading icon.
  final IconData? icon;

  /// Optional supporting text.
  final String? subtitle;

  /// Optional trailing widget (switch, chevron, badge, …).
  final Widget? trailing;

  /// Tap action; `null` renders the row non-interactive.
  final VoidCallback? onTap;

  /// Disables the row: dims content and blocks taps.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: enabled ? 1.0 : 0.38,
      child: OneBitCard(
        onTap: enabled ? onTap : null,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: OneBitIconSize.s,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: OneBitSpacing.m),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
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
          ],
        ),
      ),
    );
  }
}
