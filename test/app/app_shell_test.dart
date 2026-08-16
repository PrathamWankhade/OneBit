import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/app/shell_controller.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/features/channels/presentation/channels_screen.dart';
import 'package:onebit/features/mesh/presentation/mesh_screen.dart';
import 'package:onebit/features/nodes/presentation/nodes_screen.dart';
import 'package:onebit/shared/design_system/components/onebit_floating_navigation.dart';
import 'package:onebit/shared/design_system/components/onebit_navigation_rail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/support/app_navigation_support.dart';

const _labels = ['Channels', 'Nodes', 'Nearby', 'Mesh'];

Future<void> pumpShell(
  WidgetTester tester, {
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(oneBitApp(identity: testIdentity()));
  await tester.pumpAndSettle();
}

/// Ends a shell test with the app unmounted so drift's deferred
/// stream-closing timers are flushed before the pending-timer check.
Future<void> disposeShell(WidgetTester tester) => disposeApp(tester);

void main() {
  group('compact layout (phones)', () {
    testWidgets('shows the bottom navigation bar with all five tabs', (
      tester,
    ) async {
      await pumpShell(tester);

      expect(find.byType(FloatingBottomNavigation), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      for (final label in _labels) {
        expect(find.byTooltip(label), findsOneWidget, reason: label);
      }

      await disposeShell(tester);
    });

    testWidgets('selecting a tab switches the branch', (tester) async {
      await pumpShell(tester);
      expect(find.byType(ChannelsScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Nodes'));
      await tester.pumpAndSettle();

      expect(find.byType(NodesScreen), findsOneWidget);
      expect(find.byType(ChannelsScreen), findsNothing);

      await disposeShell(tester);
    });

    testWidgets('selecting a tab persists the last tab path', (tester) async {
      final prefs = sharedPrefsStore();
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        oneBitApp(identity: testIdentity(), prefs: prefs),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Mesh'));
      await tester.pumpAndSettle();
      expect(find.byType(MeshScreen), findsOneWidget);

      final stored = await SharedPreferencesAsync().getString(
        ShellNavigationKeys.lastTabPath,
      );
      expect(stored, AppRoutePaths.mesh);

      await disposeShell(tester);
    });
  });

  group('medium layout (600-839dp)', () {
    testWidgets('shows a collapsed navigation rail with all five tabs', (
      tester,
    ) async {
      await pumpShell(tester, size: const Size(700, 900));

      expect(find.byType(OneBitNavigationRail), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isFalse,
      );
      for (final label in _labels) {
        expect(find.byTooltip(label), findsOneWidget, reason: label);
      }

      await disposeShell(tester);
    });
  });

  group('expanded layout (>=840dp)', () {
    testWidgets('shows an extended navigation rail', (tester) async {
      await pumpShell(tester, size: const Size(1024, 768));

      expect(find.byType(OneBitNavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isTrue,
      );

      await disposeShell(tester);
    });

    testWidgets('the rail switches branches too', (tester) async {
      await pumpShell(tester, size: const Size(1024, 768));

      await tester.tap(find.text('Mesh'));
      await tester.pumpAndSettle();
      expect(find.byType(MeshScreen), findsOneWidget);
      expect(find.byType(ChannelsScreen), findsNothing);

      await disposeShell(tester);
    });
  });
}
