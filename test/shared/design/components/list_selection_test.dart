import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_list_item.dart';
import 'package:onebit/shared/design_system/components/onebit_selection_controls.dart';
import '../support/design_support.dart';

void main() {
  group('OneBitListItem', () {
    testWidgets('renders title, subtitle and trailing', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitListItem(
            title: 'Relay Alpha',
            subtitle: '0x8F2A:11',
            leading: Icons.circle,
            trailing: Text('2 min'),
            showChevron: true,
          ),
        ),
      );
      expect(find.text('Relay Alpha'), findsOneWidget);
      expect(find.text('0x8F2A:11'), findsOneWidget);
      expect(find.text('2 min'), findsOneWidget);
      expect(find.byIcon(Icons.circle), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('keeps the 48dp minimum target', (tester) async {
      await tester.pumpWidget(oneBitApp(const OneBitListItem(title: 'Row')));
      final size = tester.getSize(find.byType(OneBitListItem));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('fires taps and disables without onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        oneBitApp(OneBitListItem(title: 'Row', onTap: () => taps++)),
      );
      await tester.tap(find.text('Row'));
      expect(taps, 1);

      await tester.pumpWidget(oneBitApp(const OneBitListItem(title: 'Row')));
      await tester.tap(find.text('Row'), warnIfMissed: false);
      expect(taps, 1);
    });
  });

  group('OneBitCheckbox', () {
    testWidgets('toggles through the callback', (tester) async {
      var value = true;
      await tester.pumpWidget(
        oneBitApp(
          OneBitCheckbox(
            value: value,
            label: 'Mute channel',
            onChanged: (next) => value = next ?? false,
          ),
        ),
      );
      expect(find.byType(Checkbox), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      expect(value, isFalse);
    });

    testWidgets('exposes the semantic label', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitCheckbox(value: true, label: 'Offline-first')),
      );
      final semantics = tester.getSemantics(find.byType(OneBitCheckbox));
      expect(semantics, isSemantics(label: 'Offline-first'));
    });
  });

  group('OneBitSwitch', () {
    testWidgets('toggles through the callback', (tester) async {
      var value = false;
      await tester.pumpWidget(
        oneBitApp(
          OneBitSwitch(
            value: value,
            label: 'Relay',
            onChanged: (next) => value = next,
          ),
        ),
      );
      await tester.tap(find.byType(Switch));
      expect(value, isTrue);
    });

    testWidgets('disabled when onChanged is null', (tester) async {
      await tester.pumpWidget(oneBitApp(const OneBitSwitch(value: true)));
      final control = tester.widget<Switch>(find.byType(Switch));
      expect(control.onChanged, isNull);
    });
  });

  group('OneBitRadio', () {
    testWidgets('reports selection through the callback', (tester) async {
      String? selected;
      await tester.pumpWidget(
        oneBitApp(
          Row(
            children: [
              OneBitRadio<String>(
                value: 'a',
                groupValue: selected,
                onChanged: (next) => selected = next,
              ),
              OneBitRadio<String>(
                value: 'b',
                groupValue: selected,
                onChanged: (next) => selected = next,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(Radio<String>).first);
      expect(selected, 'a');
    });

    testWidgets('exposes the semantic label', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitRadio<String>(value: 'a', groupValue: 'a', label: 'Fast'),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitRadio<String>));
      expect(semantics, isSemantics(label: 'Fast'));
    });

    testWidgets('large text scaling keeps targets usable', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2.0),
            size: Size(400, 800),
          ),
          child: oneBitApp(const OneBitCheckbox(value: true, label: 'Relay')),
        ),
      );
      await tester.pump();
      final checkbox = tester.getSize(find.byType(Checkbox));
      expect(checkbox.width, greaterThanOrEqualTo(48));
      expect(checkbox.height, greaterThanOrEqualTo(48));
    });
  });
}
