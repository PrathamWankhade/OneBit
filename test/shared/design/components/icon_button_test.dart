import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import '../support/design_support.dart';

void main() {
  group('OneBitIconButton', () {
    testWidgets('renders the icon and fires taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        oneBitApp(OneBitIconButton(icon: Icons.close, onPressed: () => taps++)),
      );
      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      expect(taps, 1);
    });

    testWidgets('guarantees the 48dp interactive target', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitIconButton(icon: Icons.close, onPressed: _noop)),
      );
      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.constraints?.minWidth, 48);
      expect(button.constraints?.minHeight, 48);
    });

    testWidgets('is disabled when onPressed is missing', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitIconButton(icon: Icons.close, onPressed: null)),
      );
      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('provides the tooltip to screen readers', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitIconButton(
            icon: Icons.close,
            tooltip: 'Close panel',
            onPressed: _noop,
          ),
        ),
      );
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Close panel');
    });
  });
}

void _noop() {}
