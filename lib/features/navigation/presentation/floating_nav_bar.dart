import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';

/// Floating bottom navigation bar with frosted glass effect and
/// animated sliding indicator.
///
/// Features 4 tab items with badges and smooth sliding pill indicator.
class FloatingNavBar extends StatefulWidget {
  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items = const [],
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavBarItem> items;

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppTheme.bgSurface,
        border: Border(
          top: BorderSide(color: AppTheme.divider, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < widget.items.length; i++)
            _buildTab(context, i),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, int index) {
    if (index >= widget.items.length) return const SizedBox(width: 64);
    final item = widget.items[index];
    final isSelected = widget.currentIndex == index;

    const selectedColor = AppTheme.accent;
    const unselectedColor = AppTheme.textSecondary;

    return GestureDetector(
      onTap: () => widget.onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? item.activeIcon ?? item.icon : item.icon,
              size: 24,
              color: isSelected ? selectedColor : unselectedColor,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: AppTheme.caption.copyWith(
                color: isSelected ? selectedColor : unselectedColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single tab item in the floating nav bar.
class NavBarItem {
  const NavBarItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.badge,
    this.badgeColor,
    this.showDot,
    this.dotColor,
  });

  final IconData icon;
  final String label;

  /// Icon shown when this tab is selected (filled variant).
  final IconData? activeIcon;

  /// Badge text (e.g., unread count). Null = no badge.
  final String? badge;

  /// Badge background color. Defaults to accent.
  final Color? badgeColor;

  /// Whether to show a small status dot instead of a badge.
  final bool? showDot;

  /// Dot color. Defaults to green.
  final Color? dotColor;
}
