import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/features/launch/presentation/display_name_setup_screen.dart';
import 'package:onebit/features/launch/presentation/initializing_screen.dart';
import 'package:onebit/features/launch/presentation/intro_screen.dart';
import 'package:onebit/features/launch/presentation/opening_screen.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../app/support/app_navigation_support.dart';

/// Golden-size viewport.
const kGoldenTestSize = Size(400, 800);

/// Returns GoRouter from a mounted child widget's context.
GoRouter _routerOf(WidgetTester tester) {
  // After settle, IntroScreen is the first screen in the tree.
  final finder = find.byType(IntroScreen);
  if (finder.evaluate().isNotEmpty) {
    return GoRouter.of(tester.element(finder));
  }
  // Fallback: OpeningScreen (before animation completes).
  return GoRouter.of(tester.element(find.byType(OpeningScreen)));
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance = sharedPrefsStore();
  });

  testWidgets('opening screen golden', (tester) async {
    await tester.binding.setSurfaceSize(kGoldenTestSize);
    tester.view.physicalSize = kGoldenTestSize;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(oneBitApp());
    // Single frame: OpeningScreen is still in the tree.
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('launch_screens/opening.png'),
    );
  });

  testWidgets('intro screen golden', (tester) async {
    await tester.binding.setSurfaceSize(kGoldenTestSize);
    tester.view.physicalSize = kGoldenTestSize;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(oneBitApp());
    await tester.pumpAndSettle();
    // After settle, OpeningScreen navigated to IntroScreen.
    expect(find.byType(IntroScreen), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('launch_screens/intro.png'),
    );
  });

  testWidgets('display name screen golden', (tester) async {
    await tester.binding.setSurfaceSize(kGoldenTestSize);
    tester.view.physicalSize = kGoldenTestSize;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(oneBitApp());
    await tester.pumpAndSettle();
    // Navigate from IntroScreen to display name setup.
    _routerOf(tester).go(AppRoutePaths.displayNameSetup);
    await tester.pumpAndSettle();
    expect(find.byType(DisplayNameSetupScreen), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('launch_screens/display_name.png'),
    );
  });

  testWidgets('initializing screen golden', (tester) async {
    await tester.binding.setSurfaceSize(kGoldenTestSize);
    tester.view.physicalSize = kGoldenTestSize;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(oneBitApp());
    await tester.pumpAndSettle();
    _routerOf(tester).go(AppRoutePaths.initializing);
    await tester.pumpAndSettle();
    expect(find.byType(InitializingScreen), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('launch_screens/initializing.png'),
    );
  });
}
