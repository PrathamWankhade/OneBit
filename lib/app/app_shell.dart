import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/shell_controller.dart';
import 'package:onebit/app/shell_tabs.dart';
import 'package:onebit/core/navigation/app_router_provider.dart';
import 'package:onebit/core/theme/onebit_theme.dart';
import 'package:onebit/core/theme/theme_preference.dart';
import 'package:onebit/core/theme/theme_preference_provider.dart';
import 'package:onebit/features/dtn/dtn_providers.dart';
import 'package:onebit/l10n/app_localizations.dart';
import 'package:onebit/shared/design_system/components/onebit_floating_navigation.dart';
import 'package:onebit/shared/design_system/components/onebit_navigation_rail.dart';
import 'package:onebit/shared/design_system/navigation/onebit_directional_shell_body.dart';
import 'package:onebit/shared/design_system/responsive/onebit_responsive.dart';
import 'package:onebit/shared/localization/locale_controller.dart';

/// Root shell hosting the active tab's navigator.
///
/// Chrome is responsive and derived from the viewport width:
/// * compact (phones) — floating bottom [FloatingBottomNavigation];
/// * medium/expanded (tablets, landscape) — [OneBitNavigationRail].
///
/// Both layouts consume the same [shellTabs] list — navigation logic is
/// never duplicated. Switching tabs preserves every branch's stack and
/// scroll state ([StatefulShellRoute.indexedStack]) and persists the
/// current tab for the next launch.
///
/// Tab switching applies directional slide transitions via
/// [DirectionalShellBody]: forward navigation (left→right) slides content
/// left, backward slides right. Under reduced motion the slide is skipped.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  /// The stateful shell handed over by `StatefulShellRoute`.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final tabs = shellTabs(AppLocalizations.of(context));
    return OneBitResponsiveLayout(
      compact: (context) =>
          _ShellScaffold(navigationShell: navigationShell, tabs: tabs),
      medium: (context) => _RailShell(
        navigationShell: navigationShell,
        tabs: tabs,
        extended: false,
      ),
      expanded: (context) => _RailShell(
        navigationShell: navigationShell,
        tabs: tabs,
        extended: true,
      ),
    );
  }
}

/// Compact layout: floating bottom navigation bar over the branch navigator.
///
/// Uses a [Stack] so page content fills the entire body while the navigation
/// bar floats at the bottom with proper safe-area insets.
final class _ShellScaffold extends ConsumerWidget {
  const _ShellScaffold({required this.navigationShell, required this.tabs});

  final StatefulNavigationShell navigationShell;
  final List<ShellTab> tabs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = navigationShell.currentIndex;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DirectionalShellBody(navigationShell: navigationShell),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingBottomNavigation(
              destinations: [for (final tab in tabs) tab.destination],
              selectedIndex: index,
              onDestinationSelected: (selected) =>
                  _selectBranch(ref, navigationShell, tabs, selected),
            ),
          ),
        ],
      ),
    );
  }
}

/// Medium/expanded layout: navigation rail beside the branch navigator.
final class _RailShell extends ConsumerWidget {
  const _RailShell({
    required this.navigationShell,
    required this.tabs,
    required this.extended,
  });

  final StatefulNavigationShell navigationShell;
  final List<ShellTab> tabs;
  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = navigationShell.currentIndex;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            OneBitNavigationRail(
              destinations: [for (final tab in tabs) tab.destination],
              selectedIndex: index,
              extended: extended,
              onDestinationSelected: (selected) =>
                  _selectBranch(ref, navigationShell, tabs, selected),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: DirectionalShellBody(navigationShell: navigationShell),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared tab-selection logic: switch branch, persist the tab, reset the
/// branch when re-selecting the active tab.
void _selectBranch(
  WidgetRef ref,
  StatefulNavigationShell navigationShell,
  List<ShellTab> tabs,
  int index,
) {
  final currentIndex = navigationShell.currentIndex;
  navigationShell.goBranch(index, initialLocation: index == currentIndex);
  unawaited(persistLastTabPath(tabs[index].path));
}

/// Riverpod root for the whole app tree.
///
/// Everything below `OneBitApp` participates in the same provider container,
/// so controllers, repositories and bridges share state safely.
class OneBitApp extends ConsumerWidget {
  const OneBitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _AppView();
  }
}

final class _AppView extends ConsumerWidget {
  const _AppView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(themePreferenceProvider);
    // Startup touch: restores persisted DTN envelopes and arms the
    // scheduler before the first frame renders.
    ref.watch(dtnEngineProvider);

    final isDark =
        preference == ThemePreference.dark ||
        (preference == ThemePreference.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    final scheme = Theme.of(context).colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: scheme.surface,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: MaterialApp.router(
        routerConfig: ref.watch(goRouterProvider),
        theme: OneBitTheme.light,
        darkTheme: OneBitTheme.dark,
        themeMode: preference.themeMode,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: ref.watch(appLocaleProvider),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
