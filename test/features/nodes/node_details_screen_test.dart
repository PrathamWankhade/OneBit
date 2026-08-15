import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/features/channels/presentation/channel_details_screen.dart';
import 'package:onebit/features/identity/domain/trust_level.dart';
import 'package:onebit/features/nodes/presentation/node_details_screen.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

import '../../app/support/app_navigation_support.dart';
import '../../app/support/screen_test_support.dart';

/// The node details screen: identity material, verification, connection
/// data and the actions delegated to existing use cases.
void main() {
  Future<void> pumpNode(
    WidgetTester tester,
    ProviderContainer container,
    String nodeId,
  ) async {
    GoRouter.of(
      tester.element(find.byType(AppShell)),
    ).go(AppRoutePaths.nodeOf(nodeId));
    await tester.pumpAndSettle();
  }

  testWidgets('an unknown node reports not found', (tester) async {
    final container = await pumpShell(tester);

    await pumpNode(tester, container, 'ghost-node');

    expect(find.byType(NodeDetailsScreen), findsOneWidget);
    expect(find.text('Node not found'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('a known contact renders identity, verification and connection', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    await seedContact(
      container,
      nodeId: 'node-abc',
      displayName: 'Alice',
      trustLevel: TrustLevel.verified,
    );
    await tester.pumpAndSettle();

    await pumpNode(tester, container, 'node-abc');

    // Identity.
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Node ID'), findsOneWidget);
    expect(find.text('node-abc'), findsOneWidget);
    expect(find.text('Fingerprint'), findsOneWidget);
    expect(find.textContaining('abababab'), findsOneWidget);

    // Verification.
    expect(find.text('Verification'), findsOneWidget);
    expect(find.text('Trust level'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);

    // Connection (no live link).
    expect(find.text('Connection'), findsOneWidget);
    expect(find.text('This node is not currently nearby'), findsOneWidget);

    // Route (no live link).
    await tester.dragUntilVisible(
      find.text('Route'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    expect(find.text('Route'), findsOneWidget);
    expect(find.text('No route'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('technical identifiers render in the Consolas family', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    await seedContact(container, nodeId: 'node-abc', displayName: 'Alice');
    await tester.pumpAndSettle();

    await pumpNode(tester, container, 'node-abc');

    final nodeId = tester.widget<EditableText>(find.text('node-abc'));
    expect(nodeId.style.fontFamily, OneBitTypography.technicalFamily);

    final fingerprint = tester.widget<EditableText>(
      find.textContaining('abababab'),
    );
    expect(fingerprint.style.fontFamily, OneBitTypography.technicalFamily);

    await disposeApp(tester);
  });

  testWidgets('trust level can be changed through the picker', (tester) async {
    final container = await pumpShell(tester);
    await seedContact(container, nodeId: 'node-abc', displayName: 'Alice');
    await tester.pumpAndSettle();

    await pumpNode(tester, container, 'node-abc');

    expect(find.text('Known'), findsOneWidget);

    await tester.tap(find.text('Trust level'));
    await tester.pumpAndSettle();

    expect(find.text('Known'), findsWidgets);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);

    await tester.tap(find.text('Verified'));
    await tester.pumpAndSettle();

    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Known'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('open conversation creates the private channel and navigates', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    await seedContact(container, nodeId: 'node-abc', displayName: 'Alice');
    await tester.pumpAndSettle();

    await pumpNode(tester, container, 'node-abc');

    await tester.dragUntilVisible(
      find.text('Open conversation'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.tap(find.text('Open conversation'));
    await tester.pumpAndSettle();

    expect(find.byType(ChannelDetailsScreen), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('show verification code derives and presents a code', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    await seedContact(container, nodeId: 'node-abc', displayName: 'Alice');
    await tester.pumpAndSettle();

    await pumpNode(tester, container, 'node-abc');

    await tester.tap(find.text('Show verification code'));
    await tester.pumpAndSettle();

    expect(find.text('Verification code'), findsOneWidget);
    expect(find.textContaining('Matching codes'), findsOneWidget);

    await disposeApp(tester);
  });
}
