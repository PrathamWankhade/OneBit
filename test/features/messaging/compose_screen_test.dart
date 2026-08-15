import 'dart:async';

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
import 'package:onebit/features/channels/presentation/channel_details_screen.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/features/messaging/presentation/compose_message_screen.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_message_input.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../app/support/app_navigation_support.dart';
import '../../app/support/screen_test_support.dart';

/// The production composer: draft restore, send through the messaging
/// engine, attachment action sheet and the voice recorder fallback.
void main() {
  GoRouter routerOf(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(AppShell)));

  Future<ProviderContainer> pumpComposer(WidgetTester tester) async {
    final store = sharedPrefsStore();
    SharedPreferencesAsyncPlatform.instance = store;
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(
          FakeIdentityRepository(identity: testIdentity()),
        ),
        databaseConnectionFactoryProvider.overrideWithValue(
          const InMemoryConnectionFactory(),
        ),
        meshStateProvider.overrideWith(
          (ref) => Stream.value(const Ok(MeshEngineState.running)),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const OneBitApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Unmounts the app and disposes the manual container. This MUST happen
  /// inside the test body: flutter_test's pending-timer check runs before
  /// `addTearDown` callbacks, so a container left alive there would fail
  /// every test with the engine's periodic timers still pending.
  Future<void> disposeComposer(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await disposeApp(tester);
    container.dispose();
    // Drift schedules a zero-duration Timer when its query streams are
    // closed during disposal; advance the fake clock so the test ends with
    // no pending timers.
    await tester.pump(const Duration(milliseconds: 10));
  }

  Finder sendButton() => find.descendant(
    of: find.byType(OneBitMessageInput),
    matching: find.byIcon(OneBitIcons.send),
  );

  testWidgets('composer restores the persisted draft', (tester) async {
    final container = await pumpComposer(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await container.read(messagingEngineProvider).saveDraft(channelId, 'WIP');
    await tester.pumpAndSettle();

    routerOf(tester).go(AppRoutePaths.composeOf(channelId));
    await tester.pumpAndSettle();

    expect(find.byType(ComposeMessageScreen), findsOneWidget);
    expect(find.text('WIP'), findsOneWidget);

    await disposeComposer(tester, container);
  });

  testWidgets('send publishes the message into the timeline', (tester) async {
    final container = await pumpComposer(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await tester.pumpAndSettle();

    routerOf(tester).go(AppRoutePaths.composeOf(channelId));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Hello compose');
    await tester.pumpAndSettle();
    await tester.tap(sendButton());
    await tester.pumpAndSettle();

    // Drift stream emissions are timer-scheduled in the test zone; the
    // subscription must run under the real event loop to complete.
    final messages = await tester.runAsync(
      () => container
          .read(messageRepositoryProvider)
          .watchChannel(channelId, limit: 10)
          .first,
    );
    final sent = messages!.value!.where((m) => m.body == 'Hello compose');
    expect(sent, isNotEmpty);

    await disposeComposer(tester, container);
  });

  testWidgets('draft persists while typing and clears after send', (
    tester,
  ) async {
    final container = await pumpComposer(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await tester.pumpAndSettle();

    routerOf(tester).go(AppRoutePaths.composeOf(channelId));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Draft me');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    final saved = await container
        .read(messagingEngineProvider)
        .loadDraft(channelId);
    expect(saved.value?.body, 'Draft me');

    await disposeComposer(tester, container);
  });

  testWidgets('attachment action opens the picker sheet', (tester) async {
    final container = await pumpComposer(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await tester.pumpAndSettle();

    routerOf(tester).go(AppRoutePaths.composeOf(channelId));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(OneBitIcons.attachFile));
    await tester.pumpAndSettle();
    expect(find.text('Add attachment'), findsOneWidget);
    expect(find.text('Image'), findsOneWidget);
    expect(find.text('Document'), findsOneWidget);
    expect(find.text('File'), findsOneWidget);

    await disposeComposer(tester, container);
  });

  testWidgets('voice recorder reports unavailability without a backend', (
    tester,
  ) async {
    final container = await pumpComposer(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await tester.pumpAndSettle();

    routerOf(tester).go(AppRoutePaths.composeOf(channelId));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(OneBitIcons.mic));
    await tester.pumpAndSettle();
    expect(
      find.text('Voice recording is not available on this device'),
      findsOneWidget,
    );

    await disposeComposer(tester, container);
  });

  testWidgets('composed message appears in the conversation screen', (
    tester,
  ) async {
    final container = await pumpComposer(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await tester.pumpAndSettle();

    routerOf(tester).go(AppRoutePaths.composeOf(channelId));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'From composer');
    await tester.pumpAndSettle();
    await tester.tap(sendButton());
    await tester.pumpAndSettle();

    routerOf(tester).go(AppRoutePaths.channelOf(channelId));
    await tester.pumpAndSettle();

    expect(find.byType(ChannelDetailsScreen), findsOneWidget);
    expect(find.text('From composer'), findsOneWidget);

    await disposeComposer(tester, container);
  });
}
