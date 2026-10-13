import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/conversations/presentation/message_bubble.dart';

/// The lock on a bubble is read from the row, never promised: a bubble
/// without it makes no claim, and one with it describes bytes that
/// actually traveled encrypted.
///
/// I9.9.a — an expired message wears its own icon and, in words, the
/// reason it stopped: shed from the outbox before the recipient ever
/// saw it, which is not the same story as any other failure.
void main() {
  Future<void> pumpBubble(
    WidgetTester tester, {
    required bool encrypted,
    String status = 'sent',
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
}
