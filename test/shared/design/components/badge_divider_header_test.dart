import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_badge.dart';
import 'package:onebit/shared/design_system/components/onebit_divider.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import '../support/design_support.dart';

void main() {
  group('OneBitBadge', () {
    testWidgets('renders the count', (tester) async {
      await tester.pumpWidget(oneBitApp(const OneBitBadge(count: 5)));
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('clamps counts above 99', (tester) async {
      await tester.pumpWidget(oneBitApp(const OneBitBadge(count: 150)));
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('hides for null or zero counts unless showZero', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(
          const Column(
            children: [
              OneBitBadge(count: null),
              OneBitBadge(count: 0),
              OneBitBadge(count: 0, showZero: true),
            ],
          ),
        ),
      );
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('announces a custom semantic label', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitBadge(count: 3, semanticsLabel: '3 pings')),
      );
      final semantics = tester.getSemantics(find.byType(OneBitBadge));
      expect(semantics, isSemantics(label: '3 pings'));
    });
  });

  group('OneBitDivider', () {
    testWidgets('renders a hairline divider from the theme', (tester) async {
      await tester.pumpWidget(oneBitApp(const OneBitDivider()));
      final divider = tester.widget<Divider>(find.byType(Divider));
      expect(divider.thickness, isNull);
    });

    testWidgets('forwards indentation', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitDivider(indent: 16, endIndent: 24)),
      );
      final divider = tester.widget<Divider>(find.byType(Divider));
      expect(divider.indent, 16);
      expect(divider.endIndent, 24);
    });
  });

  group('OneBitSectionHeader', () {
    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitSectionHeader(title: 'NEIGHBORS', subtitle: '2 in range'),
        ),
      );
      expect(find.text('NEIGHBORS'), findsOneWidget);
      expect(find.text('2 in range'), findsOneWidget);
    });

    testWidgets('renders the trailing action', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitSectionHeader(
            title: 'NEIGHBORS',
            trailing: Icon(Icons.add),
          ),
        ),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });
}
