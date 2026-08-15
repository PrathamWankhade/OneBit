import 'package:clock/clock.dart';
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
import 'package:onebit/features/identity/domain/trust_level.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../app/support/app_navigation_support.dart';
import '../app/support/screen_test_support.dart';
import 'bluetooth/support/fake_bluetooth_platform.dart';

/// Golden coverage of the Phase 10.4 screens in deterministic states.
///
/// A fixed clock keeps every relative label and timestamp stable. Fonts
/// resolve to the default test typeface so the images are portable across
/// platforms.
void main() {
  Future<void> pumpFixed(WidgetTester tester) async {
    SharedPreferencesAsyncPlatform.instance = sharedPrefsStore();
    final platform = FakeBluetoothPlatform();
    addTearDown(platform.dispose);
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
  }

  Future<void> seedGoldenChannel(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'Meet for coffee tomorrow');
    await seedInbound(container, channelId, sender: 'peer-1', body: 'Sure!');
    await seedUnread(container, channelId, count: 2);
    await container
        .read(channelRepositoryProvider)
        .setPinned(channelId, pinned: true);
    await container.read(messagingEngineProvider).saveDraft(channelId, 'WIP');
    await tester.pumpAndSettle();
  }

  testWidgets('channels screen, empty state', (tester) async {
    await withClock(Clock.fixed(DateTime.utc(2026, 1, 1, 12)), () async {
      await pumpFixed(tester);
      await expectLater(
        find.byType(AppShell),
        matchesGoldenFile('goldens/channels_empty.png'),
      );
      await disposeApp(tester);
    });
  });

  testWidgets('channels screen, seeded list', (tester) async {
    await withClock(Clock.fixed(DateTime.utc(2026, 1, 1, 12)), () async {
      await pumpFixed(tester);
      await seedGoldenChannel(tester, containerOf(tester));
      await expectLater(
        find.byType(AppShell),
        matchesGoldenFile('goldens/channels_list.png'),
      );
      await disposeApp(tester);
    });
  });

  testWidgets('channel details screen, seeded timeline', (tester) async {
    await withClock(Clock.fixed(DateTime.utc(2026, 1, 1, 12)), () async {
      await pumpFixed(tester);
      final container = containerOf(tester);
      final channelId = await seedChannel(
        container,
        peer: 'peer-1',
        title: 'Alice',
      );
      final message = await seedOutbound(
        container,
        channelId,
        'Meet for coffee tomorrow',
      );
      await seedInbound(container, channelId, sender: 'peer-1', body: 'Sure!');
      await container
          .read(messagingEngineProvider)
          .pinMessage(channelId, message.messageId);
      await tester.pumpAndSettle();

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.channelOf(channelId));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AppShell),
        matchesGoldenFile('goldens/channel_details.png'),
      );
      await disposeApp(tester);
    });
  });

  testWidgets('search screen, invitation state', (tester) async {
    await withClock(Clock.fixed(DateTime.utc(2026, 1, 1, 12)), () async {
      await pumpFixed(tester);

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.search);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AppShell),
        matchesGoldenFile('goldens/search_empty.png'),
      );
      await disposeApp(tester);
    });
  });

  testWidgets('nodes screen, trusted contact', (tester) async {
    await withClock(Clock.fixed(DateTime.utc(2026, 1, 2, 12)), () async {
      await pumpFixed(tester);
      final container = containerOf(tester);
      await seedContact(
        container,
        nodeId: 'node-abc',
        displayName: 'Alice',
        trustLevel: TrustLevel.verified,
      );
      await tester.pumpAndSettle();

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.nodes);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AppShell),
        matchesGoldenFile('goldens/nodes_trusted.png'),
      );
      await disposeApp(tester);
    });
  });

  testWidgets('nearby screen, empty air', (tester) async {
    await withClock(Clock.fixed(DateTime.utc(2026, 1, 1, 12)), () async {
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

      await expectLater(
        find.byType(AppShell),
        matchesGoldenFile('goldens/nearby_empty.png'),
      );
      await disposeApp(tester);
      platform.dispose();
    });
  });
}
