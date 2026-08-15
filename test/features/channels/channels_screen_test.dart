import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/database/connection/connection_factory.dart';
import 'package:onebit/core/database/database_providers.dart'
    show databaseConnectionFactoryProvider;
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/channels/presentation/channel_details_screen.dart';
import 'package:onebit/features/channels/presentation/channels_screen.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/features/messaging/domain/channels/channel_type.dart';
import 'package:onebit/features/messaging/domain/channels/conversation_summary.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';
import 'package:onebit/features/messaging/presentation/search_screen.dart';
import 'package:onebit/shared/design_system/components/onebit_badge.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';

import '../../app/support/app_navigation_support.dart';
import '../../app/support/screen_test_support.dart';

/// The channels tab: conversation list, swipe/action-driven channel
/// management, and the loading/error/empty state machine.
void main() {
  testWidgets('empty state welcomes a fresh conversation list', (tester) async {
    await pumpShell(tester);

    expect(find.byType(ChannelsScreen), findsOneWidget);
    expect(find.text('No conversations yet'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('seeded channels render pin, unread, draft and delivery', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'Hello there');
    await seedUnread(container, channelId, count: 3);
    await container.read(messagingEngineProvider).saveDraft(channelId, 'WIP');
    await container
        .read(channelRepositoryProvider)
        .setPinned(channelId, pinned: true);

    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.byIcon(OneBitIcons.pin), findsOneWidget);
    expect(find.byType(OneBitBadge), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(OneBitBadge)),
      isSemantics(label: '3 unread items'),
    );
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('WIP'), findsOneWidget);
    expect(find.text('Hello there'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('swipe archive shows the undo snackbar and removes the row', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'Hello');
    await tester.pumpAndSettle();

    await tester.drag(find.text('Alice'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Channel archived'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
    expect(find.text('No conversations yet'), findsOneWidget);

    // Expire the snackbar timer so the test ends with no pending timers.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await disposeApp(tester);
  });

  testWidgets('long-press opens the action sheet and mute + mark read work', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'Hello');
    await seedUnread(container, channelId, count: 2);
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(find.text('Channel actions'), findsOneWidget);
    expect(find.text('Pin channel'), findsOneWidget);
    expect(find.text('Mute channel'), findsOneWidget);
    expect(find.text('Mark as read'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);

    await tester.tap(find.text('Mute channel'));
    await tester.pumpAndSettle();
    expect(find.byIcon(OneBitIcons.mute), findsOneWidget);

    await tester.longPress(find.text('Alice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();
    expect(find.byType(OneBitBadge), findsNothing);

    await tester.longPress(find.text('Alice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unmute channel'));
    await tester.pumpAndSettle();
    expect(find.byIcon(OneBitIcons.mute), findsNothing);

    await disposeApp(tester);
  });

  testWidgets(
    'tapping a channel opens details; search opens the search screen',
    (tester) async {
      final container = await pumpShell(tester);
      final channelId = await seedChannel(
        container,
        peer: 'peer-1',
        title: 'Alice',
      );
      await seedOutbound(container, channelId, 'Hello');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      expect(find.byType(ChannelDetailsScreen), findsOneWidget);

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.channels);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(OneBitIcons.search));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);

      await disposeApp(tester);
    },
  );

  testWidgets('conversation list failure shows the error state and retry', (
    tester,
  ) async {
    final controller = StreamController<Result<List<ConversationSummary>>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(
            FakeIdentityRepository(identity: testIdentity()),
          ),
          databaseConnectionFactoryProvider.overrideWithValue(
            const InMemoryConnectionFactory(),
          ),
          conversationSummariesProvider.overrideWith((_) => controller.stream),
        ],
        child: const OneBitApp(),
      ),
    );
    await tester.pumpAndSettle();

    controller.add(const Err(StorageFailure(message: 'boom')));
    await tester.pumpAndSettle();

    expect(find.byType(OneBitErrorState), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // Recovery: the stream emits a healthy list after retry.
    controller.add(
      const Ok([
        ConversationSummary(
          channelId: 'c-1',
          type: ChannelType.private,
          title: 'Recovered',
          peerNode: 'peer-1',
        ),
      ]),
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Recovered'), findsOneWidget);
    expect(find.byType(OneBitErrorState), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('conversation list stays loading while the stream is silent', (
    tester,
  ) async {
    final controller = StreamController<Result<List<ConversationSummary>>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(
            FakeIdentityRepository(identity: testIdentity()),
          ),
          databaseConnectionFactoryProvider.overrideWithValue(
            const InMemoryConnectionFactory(),
          ),
          conversationSummariesProvider.overrideWith((_) => controller.stream),
        ],
        child: const OneBitApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OneBitLoadingIndicator), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('every app bar control carries a 48dp tappable target', (
    tester,
  ) async {
    await pumpShell(tester);

    final searchIcon = find.byIcon(OneBitIcons.search);
    expect(searchIcon, findsOneWidget);
    final size = tester.getSize(searchIcon);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(searchIcon),
      isSemantics(label: 'Search messages'),
    );

    await disposeApp(tester);
  });

  testWidgets('archive toggle shows archived empty state', (tester) async {
    await pumpShell(tester);

    expect(find.byType(ChannelsScreen), findsOneWidget);

    // Tap the archive toggle button using tooltip.
    await tester.tap(find.byTooltip('Show archived channels'));
    await tester.pumpAndSettle();

    // Should show the archived empty state.
    expect(find.text('No archived channels'), findsOneWidget);
    expect(find.text('Channels you archive will appear here.'), findsOneWidget);

    // AppBar title should change to "Archived".
    expect(find.text('Archived'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('archive toggle switches back to active channels', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'Hello');
    await tester.pumpAndSettle();

    // Channel is visible.
    expect(find.text('Alice'), findsOneWidget);

    // Switch to archived view.
    await tester.tap(find.byTooltip('Show archived channels'));
    await tester.pumpAndSettle();
    expect(find.text('No archived channels'), findsOneWidget);

    // Switch back to active view.
    await tester.tap(find.byTooltip('Show active channels'));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('long-press in archived view shows restore action', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'Hello');
    await tester.pumpAndSettle();

    // Archive the channel first.
    final channelRepo = container.read(channelRepositoryProvider);
    await channelRepo.archive(channelId);
    await tester.pumpAndSettle();

    // Switch to archived view.
    await tester.tap(find.byTooltip('Show archived channels'));
    await tester.pumpAndSettle();

    // Channel should be visible in archived view.
    expect(find.text('Alice'), findsOneWidget);

    // Long-press should show restore option instead of archive.
    await tester.longPress(find.text('Alice'));
    await tester.pumpAndSettle();
    expect(find.text('Channel actions'), findsOneWidget);
    expect(find.byIcon(OneBitIcons.unarchive), findsOneWidget);

    await disposeApp(tester);
  });
}
