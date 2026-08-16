import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_navigation_bar.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Tokenized Material navigation rail (tablet / landscape shell chrome).
///
/// The rail mirrors [OneBitNavigationBar]: it consumes the same
/// [OneBitNavigationDestination] list so the shell never duplicates
/// navigation logic across layouts. Selection is owned by the shell
/// controller, not this widget.
class OneBitNavigationRail extends StatelessWidget {
  const OneBitNavigationRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.extended = false,
    super.key,
  });

  /// Destinations shared with the bottom bar.
  final List<OneBitNavigationDestination> destinations;

  final int selectedIndex;

  final ValueChanged<int> onDestinationSelected;

  /// When true the rail shows labels next to the icons (wide layouts).
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<OneBitThemeExtension>()!;

    return NavigationRail(
      extended: extended,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      minWidth: 64,
      indicatorColor: colors.selectedBackground,
      selectedIconTheme: IconThemeData(
        color: colors.selectedIcon,
        size: OneBitNavigationTokens.iconSize,
      ),
      unselectedIconTheme: IconThemeData(
        color: colors.iconSecondary,
        size: OneBitNavigationTokens.iconSize,
      ),
      selectedLabelTextStyle: TextStyle(
        fontFamily: OneBitTypography.primaryFamily,
        fontFamilyFallback: OneBitTypography.primaryFallback,
        fontSize: OneBitNavigationTokens.labelFontSize,
        fontWeight: OneBitTypography.medium,
        color: colors.selectedForeground,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: OneBitTypography.primaryFamily,
        fontFamilyFallback: OneBitTypography.primaryFallback,
        fontSize: OneBitNavigationTokens.labelFontSize,
        fontWeight: OneBitTypography.regular,
        color: colors.textSecondary,
      ),
      destinations: [
        for (final destination in destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
      ],
    );
  }
}
