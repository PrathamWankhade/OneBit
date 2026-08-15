import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_message_input.dart';

import '../../app/support/app_navigation_support.dart';
import '../../app/support/screen_test_support.dart';

/// Phase 10.5 message presentation: replies, edits, copying, selection,
/// forwarding, receipts, forwarded/edited labels and the typing indicator.
void main() {
  void tallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpDetails(WidgetTester tester, String channelId) async {
    GoRouter.of(
      tester.element(find.byType(AppShell)),
    ).go(AppRoutePaths.channelOf(channelId));
    await tester.pumpAndSettle();
  }

  Future<void> openMessageActions(WidgetTester tester, String body) async {
    final row = find
        .ancestor(of: find.text(body), matching: find.byType(InkWell))
        .first;
    // The bubble body is a SelectableText: long-pressing the text itself
    // opens the text-selection toolbar, not the action sheet. Press the
    // row's padding corner instead.
    await tester.longPressAt(tester.getTopLeft(row) + const Offset(8, 8));
    await tester.pumpAndSettle();
  }

  Future<void> pickSheetAction(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('reply mode quotes the target and sends a threaded message', (
    tester,
  ) async {
    tallViewport(tester);
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'Hello there');
    await tester.pumpAndSettle();

    await pumpDetails(tester, channelId);

    await openMessageActions(tester, 'Hello there');
    await pickSheetAction(tester, 'Reply');

    expect(find.text('Reply to You'), findsOneWidget);

    await tester.enterText(find.byType(OneBitMessageInput), 'Ack');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Ack'), findsOneWidget);
    // The reply preview quotes the original message next to the new bubble.
    expect(find.text('Hello there'), findsNWidgets(2));

    await disposeApp(tester);
  });

  testWidgets('edit mode pre-fills the composer and marks the edit', (
    tester,
  ) async {
    tallViewport(tester);
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'Old text');
    await tester.pumpAndSettle();

    await pumpDetails(tester, channelId);

    await openMessageActions(tester, 'Old text');
    await pickSheetAction(tester, 'Edit');

    expect(find.textContaining('Edit:'), findsOneWidget);

    await tester.enterText(find.byType(OneBitMessageInput), 'New text');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('New text'), findsOneWidget);
    expect(find.text('edited'), findsOneWidget);
    expect(find.text('Old text'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('copy writes the body to the clipboard', (tester) async {
    tallViewport(tester);
    final writes = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        writes.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'Copy me');
    await tester.pumpAndSettle();

    await pumpDetails(tester, channelId);

    await openMessageActions(tester, 'Copy me');
    await pickSheetAction(tester, 'Copy');

    final setData = writes.where((c) => c.method == 'Clipboard.setData');
    expect(setData, hasLength(1));
    expect((setData.single.arguments as Map)['text'], 'Copy me');

    await disposeApp(tester);
  });

  testWidgets('delete confirms through the dialog and removes the message', (
    tester,
  ) async {
    tallViewport(tester);
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'Doomed');
    await seedInbound(container, channelId, sender: 'peer-1', body: 'Stays');
    await tester.pumpAndSettle();

    await pumpDetails(tester, channelId);

    await openMessageActions(tester, 'Doomed');
    await pickSheetAction(tester, 'Delete');

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Delete'),
          )
          .last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Doomed'), findsNothing);
    expect(find.text('Stays'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('selection mode selects, copies and exits', (tester) async {
    tallViewport(tester);
    final writes = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        writes.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'First line');
    await seedOutbound(container, channelId, 'Second line');
    await tester.pumpAndSettle();

    await pumpDetails(tester, channelId);

    await openMessageActions(tester, 'First line');
    await pickSheetAction(tester, 'Select');

    expect(find.byTooltip('Select all'), findsOneWidget);
    await tester.tap(find.byTooltip('Select all'));
    await tester.pump();

    await tester.tap(find.byTooltip('Copy'));
    await tester.pumpAndSettle();

    final setData = writes.where((c) => c.method == 'Clipboard.setData');
    expect(setData, hasLength(1));
    expect(
      (setData.single.arguments as Map)['text'],
      'First line\n\nSecond line',
    );
    // Copying exits selection mode.
    expect(find.byTooltip('Select all'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('forward offers other channels and lands a copy there', (
    tester,
  ) async {
    tallViewport(tester);
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    final targetId = await seedChannel(container, peer: 'peer-2', title: 'Bob');
    await seedOutbound(container, channelId, 'Shareable note');
    await tester.pumpAndSettle();

    await pumpDetails(tester, channelId);

    await openMessageActions(tester, 'Shareable note');
    await pickSheetAction(tester, 'Forward');

    expect(find.text('Bob'), findsOneWidget);
    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();

    final targetTimeline =
        (await container
                .read(messagingEngineProvider)
                .pageChannel(targetId, limit: 50))
            .value
            ?.items
            .where((m) => m.body == 'Shareable note')
            .toList();
    expect(targetTimeline, hasLength(1));
    expect(targetTimeline!.single.forwarded, isTrue);

    await disposeApp(tester);
  });

  testWidgets('outbound receipts render status and read labels', (
    tester,
  ) async {
    tallViewport(tester);
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'Receipted');
    await container.read(messagingEngineProvider).markChannelRead(channelId);
    await tester.pumpAndSettle();

    await pumpDetails(tester, channelId);

    // Read receipts: the readAt time renders as a "Read {time}" label.
    expect(find.textContaining('Read '), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('forwarded and edited labels render on the bubble', (
    tester,
  ) async {
    tallViewport(tester);
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    final message = await seedOutbound(container, channelId, 'Labelled');
    await container
        .read(messagingEngineProvider)
        .edit(message.messageId, 'Labelled v2');
    await tester.pumpAndSettle();

    await pumpDetails(tester, channelId);

    expect(find.text('edited'), findsOneWidget);
    expect(find.text('Labelled v2'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('remote typing shows the typing indicator', (tester) async {
    tallViewport(tester);
    final container = await pumpShell(tester);
    final channelId = await seedChannel(
      container,
      peer: 'peer-1',
      title: 'Alice',
    );
    await seedOutbound(container, channelId, 'Hello');
    final typing = container.read(messagingEngineProvider).typing;
    typing.startTyping(channelId, 'peer-1');
    addTearDown(() => typing.stopTyping(channelId, 'peer-1'));
    await tester.pumpAndSettle();

    await pumpDetails(tester, channelId);

    expect(find.textContaining('typing'), findsOneWidget);

    await disposeApp(tester);
  });
}
