import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import '../support/design_support.dart';

void main() {
  group('OneBitButton', () {
    testWidgets('renders the label with a filled primary button', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitButton(label: 'Save', onPressed: _noop)),
      );
      expect(find.text('Save'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('disabled when onPressed is missing', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitButton(label: 'Save', onPressed: null)),
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('disabled buttons ignore taps', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        oneBitApp(OneBitButton(label: 'Save', onPressed: () => tapped++)),
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      button.onPressed!.call();
      expect(tapped, 1);
    });

    testWidgets('loading shows a spinner and is not tappable', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        oneBitApp(
          OneBitButton(label: 'Save', loading: true, onPressed: () => tapped++),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('large buttons meet the 48dp target', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitButton(
            label: 'Save',
            onPressed: _noop,
            size: OneBitButtonSize.large,
          ),
        ),
      );
      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('variants resolve to their Material hosts', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const Column(
            children: [
              OneBitButton(
                label: 'a',
                onPressed: _noop,
                variant: OneBitButtonVariant.primary,
              ),
              OneBitButton(
                label: 'b',
                onPressed: _noop,
                variant: OneBitButtonVariant.secondary,
              ),
              OneBitButton(
                label: 'c',
                onPressed: _noop,
                variant: OneBitButtonVariant.tonal,
              ),
              OneBitButton(
                label: 'd',
                onPressed: _noop,
                variant: OneBitButtonVariant.text,
              ),
              OneBitButton(
                label: 'e',
                onPressed: _noop,
                variant: OneBitButtonVariant.destructive,
              ),
            ],
          ),
        ),
      );
      expect(find.byType(FilledButton), findsNWidgets(3));
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('renders a leading icon when provided', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitButton(
            label: 'Retry',
            onPressed: _noop,
            icon: Icons.refresh,
          ),
        ),
      );
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });
  });

  group('OneBitOutlinedButton', () {
    testWidgets('renders an outlined button', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitOutlinedButton(label: 'Cancel', onPressed: _noop),
        ),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('disabled when onPressed is missing', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitOutlinedButton(label: 'Cancel', onPressed: null)),
      );
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
    });
  });
}

void _noop() {}
