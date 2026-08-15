import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/features/developer/presentation/developer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../app/support/app_navigation_support.dart';

/// The developer hub is the developer landing: reachable only with developer
/// mode enabled, at the /developer location.
void main() {
  testWidgets('developer hub renders as the developer landing', (tester) async {
    final prefs = sharedPrefsStore();
    SharedPreferencesAsyncPlatform.instance = prefs;
    await SharedPreferencesAsync().setBool(
      'onebit.navigation.developerMode',
      true,
    );
    await tester.pumpWidget(oneBitApp(identity: testIdentity(), prefs: prefs));
    await tester.pumpAndSettle();

    GoRouter.of(
      tester.element(find.byType(AppShell)),
    ).go(AppRoutePaths.developer);
    await tester.pumpAndSettle();

    expect(find.byType(DeveloperScreen), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('developer hub is gated until developer mode is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(oneBitApp(identity: testIdentity()));
    await tester.pumpAndSettle();

    GoRouter.of(
      tester.element(find.byType(AppShell)),
    ).go(AppRoutePaths.developer);
    await tester.pumpAndSettle();

    expect(find.byType(DeveloperScreen), findsNothing);

    await disposeApp(tester);
  });
}
