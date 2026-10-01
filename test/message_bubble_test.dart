import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/conversations/presentation/message_bubble.dart';

/// The lock on a bubble is read from the row, never promised: a bubble
/// without it makes no claim, and one with it describes bytes that
/// actually traveled encrypted.
void main() {
  Future<void> pumpBubble(
    WidgetTester tester, {
    required bool encrypted,
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
            status: 'sent',
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
}
