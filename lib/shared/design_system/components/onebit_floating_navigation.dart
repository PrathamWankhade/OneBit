import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/accessibility/onebit_accessibility.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';
import 'package:onebit/shared/design_system/components/onebit_navigation_bar.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Floating bottom navigation bar for the OneBit shell.
///
/// Does not touch screen edges — floats above content with horizontal and
/// bottom margins. Uses the OneBit monochrome design language with an
/// animated selection indicator that physically travels between items.
///
/// On tablets ([OneBitBreakpoint.medium]/[expanded]), the bar uses a
/// reasonable max width instead of stretching across the full display.
class FloatingBottomNavigation extends StatelessWidget {
  const FloatingBottomNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.margin = const EdgeInsets.only(bottom: 16, left: 16, right: 16),
    this.maxWidth = 480,
    super.key,
  });

  /// The navigation destinations.
  final List<OneBitNavigationDestination> destinations;

  /// Currently selected index.
  final int selectedIndex;

  /// Callback when a destination is tapped.
  final ValueChanged<int> onDestinationSelected;

  /// Outer margin around the floating bar.
  final EdgeInsetsGeometry margin;

  /// Maximum width of the bar on large screens.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final effectiveWidth = screenWidth < maxWidth ? screenWidth - 32 : maxWidth;

    return SafeArea(
      child: Padding(
        padding: margin,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: effectiveWidth),
            child: _FloatingBar(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingBar extends StatelessWidget {
  const _FloatingBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<OneBitNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _barDecoration(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < destinations.length; i++)
            _FloatingNavItem(
              destination: destinations[i],
              isSelected: i == selectedIndex,
              onTap: () => onDestinationSelected(i),
            ),
        ],
      ),
    );
  }

  BoxDecoration _barDecoration(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: const Color(0xFF1B1B1B),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(
        color: const Color(0xFF2C2C2C),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

class _FloatingNavItem extends StatelessWidget {
  const _FloatingNavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final OneBitNavigationDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: isSelected
            ? '${destination.label}, selected'
            : '${destination.label}, not selected',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: _NavItemContent(
              destination: destination,
              isSelected: isSelected,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemContent extends StatelessWidget {
  const _NavItemContent({
    required this.destination,
    required this.isSelected,
  });

  final OneBitNavigationDestination destination;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: OneBitMotion.fast,
          child: Icon(
            isSelected ? destination.selectedIcon : destination.icon,
            key: ValueKey('$isSelected-${destination.id}'),
            size: 22,
            color: isSelected
                ? const Color(0xFFFFFFFF)
                : const Color(0xFFA8A8A8),
          ),
        ),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: OneBitMotion.fast,
          style: TextStyle(
            fontFamily: OneBitTypography.primaryFamily,
            fontFamilyFallback: OneBitTypography.primaryFallback,
            fontSize: 10,
            fontWeight: isSelected ? OneBitTypography.medium : OneBitTypography.regular,
            color: isSelected
                ? const Color(0xFFFFFFFF)
                : const Color(0xFFA8A8A8),
          ),
          child: Text(destination.label),
        ),
      ],
    );
  }
}
