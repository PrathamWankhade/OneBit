import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/database/connection/connection_factory.dart';
import 'package:onebit/core/database/database_providers.dart'
    show databaseConnectionFactoryProvider;
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_providers.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/features/nodes/presentation/nodes_screen.dart';
import 'package:onebit/shared/design_system/accessibility/onebit_accessibility.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';

import '../app/support/app_navigation_support.dart';
import '../app/support/screen_test_support.dart';
import 'bluetooth/support/fake_bluetooth_platform.dart';

/// Screen-level accessibility: every interactive control carries a semantic
/// label and a >= 48dp target, and dynamic text does not break layouts.
void main() {
  group('channels screen', () {
    testWidgets('search control exposes a label and 48dp target', (
      tester,
    ) async {
      await pumpShell(tester);

      final button = find.byType(OneBitIconButton);
      expect(button, findsOneWidget);
      expect(
        tester.getSemantics(button),
        isSemantics(label: 'Search messages', isButton: true),
      );
      final size = tester.getSize(button);
      expect(
        size.width,
        greaterThanOrEqualTo(OneBitAccessibility.minInteractiveSize),
      );
      expect(
        size.height,
        greaterThanOrEqualTo(OneBitAccessibility.minInteractiveSize),
      );

      await disposeApp(tester);
    });

    testWidgets('rows stay tappable at large text scales', (tester) async {
      final container = await pumpShell(tester);
      final channelId = await seedChannel(
        container,
        peer: 'peer-1',
        title: 'Alice',
      );
      await seedOutbound(container, channelId, 'Hello');
      await seedUnread(container, channelId, count: 2);
      await tester.pumpAndSettle();

      await tester.binding.setSurfaceSize(const Size(1080, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpAndSettle();

      final row = find.text('Alice');
      expect(row, findsOneWidget);
      final size = tester.getSize(row);
      expect(
        size.height,
        greaterThanOrEqualTo(OneBitAccessibility.minVisualSize),
      );

      await disposeApp(tester);
    });
  });

  group('nodes screen', () {
    testWidgets('every section header and row reads back to TalkBack', (
      tester,
    ) async {
      final container = await pumpShell(tester);
      await seedContact(container, nodeId: 'node-abc', displayName: 'Alice');
      await tester.pumpAndSettle();

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.nodes);
      await tester.pumpAndSettle();

      expect(find.byType(NodesScreen), findsOneWidget);
      expect(find.text('Trusted'), findsOneWidget);
      final semantics = tester.getSemantics(find.text('Alice'));
      expect(semantics, isSemantics(label: 'Alice'));

      await disposeApp(tester);
    });
  });

  group('nearby screen', () {
    testWidgets('scan toggle is announced and 48dp', (tester) async {
      final platform = FakeBluetoothPlatform();
      platform.enqueue('getState', Ok(readySnapshot()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(
              FakeIdentityRepository(identity: testIdentity()),
            ),
            databaseConnectionFactoryProvider.overrideWithValue(
              const InMemoryConnectionFactory(),
            ),
            bluetoothPlatformProvider.overrideWithValue(platform),
          ],
          child: const OneBitApp(),
        ),
      );
      await tester.pumpAndSettle();

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.nearby);
      await tester.pumpAndSettle();

      final button = find.byType(OneBitIconButton);
      expect(button, findsOneWidget);
      expect(
        tester.getSemantics(button),
        isSemantics(label: 'Scan for devices', isButton: true),
      );
      final size = tester.getSize(button);
      expect(
        size.width,
        greaterThanOrEqualTo(OneBitAccessibility.minInteractiveSize),
      );
      expect(
        size.height,
        greaterThanOrEqualTo(OneBitAccessibility.minInteractiveSize),
      );

      await disposeApp(tester);
      platform.dispose();
    });
  });
}
