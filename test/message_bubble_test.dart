import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/conversations/presentation/message_bubble.dart';
import 'package:onebit/features/protocol/delivery_state.dart';

/// The lock on a bubble is read from the row, never promised: a bubble
/// without it makes no claim, and one with it describes bytes that
/// actually traveled encrypted.
///
/// I9.9.a — an expired message wears its own icon and, in words, the
/// reason it stopped: shed from the outbox before the recipient ever
/// saw it, which is not the same story as any other failure.
///
/// I9.14.a — the icon and the words come from one contract: the
/// screen computes it once per row and the bubble paints whatever it
/// is handed, including the in-flight and retry states the database
/// never holds.
void main() {
  Future<void> pumpBubble(
    WidgetTester tester, {
    required bool encrypted,
    String status = 'sent',
    DeliveryState? deliveryState,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: MessageBubble(
            content: 'hello',
            timestamp: DateTime(2025),
            isReceived: false,
            status: status,
            deliveryState: deliveryState,
            encrypted: encrypted,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('an encrypted bubble carries the lock', (tester) async {
    await pumpBubble(tester, encrypted: true);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('a plaintext bubble makes no claim', (tester) async {
    await pumpBubble(tester, encrypted: false);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('an expired message says it never reached the recipient',
      (tester) async {
    await pumpBubble(tester, encrypted: false, status: 'expired');
    expect(find.byIcon(Icons.timer_off), findsOneWidget);
    expect(find.text('Expired — never reached recipient'), findsOneWidget);
  });

  testWidgets('only expiry wears the expiry label', (tester) async {
    await pumpBubble(tester, encrypted: false, status: 'failed');
    expect(find.text('Expired — never reached recipient'), findsNothing);
    expect(find.byIcon(Icons.timer_off), findsNothing);

    await pumpBubble(tester, encrypted: false, status: 'queued');
    expect(find.text('Expired — never reached recipient'), findsNothing);
    expect(find.byIcon(Icons.timer_off), findsNothing);
  });

  testWidgets('a retrying message says it will go again', (tester) async {
    await pumpBubble(
      tester,
      encrypted: false,
      status: 'queued',
      deliveryState: DeliveryState.retrying,
    );
    expect(find.byIcon(Icons.sync_problem), findsOneWidget);
    expect(find.text('Retrying'), findsOneWidget);
  });

  testWidgets('a message on the wire shows it being sent', (tester) async {
    await pumpBubble(
      tester,
      encrypted: false,
      status: 'queued',
      deliveryState: DeliveryState.transmitting,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Sending…'), findsOneWidget);
  });

  testWidgets('a queued message wears the clock and the word',
      (tester) async {
    await pumpBubble(
      tester,
      encrypted: false,
      status: 'queued',
      deliveryState: DeliveryState.queued,
    );
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.text('Queued'), findsOneWidget);
  });

  testWidgets('a failed message says Failed, in red-inked words',
      (tester) async {
    await pumpBubble(
      tester,
      encrypted: false,
      status: 'failed',
      deliveryState: DeliveryState.failed,
    );
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
  });

  testWidgets('delivered and read carry their checks without a caption',
      (tester) async {
    await pumpBubble(
      tester,
      encrypted: false,
      status: 'delivered',
      deliveryState: DeliveryState.delivered,
    );
    expect(find.byIcon(Icons.done_all), findsOneWidget);
    expect(find.text('Queued'), findsNothing);
    expect(find.text('Retrying'), findsNothing);

    await pumpBubble(
      tester,
      encrypted: false,
      status: 'read',
      deliveryState: DeliveryState.read,
    );
    expect(find.byIcon(Icons.done_all), findsOneWidget);
    expect(find.text('Queued'), findsNothing);
  });

  testWidgets('a computed state outranks the raw status string',
      (tester) async {
    // The screen hands the contract's answer; the fallback on the
    // status string exists only for callers that know no better.
    await pumpBubble(
      tester,
      encrypted: false,
      status: 'sent',
      deliveryState: DeliveryState.read,
    );
    expect(find.byIcon(Icons.done_all), findsOneWidget);
    expect(find.byIcon(Icons.done), findsNothing);
  });
}
