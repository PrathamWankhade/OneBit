import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';

// ── OneBitCard ──────────────────────────────────────────────────────

/// Consistent card container with OneBit terminal styling.
class OneBitCard extends StatelessWidget {
  const OneBitCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: border ?? Border.all(color: AppTheme.borderSubtle, width: 0.5),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

// ── OneBitListTile ──────────────────────────────────────────────────

/// Consistent list tile with OneBit styling.
class OneBitListTile extends StatelessWidget {
  const OneBitListTile({
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.leadingColor,
    this.dense = false,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? leadingColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: leading != null
          ? IconTheme(
              data: IconThemeData(
                color: leadingColor ?? AppTheme.textSecondary,
                size: AppTheme.iconMd,
              ),
              child: leading!,
            )
          : null,
      title: DefaultTextStyle(
        style: AppTheme.bodyMedium.copyWith(color: AppTheme.brightWhite),
        child: title,
      ),
      subtitle: subtitle != null
          ? DefaultTextStyle(
              style: AppTheme.caption,
              child: subtitle!,
            )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 20),
      onTap: onTap,
      dense: dense,
      visualDensity: dense ? VisualDensity.compact : null,
    );
  }
}

// ── OneBitStatusDot ─────────────────────────────────────────────────

/// Small colored dot indicating status.
class OneBitStatusDot extends StatelessWidget {
  const OneBitStatusDot({
    required this.color,
    super.key,
    this.size = 8,
    this.pulse = false,
  });

  final Color color;
  final double size;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: pulse
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

// ── OneBitSectionHeader ─────────────────────────────────────────────

/// Section header for grouped content.
class OneBitSectionHeader extends StatelessWidget {
  const OneBitSectionHeader({
    required this.label,
    super.key,
    this.trailing,
  });

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: AppTheme.labelMedium.copyWith(
              color: AppTheme.textTertiary,
              letterSpacing: 0.1,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ── OneBitIdentityBadge ─────────────────────────────────────────────

/// Compact identity badge showing verification status.
class OneBitIdentityBadge extends StatelessWidget {
  const OneBitIdentityBadge({
    required this.label,
    super.key,
    this.color = AppTheme.green,
    this.icon = Icons.check_circle_outline,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── OneBitEmptyState ────────────────────────────────────────────────

/// Reusable empty state with icon, title, and optional action.
class OneBitEmptyState extends StatelessWidget {
  const OneBitEmptyState({
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.accent),
            const SizedBox(height: AppTheme.space16),
            Text(
              title,
              style: AppTheme.titleMedium.copyWith(color: AppTheme.brightWhite),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.space8),
              Text(
                subtitle!,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTheme.space24),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
