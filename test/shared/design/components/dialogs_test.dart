import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_dialogs.dart';
import '../support/design_support.dart';

void main() {
  Widget opener(Future<bool?> Function(BuildContext) open) {
    return oneBitApp(
      Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  testWidgets('showOneBitDialog returns the chosen action value', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      opener(
        (context) => showOneBitDialog<bool>(
          context,
          title: 'Reset node?',
          message: 'All routes will be cleared.',
          actions: const [
            OneBitDialogAction(label: 'Cancel', value: false),
            OneBitDialogAction(label: 'Reset', value: true),
          ],
        ).then((value) => result = value),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Reset node?'), findsOneWidget);
    expect(find.text('All routes will be cleared.'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('OneBitDialogs.confirm resolves true/false', (tester) async {
    bool? outcome;
    await tester.pumpWidget(
      opener(
        (context) => OneBitDialogs.confirm(
          context,
          title: 'Enable relay?',
          confirmLabel: 'Enable',
        ).then((value) => outcome = value),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();
    expect(outcome, isTrue);
  });

  testWidgets('destructive variant confirms with the destructive button', (
    tester,
  ) async {
    await tester.pumpWidget(
      opener(
        (context) => OneBitDialogs.destructive(
          context,
          title: 'Purge cache?',
          confirmLabel: 'Purge',
          onConfirm: () {},
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Purge cache?'), findsOneWidget);
    await tester.tap(find.text('Purge'));
    await tester.pumpAndSettle();
  });

  testWidgets('dismissing via barrier returns null', (tester) async {
    bool? result;
    await tester.pumpWidget(
      opener(
        (context) => showOneBitDialog<bool>(
          context,
          title: 'Info',
          actions: const [OneBitDialogAction(label: 'OK', value: true)],
        ).then((value) => result = value),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('renders in the dark identity', (tester) async {
    await tester.pumpWidget(
      oneBitDarkApp(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => OneBitDialogs.info(
                context,
                title: 'Dark info',
                message: 'Message',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Dark info'), findsOneWidget);
  });
}
