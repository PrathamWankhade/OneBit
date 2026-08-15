import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/app/developer_mode_controller.dart';
import 'package:onebit/app/shell_controller.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/features/about/presentation/about_screen.dart';
import 'package:onebit/features/about/presentation/licenses_screen.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_dev_screen.dart';
import 'package:onebit/features/channels/presentation/channel_details_screen.dart';
import 'package:onebit/features/channels/presentation/channels_screen.dart';
import 'package:onebit/features/developer/presentation/database_viewer_screen.dart';
import 'package:onebit/features/developer/presentation/developer_screen.dart';
import 'package:onebit/features/developer/presentation/diagnostics_screen.dart';
import 'package:onebit/features/developer/presentation/logs_screen.dart';
import 'package:onebit/features/developer/presentation/performance_screen.dart';
import 'package:onebit/features/developer/presentation/statistics_screen.dart';
import 'package:onebit/features/dtn/presentation/dtn_dev_screen.dart';
import 'package:onebit/features/home/presentation/splash_screen.dart';
import 'package:onebit/features/identity/presentation/identity_controller.dart';
import 'package:onebit/features/identity/presentation/identity_overview_screen.dart';
import 'package:onebit/features/identity/presentation/onboarding_screen.dart';
import 'package:onebit/features/identity/presentation/qr_hub_screen.dart';
import 'package:onebit/features/identity/presentation/qr_identity_screen.dart';
import 'package:onebit/features/identity/presentation/qr_scanner_screen.dart';
import 'package:onebit/features/launch/presentation/display_name_setup_screen.dart';
import 'package:onebit/features/launch/presentation/initializing_screen.dart';
import 'package:onebit/features/launch/presentation/intro_screen.dart';
import 'package:onebit/features/launch/presentation/launch_providers.dart';
import 'package:onebit/features/launch/presentation/opening_screen.dart';
import 'package:onebit/features/media/presentation/media_gallery_screen.dart';
import 'package:onebit/features/media/presentation/transfer_progress_screen.dart';
import 'package:onebit/features/mesh/presentation/mesh_dev_screen.dart';
import 'package:onebit/features/mesh/presentation/mesh_screen.dart';
import 'package:onebit/features/mesh/presentation/route_inspector_screen.dart';
import 'package:onebit/features/messaging/presentation/compose_message_screen.dart';
import 'package:onebit/features/messaging/presentation/search_screen.dart';
import 'package:onebit/features/nearby/presentation/nearby_screen.dart';
import 'package:onebit/features/nodes/presentation/node_details_screen.dart';
import 'package:onebit/features/nodes/presentation/nodes_screen.dart';
import 'package:onebit/features/packet/presentation/packet_dev_screen.dart';
import 'package:onebit/features/settings/presentation/appearance_settings_screen.dart';
import 'package:onebit/features/settings/presentation/bluetooth_settings_screen.dart';
import 'package:onebit/features/settings/presentation/notifications_settings_screen.dart';
import 'package:onebit/features/settings/presentation/privacy_settings_screen.dart';
import 'package:onebit/features/settings/presentation/settings_screen.dart';
import 'package:onebit/features/settings/presentation/storage_settings_screen.dart';
import 'package:onebit/l10n/app_localizations.dart';

/// Declarative router for the whole application.
///
/// Layout:
///
/// ```
/// /splash, /onboarding                (pre-shell flows)
/// /settings …                        (global settings, top-level)
///   ├── /appearance, /privacy, …      (settings sections)
///   ├── /about, /licenses             (about area)
/// /developer …                        (gated developer area)
/// StatefulShellRoute.indexedStack     (AppShell chrome)
///   ├── branch 0  /channels …        (channels tab)
///   ├── branch 1  /nodes …           (nodes tab)
///   ├── branch 2  /nearby            (nearby tab)
///   └── branch 3  /mesh …            (mesh tab)
/// ```
///
/// Guards:
/// * identity gate — without an identity every location resolves to
///   onboarding; with one, splash/onboarding resolve to the restored tab.
/// * developer gate — developer-area paths redirect to settings until
///   developer mode is unlocked (see [developerModeProvider]).
///
/// Deep links (`/channels/:channelId`, …) match parameterized GoRoutes; the
/// identifiers mirror the domain models (see [AppRouteParameters]).
abstract final class AppRouter {
  const AppRouter._();

  /// Creates the router bound to [ref]'s container (used by the provider).
  static GoRouter create(Ref ref) {
    final router = GoRouter(
      initialLocation: AppRoutePaths.launch,
      redirect: (context, state) => _redirect(ref, state),
      routes: [
        GoRoute(
          path: AppRoutePaths.launch,
          builder: (context, state) => const OpeningScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.intro,
          builder: (context, state) => const IntroScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.displayNameSetup,
          builder: (context, state) => const DisplayNameSetupScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.initializing,
          builder: (context, state) => const InitializingScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        // Global settings — top-level route, not a shell branch.
        GoRoute(
          path: AppRoutePaths.settings,
          builder: (context, state) => const SettingsScreen(),
          routes: [
            _simpleRoute(
              AppRoutePaths.settings,
              AppRoutePaths.appearance,
              const AppearanceSettingsScreen(),
            ),
            _simpleRoute(
              AppRoutePaths.settings,
              AppRoutePaths.privacy,
              const PrivacySettingsScreen(),
            ),
            _simpleRoute(
              AppRoutePaths.settings,
              AppRoutePaths.storage,
              const StorageSettingsScreen(),
            ),
            _simpleRoute(
              AppRoutePaths.settings,
              AppRoutePaths.notifications,
              const NotificationsSettingsScreen(),
            ),
            _simpleRoute(
              AppRoutePaths.settings,
              AppRoutePaths.bluetooth,
              const BluetoothSettingsScreen(),
            ),
            _simpleRoute(
              AppRoutePaths.settings,
              AppRoutePaths.about,
              const AboutScreen(),
            ),
            _simpleRoute(
              AppRoutePaths.settings,
              AppRoutePaths.licenses,
              const LicensesScreen(),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutePaths.developer,
          builder: (context, state) => const DeveloperScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.diagnostics,
          builder: (context, state) => const DiagnosticsScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.logs,
          builder: (context, state) => const LogsScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.databaseViewer,
          builder: (context, state) => const DatabaseViewerScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.statistics,
          builder: (context, state) => const StatisticsScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.performance,
          builder: (context, state) => const PerformanceScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.bluetoothDebug,
          builder: (context, state) => const BluetoothDevScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.meshDebug,
          builder: (context, state) => const MeshDevScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.packetDebug,
          builder: (context, state) => const PacketDevScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.dtnDebug,
          builder: (context, state) => const DtnDevScreen(),
        ),
        StatefulShellRoute.indexedStack(
          restorationScopeId: 'onebit-shell',
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: _branches(),
        ),
      ],
      errorBuilder: (context, state) => const _RouterErrorView(),
    );

    // Re-evaluate redirects when gated state changes (identity, developer
    // mode, restored tab, launch flow), so guard transitions happen without
    // user input.
    ref.listen(identityControllerProvider, (_, _) => router.refresh());
    ref.listen(developerModeProvider, (_, _) => router.refresh());
    ref.listen(restoredTabPathProvider, (_, _) => router.refresh());
    ref.listen(launchFlowProvider, (_, _) => router.refresh());
    return router;
  }

  // ---------------------------------------------------------------------
  // Branches
  // ---------------------------------------------------------------------

  static List<StatefulShellBranch> _branches() => [
    StatefulShellBranch(
      restorationScopeId: 'onebit-branch-channels',
      routes: [
        GoRoute(
          path: AppRoutePaths.channels,
          builder: (context, state) => const ChannelsScreen(),
          routes: [
            _paramRoute(
              AppRoutePaths.channels,
              AppRoutePaths.channel,
              (state) => ChannelDetailsScreen(
                channelId: state.pathParameters[AppRouteParameters.channelId]!,
              ),
            ),
            _paramRoute(
              AppRoutePaths.channels,
              AppRoutePaths.message,
              (state) => ChannelDetailsScreen(
                channelId: state.pathParameters[AppRouteParameters.channelId]!,
                messageId: state.pathParameters[AppRouteParameters.messageId],
              ),
            ),
            _paramRoute(
              AppRoutePaths.channels,
              AppRoutePaths.composeMessage,
              (state) => ComposeMessageScreen(
                channelId: state.pathParameters[AppRouteParameters.channelId]!,
                replyToMessageId: state.uri.queryParameters['replyTo'],
                editMessageId: state.uri.queryParameters['edit'],
              ),
            ),
          ],
        ),
        // Flat routes in the branch: /search and the media area are not
        // children of the channels tab route, but share its navigator.
        GoRoute(
          path: AppRoutePaths.search,
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.transfer,
          builder: (context, state) => TransferProgressScreen(
            sessionId: state.pathParameters[AppRouteParameters.sessionId]!,
          ),
        ),
        GoRoute(
          path: AppRoutePaths.mediaGallery,
          builder: (context, state) => const MediaGalleryScreen(),
        ),
      ],
    ),
    StatefulShellBranch(
      restorationScopeId: 'onebit-branch-nodes',
      routes: [
        GoRoute(
          path: AppRoutePaths.nodes,
          builder: (context, state) => const NodesScreen(),
          routes: [
            _paramRoute(
              AppRoutePaths.nodes,
              AppRoutePaths.node,
              (state) => NodeDetailsScreen(
                nodeId: state.pathParameters[AppRouteParameters.nodeId]!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutePaths.identity,
          builder: (context, state) => const IdentityOverviewScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.qr,
          builder: (context, state) => const QrHubScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.qrIdentity,
          builder: (context, state) => const QrIdentityScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.qrScanner,
          builder: (context, state) => const QrScannerScreen(),
        ),
      ],
    ),
    StatefulShellBranch(
      restorationScopeId: 'onebit-branch-nearby',
      routes: [
        GoRoute(
          path: AppRoutePaths.nearby,
          builder: (context, state) => const NearbyScreen(),
        ),
      ],
    ),
    StatefulShellBranch(
      restorationScopeId: 'onebit-branch-mesh',
      routes: [
        GoRoute(
          path: AppRoutePaths.mesh,
          builder: (context, state) => const MeshScreen(),
          routes: [
            _simpleRoute(
              AppRoutePaths.mesh,
              AppRoutePaths.routeInspector,
              const RouteInspectorScreen(),
            ),
          ],
        ),
      ],
    ),
  ];

  /// A child route of [parentPath] whose path is the absolute [path]
  /// constant (converted to a relative child path by go_router).
  static GoRoute _simpleRoute(String parentPath, String path, Widget screen) =>
      GoRoute(
        path: _childPath(parentPath, path),
        builder: (context, state) => screen,
      );

  /// A child route whose screen reads resolved deep-link parameters.
  static GoRoute _paramRoute(
    String parentPath,
    String path,
    Widget Function(GoRouterState state) builder,
  ) => GoRoute(
    path: _childPath(parentPath, path),
    builder: (context, state) => builder(state),
  );

  /// Absolute path -> relative child path under [parentPath].
  static String _childPath(String parentPath, String absolutePath) =>
      absolutePath.substring(parentPath.length);

  // ---------------------------------------------------------------------
  // Guards
  // ---------------------------------------------------------------------

  static String? _redirect(Ref ref, GoRouterState state) {
    final location = state.uri.path;

    final identity = ref.read(identityControllerProvider);
    if (identity.isLoading) {
      // Stay wherever we are (launch on boot) until identity resolves.
      return null;
    }
    final hasIdentity = identity.hasValue && identity.value != null;

    // The launch area handles its own state machine transitions — never
    // redirect away from it while the flow is active.
    if (location == AppRoutePaths.launch ||
        location == AppRoutePaths.intro ||
        location == AppRoutePaths.displayNameSetup ||
        location == AppRoutePaths.initializing) {
      return null;
    }

    if (!hasIdentity) {
      // No identity: everything resolves to the launch flow.
      return AppRoutePaths.launch;
    }

    // Legacy console path resolves to the first tab.
    if (location == AppRoutePaths.home) {
      return AppRoutePaths.channels;
    }

    // Developer gate.
    if (!(ref.read(developerModeProvider).value ?? false) &&
        AppRoutePaths.developerGatedPaths.contains(location)) {
      return AppRoutePaths.settings;
    }

    // Boot landing from legacy splash/onboarding: wait for the restored tab,
    // then leave.
    if (location == AppRoutePaths.splash ||
        location == AppRoutePaths.onboarding) {
      final restored = ref.read(restoredTabPathProvider);
      if (restored.isLoading) {
        return null;
      }
      return restored.value ?? AppRoutePaths.channels;
    }

    return null;
  }
}

/// Fallback page rendered when the router itself fails.
final class _RouterErrorView extends StatelessWidget {
  const _RouterErrorView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(AppLocalizations.of(context).commonError)),
    );
  }
}
