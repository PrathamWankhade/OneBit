import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';
import '../support/design_support.dart';

void main() {
  group('OneBitCard', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitCard(child: Text('content'))),
      );
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('fires tap and long-press callbacks', (tester) async {
      var taps = 0;
      var longPresses = 0;
      await tester.pumpWidget(
        oneBitApp(
          OneBitCard(
            onTap: () => taps++,
            onLongPress: () => longPresses++,
            child: const Text('content'),
          ),
        ),
      );
      await tester.tap(find.text('content'));
      await tester.longPress(find.text('content'));
      expect(taps, 1);
      expect(longPresses, 1);
    });

    testWidgets('compact uses token padding, default uses card padding', (
      tester,
    ) async {
      await tester.pumpWidget(oneBitApp(const OneBitCard(child: Text('a'))));
      final defaultPadding = tester.widget<Padding>(
        find.ancestor(of: find.text('a'), matching: find.byType(Padding)).first,
      );
      expect(defaultPadding.padding, OneBitCardTokens.contentPadding);

      await tester.pumpWidget(
        oneBitApp(const OneBitCard(compact: true, child: Text('b'))),
      );
      final compactPadding = tester.widget<Padding>(
        find.ancestor(of: find.text('b'), matching: find.byType(Padding)).first,
      );
      expect(compactPadding.padding, OneBitCardTokens.contentPaddingCompact);
    });

    testWidgets('outlined cards use the highest container surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitCard(outlined: true, child: Text('content'))),
      );
      final scheme = Theme.of(tester.element(find.text('content')));
      final container = tester.widget<Ink>(
        find
            .ancestor(of: find.text('content'), matching: find.byType(Ink))
            .first,
      );
      expect(
        (container.decoration! as BoxDecoration).color,
        scheme.colorScheme.surfaceContainerHighest,
      );
    });
  });
}
