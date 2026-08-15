import 'package:flutter/widgets.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/l10n/app_localizations.dart';
import 'package:onebit/shared/design_system/components/onebit_navigation_bar.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';

/// One primary shell destination (bottom bar / navigation rail item).
///
/// The id is the stable route identifier; the label and icons are
/// presentation-only. The shell chrome (bar and rail) consumes this same
/// list so navigation logic is never duplicated per layout.
@immutable
final class ShellTab {
  const ShellTab({
    required this.id,
    required this.path,
    required this.destination,
  });

  /// Stable identifier (route id, not the visible label).
  final String id;

  /// The location this tab maps to (see [AppRoutePaths]).
  final String path;

  /// Tokenized destination consumed by the bottom bar and the rail.
  final OneBitNavigationDestination destination;
}

/// The primary destinations, in fixed tab order.
///
/// Developer is intentionally absent: it lives behind the developer-mode
/// gate and is reached from Settings, never as a tab.
List<ShellTab> shellTabs(AppLocalizations l10n) => [
  ShellTab(
    id: 'channels',
    path: AppRoutePaths.channels,
    destination: OneBitNavigationDestination(
      id: 'channels',
      label: l10n.appShellChannels,
      icon: OneBitIcons.shellChannels,
      selectedIcon: OneBitIcons.shellChannelsFilled,
    ),
  ),
  ShellTab(
    id: 'nodes',
    path: AppRoutePaths.nodes,
    destination: OneBitNavigationDestination(
      id: 'nodes',
      label: l10n.appShellNodes,
      icon: OneBitIcons.shellNodes,
      selectedIcon: OneBitIcons.shellNodesFilled,
    ),
  ),
  ShellTab(
    id: 'nearby',
    path: AppRoutePaths.nearby,
    destination: OneBitNavigationDestination(
      id: 'nearby',
      label: l10n.appShellNearby,
      icon: OneBitIcons.shellNearby,
      selectedIcon: OneBitIcons.shellNearbyFilled,
    ),
  ),
  ShellTab(
    id: 'mesh',
    path: AppRoutePaths.mesh,
    destination: OneBitNavigationDestination(
      id: 'mesh',
      label: l10n.appShellMesh,
      icon: OneBitIcons.shellMesh, // account_tree_outlined
      selectedIcon: OneBitIcons.shellMeshFilled, // account_tree_rounded
    ),
  ),
];
