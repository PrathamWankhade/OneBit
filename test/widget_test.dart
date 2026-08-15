import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/features/channels/presentation/channels_screen.dart';
import 'package:onebit/features/identity/presentation/onboarding_screen.dart';

import 'app/support/app_navigation_support.dart';

/// Smoke test: the app root mounts and resolves a landing screen.
void main() {
  testWidgets('with an identity the app lands in the shell', (tester) async {
    await tester.pumpWidget(oneBitApp(identity: testIdentity()));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(ChannelsScreen), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('without an identity the app lands on onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(oneBitApp());
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);

    await disposeApp(tester);
  });
}
