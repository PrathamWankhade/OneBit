import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/ui/components/conversation_actions_sheet.dart';
import 'package:onebit/features/ui/components/message_actions_sheet.dart';

/// The action sheets used to pop without a value, so every awaiting
/// caller read its own menu as "the user backed out" and returned
/// before doing anything. These pin the contract down: a tap answers
/// with its action, a dismissal answers with null.
void main() {
  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        // Injected through the builder so `MaterialApp` does not replace
        // it with its own MediaQuery; the sheet itself has no looping
        // animation, this just keeps the transition out of the way.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const Scaffold(body: SizedBox()),
      ),
    );
  }

  /// Open or close, in bounded steps rather than a `pumpAndSettle` that
  /// a modal route can keep alive longer than it looks.
  Future<void> pumpTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// A context that is inside the navigator and has localizations —
  /// the `MaterialApp` element itself has neither, so a sheet shown
  /// from there asserts before it opens.
  BuildContext hostContext(WidgetTester tester) =>
      tester.element(find.byType(Scaffold));

  testWidgets('tapping a row resolves the sheet to that row action',
      (tester) async {
    await pumpHost(tester);

    final shown = showMessageActions(hostContext(tester));
    await pumpTransition(tester);

    await tester.tap(find.text('Delete'));
    await pumpTransition(tester);

    expect(await shown, MessageActionType.delete);
  });

  testWidgets('tapping Copy resolves to the copy action', (tester) async {
    await pumpHost(tester);

    final shown = showMessageActions(hostContext(tester));
    await pumpTransition(tester);

    await tester.tap(find.text('Copy'));
    await pumpTransition(tester);

    expect(await shown, MessageActionType.copy);
  });

  testWidgets('tapping outside resolves to null', (tester) async {
    await pumpHost(tester);

    final shown = showMessageActions(hostContext(tester));
    await pumpTransition(tester);

    await tester.tapAt(const Offset(4, 4));
    await pumpTransition(tester);

    expect(await shown, isNull);
  });

  testWidgets('a message with no text offers nothing to copy',
      (tester) async {
    await pumpHost(tester);

    final shown = showMessageActions(hostContext(tester), canCopy: false);
    await pumpTransition(tester);

    expect(find.text('Copy'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await pumpTransition(tester);

    expect(await shown, MessageActionType.delete);
  });

  testWidgets('the message menu only offers what it can carry out',
      (tester) async {
    await pumpHost(tester);

    final shown = showMessageActions(hostContext(tester));
    await pumpTransition(tester);

    // Rows that existed with an empty handler are gone rather than
    // shipped as dead taps.
    for (final label in ['Reply', 'Forward', 'React', 'Edit', 'Details']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await pumpTransition(tester);

    expect(await shown, isNull);
  });

  testWidgets('the conversation menu answers with its only real action',
      (tester) async {
    await pumpHost(tester);

    final shown = showConversationActions(hostContext(tester), peerName: 'B');
    await pumpTransition(tester);

    expect(find.text('Delete conversation'), findsOneWidget);
    expect(find.text('Pin conversation'), findsNothing);
    expect(find.text('Mute notifications'), findsNothing);

    await tester.tap(find.text('Delete conversation'));
    await pumpTransition(tester);

    expect(await shown, ConversationActionType.delete);
  });
}
