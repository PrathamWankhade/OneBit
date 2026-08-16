import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/app/developer_mode_controller.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/features/about/presentation/about_screen.dart';
import 'package:onebit/features/about/presentation/licenses_screen.dart';
import 'package:onebit/shared/design_system/components/onebit_settings_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';

import '../../app/support/app_navigation_support.dart';

void main() {
  Future<void> pumpAbout(
    WidgetTester tester, {
    InMemorySharedPreferencesAsync? prefs,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = prefs ?? sharedPrefsStore();
    await tester.pumpWidget(oneBitApp(identity: testIdentity(), prefs: store));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(AppShell))).go(AppRoutePaths.about);
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);
  }

  /// Unmounts the app so drift's deferred stream-closing timers are flushed
  /// before the pending-timer check.
  Future<void> disposeAbout(WidgetTester tester) => disposeApp(tester);

  testWidgets('shows version and licenses rows', (tester) async {
    await pumpAbout(tester);

    expect(find.text('Version'), findsWidgets);
    expect(find.text('Open-source licenses'), findsOneWidget);

    await disposeAbout(tester);
  });

  testWidgets('seven rapid taps on the version row unlock developer mode', (
    tester,
  ) async {
    final prefs = sharedPrefsStore();
    await pumpAbout(tester, prefs: prefs);

    await withClock(Clock.fixed(DateTime(2026, 1, 1)), () async {
      for (var i = 0; i < DeveloperModeController.versionTapsRequired; i++) {
        await tester.ensureVisible(
          find.widgetWithText(OneBitSettingsCard, 'Version'),
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.widgetWithText(OneBitSettingsCard, 'Version'));
        await tester.pump(const Duration(milliseconds: 50));
      }
    });
    await tester.pumpAndSettle();

    expect(find.text('Developer mode enabled'), findsOneWidget);
    expect(
      await SharedPreferencesAsync().getBool('onebit.navigation.developerMode'),
      isTrue,
    );

    await disposeAbout(tester);
  });

  testWidgets('taps outside the window never complete the sequence', (
    tester,
  ) async {
    final prefs = sharedPrefsStore();
    await pumpAbout(tester, prefs: prefs);

    var now = DateTime(2026, 1, 1);
    final clock = Clock(() => now);
    await withClock(clock, () async {
      for (
        var i = 0;
        i < DeveloperModeController.versionTapsRequired * 2;
        i++
      ) {
        now = now.add(
          DeveloperModeController.versionTapWindow +
              const Duration(milliseconds: 1),
        );
        await tester.ensureVisible(
          find.widgetWithText(OneBitSettingsCard, 'Version'),
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.widgetWithText(OneBitSettingsCard, 'Version'));
        await tester.pump(const Duration(milliseconds: 50));
      }
    });

    expect(find.text('Developer mode enabled'), findsNothing);
    expect(
      await SharedPreferencesAsync().getBool('onebit.navigation.developerMode'),
      isNot(true),
    );

    await disposeAbout(tester);
  });

  testWidgets('licenses row pushes the licenses screen', (tester) async {
    await pumpAbout(tester);

    await tester.tap(find.text('Open-source licenses'));
    await tester.pumpAndSettle();

    expect(find.byType(LicensesScreen), findsOneWidget);
    expect(find.byType(AboutScreen), findsNothing);

    await disposeAbout(tester);
  });
}
