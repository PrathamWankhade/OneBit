import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';

/// F8 — Settings section with header and container.
///
/// Section Header: Label/12px/Medium, text-tertiary.
/// Section Container: bg-surface, radius-lg (12px), gap between sections 24px.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: AppTheme.labelMedium.copyWith(
              color: AppTheme.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // Section container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: AppTheme.bgMuted,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
