import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/navigation/app_router_provider.dart';
import 'package:onebit/features/about/presentation/about_screen.dart';
import 'package:onebit/features/about/presentation/licenses_screen.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_dev_screen.dart';
import 'package:onebit/features/channels/presentation/channel_details_screen.dart';
import 'package:onebit/features/channels/presentation/channels_screen.dart';
import 'package:onebit/features/messaging/presentation/compose_message_screen.dart';
import 'package:onebit/features/developer/presentation/developer_screen.dart';
import 'package:onebit/features/developer/presentation/diagnostics_screen.dart';
import 'package:onebit/features/developer/presentation/logs_screen.dart';
import 'package:onebit/features/dtn/presentation/dtn_dev_screen.dart';
import 'package:onebit/features/identity/presentation/identity_overview_screen.dart';
import 'package:onebit/features/identity/presentation/qr_hub_screen.dart';
import 'package:onebit/features/identity/presentation/qr_identity_screen.dart';
import 'package:onebit/features/identity/presentation/qr_scanner_screen.dart';
import 'package:onebit/features/launch/presentation/intro_screen.dart';
import 'package:onebit/features/launch/presentation/opening_screen.dart';
import 'package:onebit/features/media/presentation/media_gallery_screen.dart';
import 'package:onebit/features/media/presentation/media_providers.dart';
import 'package:onebit/features/media/presentation/transfer_progress_screen.dart';
import 'package:onebit/features/media/transfer/transfer_bitmap.dart';
import 'package:onebit/features/media/transfer/transfer_session.dart';
import 'package:onebit/features/media/transfer/transfer_state.dart';
import 'package:onebit/features/mesh/presentation/mesh_dev_screen.dart';
import 'package:onebit/features/mesh/presentation/mesh_screen.dart';
import 'package:onebit/features/mesh/presentation/route_inspector_screen.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../app/support/app_navigation_support.dart';

/// The app's router once the shell is mounted.
GoRouter routerOf(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(AppShell)));

void main() {
  group('boot flow', () {
    testWidgets('with an identity: opening screen, then the restored tab', (
      tester,
    ) async {
      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      expect(find.byType(OpeningScreen), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(ChannelsScreen), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('without an identity: opening screen instead of the shell', (
      tester,
    ) async {
      await tester.pumpWidget(oneBitApp());
      // OpeningScreen renders for one frame before the animation completes
      // and finishOpening navigates to IntroScreen.
      await tester.pump();
      expect(find.byType(OpeningScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);

      await disposeApp(tester);
    });
  });

  group('route registration', () {
    test('every AppRoutePaths constant is registered in the router tree', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(goRouterProvider);

      final registered = <String>{};
      void visit(RouteBase route) {
        if (route is GoRoute) {
          registered.add(router.configuration.locationForRoute(route)!);
        }
        for (final child in route.routes) {
          visit(child);
        }
      }

      for (final route in router.configuration.routes) {
        visit(route);
      }

      const expected = [
        AppRoutePaths.launch,
        AppRoutePaths.intro,
        AppRoutePaths.displayNameSetup,
        AppRoutePaths.initializing,
        AppRoutePaths.onboarding,
        AppRoutePaths.splash,
        AppRoutePaths.channels,
        AppRoutePaths.channel,
        AppRoutePaths.message,
        AppRoutePaths.composeMessage,
        AppRoutePaths.search,
        AppRoutePaths.transfer,
        AppRoutePaths.mediaGallery,
        AppRoutePaths.nodes,
        AppRoutePaths.node,
        AppRoutePaths.identity,
        AppRoutePaths.qr,
        AppRoutePaths.qrIdentity,
        AppRoutePaths.qrScanner,
        AppRoutePaths.nearby,
        AppRoutePaths.mesh,
        AppRoutePaths.routeInspector,
        AppRoutePaths.settings,
        AppRoutePaths.appearance,
        AppRoutePaths.privacy,
        AppRoutePaths.storage,
        AppRoutePaths.notifications,
        AppRoutePaths.bluetooth,
        AppRoutePaths.developer,
        AppRoutePaths.diagnostics,
        AppRoutePaths.logs,
        AppRoutePaths.about,
        AppRoutePaths.licenses,
        AppRoutePaths.bluetoothDebug,
        AppRoutePaths.meshDebug,
        AppRoutePaths.packetDebug,
        AppRoutePaths.dtnDebug,
        // '/' is deliberately a redirect, not a registered route.
      ];
      expect(registered, containsAll(expected));
    });

    testWidgets('every registered route navigates to its screen', (
      tester,
    ) async {
      final prefs = sharedPrefsStore();
      SharedPreferencesAsyncPlatform.instance = prefs;
      await SharedPreferencesAsync().setBool(
        'onebit.navigation.developerMode',
        true,
      );
      await tester.pumpWidget(
        oneBitApp(identity: testIdentity(), prefs: prefs),
      );
      await tester.pumpAndSettle();

      const routes = <String, Type>{
        AppRoutePaths.channels: ChannelsScreen,
        '/channels/chan-1': ChannelDetailsScreen,
        '/channels/chan-1/message/msg-2': ChannelDetailsScreen,
        '/channels/chan-1/compose': ComposeMessageScreen,
        AppRoutePaths.search: SearchScreen,
        '/transfers/sess-3': TransferProgressScreen,
        AppRoutePaths.mediaGallery: MediaGalleryScreen,
        AppRoutePaths.nodes: NodesScreen,
        '/nodes/node-4': NodeDetailsScreen,
        AppRoutePaths.identity: IdentityOverviewScreen,
        AppRoutePaths.qr: QrHubScreen,
        AppRoutePaths.qrIdentity: QrIdentityScreen,
        AppRoutePaths.qrScanner: QrScannerScreen,
        AppRoutePaths.nearby: NearbyScreen,
        AppRoutePaths.mesh: MeshScreen,
        AppRoutePaths.routeInspector: RouteInspectorScreen,
        AppRoutePaths.settings: SettingsScreen,
        AppRoutePaths.appearance: AppearanceSettingsScreen,
        AppRoutePaths.privacy: PrivacySettingsScreen,
        AppRoutePaths.storage: StorageSettingsScreen,
        AppRoutePaths.notifications: NotificationsSettingsScreen,
        AppRoutePaths.bluetooth: BluetoothSettingsScreen,
        AppRoutePaths.developer: DeveloperScreen,
        AppRoutePaths.diagnostics: DiagnosticsScreen,
        AppRoutePaths.logs: LogsScreen,
        AppRoutePaths.about: AboutScreen,
        AppRoutePaths.licenses: LicensesScreen,
        AppRoutePaths.bluetoothDebug: BluetoothDevScreen,
        AppRoutePaths.meshDebug: MeshDevScreen,
        AppRoutePaths.packetDebug: PacketDevScreen,
        AppRoutePaths.dtnDebug: DtnDevScreen,
      };

      final router = routerOf(tester);
      for (final entry in routes.entries) {
        router.go(entry.key);
        // ignore: avoid_print
        print('DEBUG navigating to ${entry.key}');
        await tester.pumpAndSettle();
        expect(
          find.byType(entry.value),
          findsOneWidget,
          reason: '${entry.key} should render ${entry.value}',
        );
      }

      await disposeApp(tester);
    });
  });

  group('deep links', () {
    testWidgets('channel id reaches the details screen', (tester) async {
      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();

      routerOf(tester).go(AppRoutePaths.channelOf('chan-42'));
      await tester.pumpAndSettle();

      expect(find.byType(ChannelDetailsScreen), findsOneWidget);
      expect(find.textContaining('chan-42'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('message anchor is resolved too', (tester) async {
      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();

      routerOf(tester).go(AppRoutePaths.messageOf('chan-42', 'msg-9'));
      await tester.pumpAndSettle();

      expect(find.byType(ChannelDetailsScreen), findsOneWidget);
      expect(find.textContaining('chan-42'), findsOneWidget);
      expect(find.textContaining('msg-9'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('node id reaches the details screen', (tester) async {
      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();

      routerOf(tester).go(AppRoutePaths.nodeOf('node-7'));
      await tester.pumpAndSettle();

      expect(find.byType(NodeDetailsScreen), findsOneWidget);
      expect(find.textContaining('node-7'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('transfer session id reaches the progress screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OneBitApp)),
      );
      await container
          .read(sqliteTransferRepositoryProvider)
          .createSession(
            TransferSession(
              sessionId: 'session-1',
              attachmentId: 'att-1',
              peerNodeId: 'peer-9',
              direction: TransferDirection.send,
              state: TransferState.queued,
              chunkSize: 512,
              totalChunks: 4,
              chunksBitmap: TransferBitmap.empty(4),
              bytesTransferred: 0,
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await tester.pumpAndSettle();

      routerOf(tester).go(AppRoutePaths.transferOf('session-1'));
      await tester.pumpAndSettle();

      expect(find.byType(TransferProgressScreen), findsOneWidget);
      expect(find.textContaining('session-1'), findsOneWidget);

      await disposeApp(tester);
    });
  });
  group('nested navigation', () {
    testWidgets('push and back through the channels stack', (tester) async {
      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();
      final router = routerOf(tester);

      router.go(AppRoutePaths.channels);
      await tester.pumpAndSettle();
      expect(find.byType(ChannelsScreen), findsOneWidget);

      unawaited(router.push(AppRoutePaths.channelOf('chan-1')));
      await tester.pumpAndSettle();
      expect(find.byType(ChannelDetailsScreen), findsOneWidget);
      expect(find.byType(ChannelsScreen), findsNothing);

      unawaited(router.push(AppRoutePaths.composeOf('chan-1')));
      await tester.pumpAndSettle();
      expect(find.byType(ComposeMessageScreen), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ChannelDetailsScreen), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ChannelsScreen), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('settings sections sit above settings and pop back', (
      tester,
    ) async {
      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();
      final router = routerOf(tester);

      router.go(AppRoutePaths.settings);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      unawaited(router.push(AppRoutePaths.about));
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      await disposeApp(tester);
    });
  });
  group('guards', () {
    testWidgets(
      'without an identity every location resolves to the opening screen',
      (tester) async {
        await tester.pumpWidget(oneBitApp());
        // Pump once so OpeningScreen is mounted.
        await tester.pump();

        final router = GoRouter.of(tester.element(find.byType(OpeningScreen)));
        for (final path in [
          AppRoutePaths.channels,
          AppRoutePaths.nodes,
          AppRoutePaths.nearby,
          AppRoutePaths.mesh,
          AppRoutePaths.settings,
          AppRoutePaths.developer,
          AppRoutePaths.about,
        ]) {
          router.go(path);
          await tester.pumpAndSettle();
          // Without identity, all non-launch routes redirect to /launch,
          // then OpeningScreen navigates to IntroScreen.
          expect(find.byType(IntroScreen), findsOneWidget, reason: path);
        }

        await disposeApp(tester);
      },
    );

    testWidgets('developer area redirects to settings until unlocked', (
      tester,
    ) async {
      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();
      final router = routerOf(tester);

      for (final path in AppRoutePaths.developerGatedPaths) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget, reason: path);
      }

      // The about area is not gated.
      router.go(AppRoutePaths.about);
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('developer area is reachable when developer mode is on', (
      tester,
    ) async {
      final prefs = sharedPrefsStore();
      SharedPreferencesAsyncPlatform.instance = prefs;
      await SharedPreferencesAsync().setBool(
        'onebit.navigation.developerMode',
        true,
      );
      await tester.pumpWidget(
        oneBitApp(identity: testIdentity(), prefs: prefs),
      );
      await tester.pumpAndSettle();

      routerOf(tester).go(AppRoutePaths.developer);
      await tester.pumpAndSettle();
      expect(find.byType(DeveloperScreen), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('legacy home location resolves to the first tab', (
      tester,
    ) async {
      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();

      routerOf(tester).go(AppRoutePaths.home);
      await tester.pumpAndSettle();
      expect(find.byType(ChannelsScreen), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('unknown locations render the router error view', (
      tester,
    ) async {
      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();

      routerOf(tester).go('/does-not-exist');
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong'), findsOneWidget);

      await disposeApp(tester);
    });
  });

  group('tab restoration', () {
    testWidgets('the last active tab is restored across restarts', (
      tester,
    ) async {
      final prefs = sharedPrefsStore();
      await tester.pumpWidget(
        oneBitApp(identity: testIdentity(), prefs: prefs),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChannelsScreen), findsOneWidget);

      await tester.tap(find.text('Nodes'));
      await tester.pumpAndSettle();
      expect(find.byType(NodesScreen), findsOneWidget);
      expect(find.byType(ChannelsScreen), findsNothing);

      // Restart with the same prefs store.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        oneBitApp(identity: testIdentity(), prefs: prefs),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NodesScreen), findsOneWidget);
      expect(find.byType(ChannelsScreen), findsNothing);

      await disposeApp(tester);
    });
  });
}
