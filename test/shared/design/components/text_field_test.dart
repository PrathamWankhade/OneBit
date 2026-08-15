import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_search_field.dart';
import 'package:onebit/shared/design_system/components/onebit_text_field.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import '../support/design_support.dart';

void main() {
  group('OneBitSearchField', () {
    testWidgets('shows hint and search prefix', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        oneBitApp(
          OneBitSearchField(controller: controller, hintText: 'Search nodes'),
        ),
      );
      expect(find.text('Search nodes'), findsOneWidget);
      expect(find.byIcon(OneBitIcons.search), findsOneWidget);
    });

    testWidgets('clear action appears with text and clears', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? lastChange;
      await tester.pumpWidget(
        oneBitApp(
          OneBitSearchField(
            controller: controller,
            onChanged: (value) => lastChange = value,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'node-01');
      await tester.pump();
      expect(find.byIcon(OneBitIcons.close), findsOneWidget);

      await tester.tap(find.byIcon(OneBitIcons.close));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(lastChange, '');
    });

    testWidgets('no clear action while empty', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        oneBitApp(OneBitSearchField(controller: controller)),
      );
      await tester.pump();
      expect(find.byIcon(OneBitIcons.close), findsNothing);
    });
  });

  group('OneBitTextField', () {
    testWidgets('renders label, hint and forwards edits', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? lastChange;
      await tester.pumpWidget(
        oneBitApp(
          OneBitTextField(
            controller: controller,
            label: 'Display name',
            hint: 'e.g. relay-42',
            onChanged: (value) => lastChange = value,
          ),
        ),
      );
      expect(find.text('Display name'), findsOneWidget);
      expect(find.text('e.g. relay-42'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'relay-42');
      expect(lastChange, 'relay-42');
    });

    testWidgets('reports validator errors', (tester) async {
      final controller = TextEditingController(text: 'x');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        oneBitApp(
          OneBitTextField(
            controller: controller,
            validator: (value) =>
                (value == null || value.length < 2) ? 'Too short' : null,
          ),
        ),
      );
      expect(find.text('Too short'), findsOneWidget);
    });

    testWidgets('renders prefix and suffix icons', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        oneBitApp(
          OneBitTextField(
            controller: controller,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: const Icon(Icons.check),
          ),
        ),
      );
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });
}
