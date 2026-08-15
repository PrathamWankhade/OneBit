import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// An immutable destination of the bottom [OneBitNavigationBar].
@immutable
final class OneBitNavigationDestination {
  const OneBitNavigationDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  /// Stable route identifier, not the visible label.
  final String id;

  /// Visible label below the icon.
  final String label;

  /// Unselected icon.
  final IconData icon;

  /// Selected icon (usually filled variant).
  final IconData selectedIcon;
}

/// Tokenized Material bottom navigation bar.
///
/// The shell renders exactly one of these with
/// [OneBitNavigationDestination]s; the selection index is owned by the shell
/// controller, not this widget.
class OneBitNavigationBar extends StatelessWidget {
  const OneBitNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final List<OneBitNavigationDestination> destinations;

  final int selectedIndex;

  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      height: OneBitNavigationTokens.barHeight,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: Icon(destination.icon, size: OneBitNavigationTokens.iconSize),
            selectedIcon: Icon(
              destination.selectedIcon,
              size: OneBitNavigationTokens.iconSize,
            ),
            label: destination.label,
          ),
      ],
    );
  }
}
