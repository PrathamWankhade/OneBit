import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_navigation_bar.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

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
    return NavigationRail(
      extended: extended,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      minWidth: 64,
      destinations: [
        for (final destination in destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon, size: OneBitNavigationTokens.iconSize),
            selectedIcon: Icon(
              destination.selectedIcon,
              size: OneBitNavigationTokens.iconSize,
            ),
            label: Text(destination.label),
          ),
      ],
    );
  }
}
