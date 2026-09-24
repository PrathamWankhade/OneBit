import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';

/// F10 — Standard bottom sheet component.
///
/// Handle bar (40×4px), optional title, action items, optional dividers.
/// Max height 80% of screen, scrollable.
///
/// Usage:
/// ```dart
/// showAppBottomSheet(
///   context,
///   title: 'Actions',
///   actions: [
///     SheetAction(icon: Icons.reply, label: 'Reply', onTap: () {}),
///     SheetAction(icon: Icons.copy, label: 'Copy', onTap: () {}),
///   ],
/// );
/// ```

class SheetAction {
  const SheetAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.isDestructive = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;
  final Widget? trailing;
}

Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  String? title,
  required List<SheetAction> actions,
  List<int> dividerIndices = const [],
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AppBottomSheet(
      title: title,
      actions: actions,
      dividerIndices: dividerIndices,
    ),
  );
}

class _AppBottomSheet extends StatelessWidget {
  const _AppBottomSheet({
    this.title,
    required this.actions,
    required this.dividerIndices,
  });

  final String? title;
  final List<SheetAction> actions;
  final List<int> dividerIndices;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.bgMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                title!,
                style: AppTheme.titleLarge.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ),

          // Actions
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final action = actions[index];
                final showDivider = dividerIndices.contains(index);

                return Column(
                  children: [
                    if (showDivider)
                      const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: AppTheme.bgMuted,
                      ),
                    _ActionTile(action: action),
                  ],
                );
              },
            ),
          ),

          // Safe area bottom
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final SheetAction action;

  @override
  Widget build(BuildContext context) {
    final color = action.isDestructive ? AppTheme.red : AppTheme.textPrimary;
    final iconColor =
        action.isDestructive ? AppTheme.red : AppTheme.textSecondary;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        action.onTap?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(action.icon, size: 24, color: iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                action.label,
                style: AppTheme.bodyMedium.copyWith(color: color),
              ),
            ),
            if (action.trailing != null) action.trailing!,
          ],
        ),
      ),
    );
  }
}
