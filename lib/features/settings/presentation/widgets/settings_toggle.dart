import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';

/// F8 — Toggle settings tile with icon, title, optional description,
/// and a toggle switch.
///
/// Toggle: 51px × 31px, accent when on, bg-muted when off.
class SettingsToggle extends StatelessWidget {
  const SettingsToggle({
    required this.icon,
    required this.title,
    required this.value,
    this.description,
    this.onChanged,
    super.key,
  });

  final IconData icon;
  final String title;
  final bool value;
  final String? description;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          minHeight: description != null ? 72 : 56,
        ),
        child: Row(
          children: [
            // Icon
            Icon(icon, size: 24, color: AppTheme.textSecondary),
            const SizedBox(width: 16),

            // Title + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Toggle switch
            SizedBox(
              width: 51,
              height: 31,
              child: Switch(
                value: value,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
