import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/features/messaging/domain/channels/channel.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_type.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';

import '../../app/support/app_navigation_support.dart';
import '../../app/support/screen_test_support.dart';

/// The channel details screen: timeline, pinned messages, pagination and
/// the loading/error/empty state machine.
void main() {
  Future<void> pumpDetails(
    WidgetTester tester,
    ProviderContainer container,
    String channelId,
  ) async {
    GoRouter.of(
      tester.element(find.byType(AppShell)),
    ).go(AppRoutePaths.channelOf(channelId));
    await tester.pumpAndSettle();
  }

  testWidgets('renders outbound and inbound messages in the timeline', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'Hello there');
    await seedInbound(container, channelId, sender: 'peer-1', body: 'Hi back');
    await tester.pumpAndSettle();

    await pumpDetails(tester, container, channelId);

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Hello there'), findsOneWidget);
    expect(find.text('Hi back'), findsOneWidget);
    expect(find.text('peer-1'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('pinned messages render under the pinned section', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    final message = await seedOutbound(container, channelId, 'Important');
    await container
        .read(messagingEngineProvider)
        .pinMessage(channelId, message.messageId);
    await tester.pumpAndSettle();

    await pumpDetails(tester, container, channelId);

    expect(find.text('Pinned messages'), findsOneWidget);
    expect(find.text('Important'), findsNWidgets(2));

    await disposeApp(tester);
  });

  testWidgets('load older paginates toward the past', (tester) async {
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    // 151 messages: one page (150) + one older page.
    for (var i = 0; i < 151; i++) {
      await container
          .read(messageRepositoryProvider)
          .insert(
            Message(
              messageId: 'm-$i',
              channelId: channelId,
              sender: 'peer-1',
              timestamp: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
              body: 'Message $i',
              status: MessageStatus.delivered,
              sequence: i,
            ),
          );
    }
    await tester.pumpAndSettle();

    await pumpDetails(tester, container, channelId);

    // Newest message and the load-older affordance sit at the bottom of
    // the reversed timeline.
    expect(find.text('Message 150'), findsOneWidget);
    expect(find.text('Load older messages'), findsOneWidget);

    await tester.tap(find.text('Load older messages'));
    await tester.pumpAndSettle();

    // All history is loaded: the affordance is gone and the oldest
    // message is reachable at the top of the reversed list.
    // All history is loaded: the affordance is gone and the oldest
    // message is reachable at the top of the reversed list. Incremental
    // drags: bubble bodies are SelectableTexts, which can consume a
    // single oversized drag gesture.
    expect(find.text('Load older messages'), findsNothing);
    for (var i = 0; i < 8 && tester.any(find.text('Message 0')) == false; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, 3000));
      await tester.pumpAndSettle();
    }
    expect(find.text('Message 0'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('an empty channel shows the friendly empty state', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await tester.pumpAndSettle();

    await pumpDetails(tester, container, channelId);

    expect(find.text('No messages yet'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('an unknown channel id reports not found', (tester) async {
    final container = await pumpShell(tester);

    await pumpDetails(tester, container, 'does-not-exist');

    expect(find.text('Channel not found'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('timeline failure shows the error state with retry', (
    tester,
  ) async {
    // Broadcast: the retry invalidates the provider, which re-subscribes;
    // a single-subscription controller would throw on the second listen.
    final controller = StreamController<Result<List<Message>>>.broadcast();
    addTearDown(controller.close);

    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(
          FakeIdentityRepository(identity: testIdentity()),
        ),
        databaseConnectionFactoryProvider.overrideWithValue(
          const InMemoryConnectionFactory(),
        ),
        channelTimelineProvider.overrideWith((ref, arg) => controller.stream),
      ],
    );
    final created = await container
        .read(channelRepositoryProvider)
        .create(
          const CreateChannelParams(
            type: ChannelType.private,
            peer: 'peer-1',
            title: 'Alice',
          ),
        );
    final channelId = created.value!.channelId;
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const OneBitApp()),
    );
    await tester.pumpAndSettle();

    GoRouter.of(
      tester.element(find.byType(AppShell)),
    ).go(AppRoutePaths.channelOf(channelId));
    await tester.pumpAndSettle();

    controller.add(const Err(StorageFailure(message: 'boom')));
    await tester.pumpAndSettle();

    expect(find.byType(OneBitErrorState), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // Retry re-runs the timeline stream; the recovery data arrives after
    // the re-subscription.
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    controller.add(
      Ok([
        Message(
          messageId: 'm-1',
          channelId: channelId,
          sender: 'peer-1',
          timestamp: DateTime.utc(2026, 1, 1),
          body: 'Recovered line',
          status: MessageStatus.delivered,
        ),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // ignore: avoid_print
    print(
      'PROBE6 after add: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()}',
    );
    expect(find.text('Recovered line'), findsOneWidget);
    expect(find.byType(OneBitErrorState), findsNothing);

    await disposeApp(tester);
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('timeline stays loading while the channel stream is silent', (
    tester,
  ) async {
    const channelId = 'c-1';
    final controller = StreamController<Result<List<Message>>>.broadcast();
    addTearDown(controller.close);

    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(
          FakeIdentityRepository(identity: testIdentity()),
        ),
        databaseConnectionFactoryProvider.overrideWithValue(
          const InMemoryConnectionFactory(),
        ),
        channelTimelineProvider.overrideWith((ref, arg) => controller.stream),
        // The channel lookup never resolves either, so the view cannot
        // leave its initial loading state.
        channelProvider.overrideWith(
          (ref, arg) => Completer<Result<Channel?>>().future,
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const OneBitApp()),
    );
    await tester.pumpAndSettle();

    GoRouter.of(
      tester.element(find.byType(AppShell)),
    ).go(AppRoutePaths.channelOf(channelId));
    // Bounded pumps: the loading indicator animates indefinitely, so
    // pumpAndSettle would never settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(OneBitLoadingIndicator), findsOneWidget);

    await disposeApp(tester);
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
  });
}
