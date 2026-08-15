import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_filter_field.dart';
import 'package:onebit/shared/design_system/components/onebit_message_input.dart';
import 'package:onebit/shared/design_system/components/onebit_technical_field.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import '../support/design_support.dart';

void main() {
  group('OneBitMessageInput', () {
    testWidgets('sends the draft on submit', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? sent;
      await tester.pumpWidget(
        oneBitApp(
          OneBitMessageInput(
            controller: controller,
            hintText: 'Message',
            onSend: (value) => sent = value,
          ),
        ),
      );
      expect(find.text('Message'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byIcon(OneBitIcons.send));
      await tester.pump();
      expect(sent, 'hello');
    });

    testWidgets('send stays disabled while empty', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? sent;
      await tester.pumpWidget(
        oneBitApp(
          OneBitMessageInput(
            controller: controller,
            onSend: (value) => sent = value,
          ),
        ),
      );
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(OneBitIcons.send),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(sent, isNull);
    });

    testWidgets('sending state replaces the action with progress', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'x');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        oneBitApp(
          OneBitMessageInput(
            controller: controller,
            sending: true,
            onSend: (_) {},
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(OneBitIcons.send), findsNothing);
    });

    testWidgets('disabled composer blocks edits', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        oneBitApp(
          OneBitMessageInput(
            controller: controller,
            enabled: false,
            onSend: (_) {},
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });
  });

  group('OneBitTechnicalField', () {
    testWidgets('accepts technical values', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? last;
      await tester.pumpWidget(
        oneBitApp(
          OneBitTechnicalField(
            controller: controller,
            label: 'fingerprint',
            onChanged: (value) => last = value,
          ),
        ),
      );
      expect(find.text('fingerprint'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'A1:B2');
      expect(last, 'A1:B2');
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.style.fontFamily, 'Consolas');
    });

    testWidgets('disabled field blocks input', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        oneBitApp(OneBitTechnicalField(controller: controller, enabled: false)),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });
  });

  group('OneBitFilterField', () {
    testWidgets('renders hint, filter glyph and active badge', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        oneBitApp(
          OneBitFilterField(
            controller: controller,
            hintText: 'Filter packets',
            activeCount: 2,
          ),
        ),
      );
      expect(find.text('Filter packets'), findsOneWidget);
      expect(find.byIcon(OneBitIcons.filter), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('clear action clears text and reports change', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? last;
      var cleared = 0;
      await tester.pumpWidget(
        oneBitApp(
          OneBitFilterField(
            controller: controller,
            onChanged: (value) => last = value,
            onClear: () => cleared++,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'mem');
      await tester.pump();
      expect(find.byIcon(OneBitIcons.close), findsOneWidget);
      await tester.tap(find.byIcon(OneBitIcons.close));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(last, '');
      expect(cleared, 1);
    });
  });
}
