import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

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

  /// Fixed width for the leading icon column to ensure label alignment.
  static const double _iconColumnWidth = 32;

  /// Minimum height for the settings tile.
  static const double _minTileHeight = 64;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: enabled ? 1.0 : 0.38,
      child: OneBitCard(
        onTap: enabled ? onTap : null,
        padding: const EdgeInsets.symmetric(
          horizontal: OneBitSpacing.m,
          vertical: OneBitSpacing.sm,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minTileHeight),
          child: Row(
            children: [
              if (icon != null)
                SizedBox(
                  width: _iconColumnWidth,
                  child: Icon(
                    icon,
                    size: OneBitIconSize.s,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                const SizedBox(width: _iconColumnWidth),
              const SizedBox(width: OneBitSpacing.xs),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: OneBitTypography.oneBitCardTitle(
                        color: scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: OneBitTypography.oneBitCaption(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
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
        ),
      ),
    );
  }
}
