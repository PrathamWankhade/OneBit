import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/features/channels/presentation/channels_screen.dart';
import 'package:onebit/features/identity/presentation/identity_overview_screen.dart';
import 'package:onebit/features/identity/presentation/qr_hub_screen.dart';
import 'package:onebit/features/mesh/presentation/mesh_screen.dart';
import 'package:onebit/features/nearby/presentation/nearby_screen.dart';
import 'package:onebit/features/nodes/presentation/nodes_screen.dart';
import 'package:onebit/shared/design_system/components/onebit_floating_navigation.dart';
import 'package:onebit/shared/design_system/components/onebit_navigation_rail.dart';

import '../../app/support/app_navigation_support.dart';

/// The app's router once the shell is mounted.
GoRouter routerOf(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(AppShell)));

void main() {
  group('system UI', () {
    testWidgets('black system bars are configured via AnnotatedRegion', (
      tester,
    ) async {
      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();

      // At least one AnnotatedRegion<SystemUiOverlayStyle> must exist with
      // the expected black navigation bar color.
      final regions = tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      final hasBlackNavBar = regions.any(
        (r) => r.value.systemNavigationBarColor == Colors.black,
      );
      expect(hasBlackNavBar, isTrue, reason: 'system nav bar should be black');

      final hasTransparentStatus = regions.any(
        (r) => r.value.statusBarColor == Colors.transparent,
      );
      expect(
        hasTransparentStatus,
        isTrue,
        reason: 'status bar should be transparent',
      );

      await disposeApp(tester);
    });
  });

  group('responsive navigation', () {
    testWidgets('compact layout shows bottom navigation bar', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingBottomNavigation), findsOneWidget);
      expect(find.byType(OneBitNavigationRail), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('medium layout shows navigation rail (collapsed)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();

      expect(find.byType(OneBitNavigationRail), findsOneWidget);
      expect(find.byType(FloatingBottomNavigation), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('expanded layout shows navigation rail (extended)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();

      final rail = tester.widget<OneBitNavigationRail>(
        find.byType(OneBitNavigationRail),
      );
      expect(rail.extended, isTrue);

      await disposeApp(tester);
    });

    testWidgets('bottom bar has four destinations', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();

      final bar = tester.widget<FloatingBottomNavigation>(
        find.byType(FloatingBottomNavigation),
      );
      expect(bar.destinations, hasLength(4));
      expect(bar.destinations.map((d) => d.id), [
        'channels',
        'nodes',
        'nearby',
        'mesh',
      ]);

      await disposeApp(tester);
    });

    testWidgets('rail has four destinations', (tester) async {
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();

      final rail = tester.widget<OneBitNavigationRail>(
        find.byType(OneBitNavigationRail),
      );
      expect(rail.destinations, hasLength(4));
      expect(rail.destinations.map((d) => d.id), [
        'channels',
        'nodes',
        'nearby',
        'mesh',
      ]);

      await disposeApp(tester);
    });
  });

  group('selected destination', () {
    testWidgets('Channels is selected by default', (tester) async {
      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();

      expect(find.byType(ChannelsScreen), findsOneWidget);
      expect(find.byType(NodesScreen), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('tapping a tab switches the displayed screen', (tester) async {
      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Nodes'));
      await tester.pumpAndSettle();
      expect(find.byType(NodesScreen), findsOneWidget);
      expect(find.byType(ChannelsScreen), findsNothing);

      await tester.tap(find.byTooltip('Nearby'));
      await tester.pumpAndSettle();
      expect(find.byType(NearbyScreen), findsOneWidget);
      expect(find.byType(NodesScreen), findsNothing);

      await tester.tap(find.byTooltip('Mesh'));
      await tester.pumpAndSettle();
      expect(find.byType(MeshScreen), findsOneWidget);
      expect(find.byType(NearbyScreen), findsNothing);

      await tester.tap(find.byTooltip('Channels'));
      await tester.pumpAndSettle();
      expect(find.byType(ChannelsScreen), findsOneWidget);

      await disposeApp(tester);
    });
  });

  group('deep links for new routes', () {
    testWidgets('/identity reaches IdentityOverviewScreen', (tester) async {
      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();

      routerOf(tester).go(AppRoutePaths.identity);
      await tester.pumpAndSettle();

      expect(find.byType(IdentityOverviewScreen), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('/qr reaches QrHubScreen', (tester) async {
      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();

      routerOf(tester).go(AppRoutePaths.qr);
      await tester.pumpAndSettle();

      expect(find.byType(QrHubScreen), findsOneWidget);

      await disposeApp(tester);
    });
  });

  group('back navigation', () {
    testWidgets('pushing a route and popping returns to the previous screen', (
      tester,
    ) async {
      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();

      final router = routerOf(tester);

      // Navigate to identity
      router.go(AppRoutePaths.identity);
      await tester.pumpAndSettle();
      expect(find.byType(IdentityOverviewScreen), findsOneWidget);

      // Push QR on top
      unawaited(router.push(AppRoutePaths.qr));
      await tester.pumpAndSettle();
      expect(find.byType(QrHubScreen), findsOneWidget);

      // Pop back
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(IdentityOverviewScreen), findsOneWidget);

      await disposeApp(tester);
    });
  });

  group('state restoration', () {
    testWidgets('selected tab is persisted and restored', (tester) async {
      final prefs = sharedPrefsStore();
      await tester.pumpWidget(
        oneBitApp(identity: testIdentity(), prefs: prefs),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChannelsScreen), findsOneWidget);

      // Switch to Mesh
      await tester.tap(find.byTooltip('Mesh'));
      await tester.pumpAndSettle();
      expect(find.byType(MeshScreen), findsOneWidget);

      // "Restart" with the same prefs
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        oneBitApp(identity: testIdentity(), prefs: prefs),
      );
      await tester.pumpAndSettle();

      // Mesh should still be active
      expect(find.byType(MeshScreen), findsOneWidget);
      expect(find.byType(ChannelsScreen), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('default tab is channels when no previous tab is stored', (
      tester,
    ) async {
      await tester.pumpWidget(oneBitApp(identity: testIdentity()));
      await tester.pumpAndSettle();

      expect(find.byType(ChannelsScreen), findsOneWidget);

      await disposeApp(tester);
    });
  });
}
