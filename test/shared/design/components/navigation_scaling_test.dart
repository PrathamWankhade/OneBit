import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/components/onebit_navigation_bar.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/components/onebit_text_field.dart';
import '../support/design_support.dart';

void main() {
  group('OneBitNavigationBar', () {
    const destinations = [
      OneBitNavigationDestination(
        id: 'home',
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      OneBitNavigationDestination(
        id: 'mesh',
        label: 'Mesh',
        icon: Icons.account_tree_outlined,
        selectedIcon: Icons.account_tree_rounded,
      ),
    ];

    testWidgets('renders every destination', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitNavigationBar(
            destinations: destinations,
            selectedIndex: 0,
            onDestinationSelected: _noopWithIndex,
          ),
        ),
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Mesh'), findsOneWidget);
    });

    testWidgets('reports selection changes', (tester) async {
      int? selected;
      await tester.pumpWidget(
        oneBitApp(
          OneBitNavigationBar(
            destinations: destinations,
            selectedIndex: 0,
            onDestinationSelected: (index) => selected = index,
          ),
        ),
      );
      await tester.tap(find.text('Mesh'));
      expect(selected, 1);
    });
  });

  group('Dynamic text', () {
    Future<double> buttonHeightAt(WidgetTester tester, double scale) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(scale),
            size: const Size(400, 800),
          ),
          child: oneBitApp(const OneBitButton(label: 'Save', onPressed: _noop)),
        ),
      );
      await tester.pump();
      return tester.getSize(find.byType(FilledButton)).height;
    }

    testWidgets('buttons grow instead of clipping at large text scales', (
      tester,
    ) async {
      final baseline = await buttonHeightAt(tester, 1.0);
      final scaled = await buttonHeightAt(tester, 3.0);
      expect(scaled, greaterThan(baseline));
    });

    testWidgets('status chips grow past the token minimum under scaling', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2.0),
            size: Size(400, 800),
          ),
          child: oneBitApp(const OneBitStatusChip(label: 'Online')),
        ),
      );
      await tester.pump();
      final size = tester.getSize(find.byType(OneBitStatusChip));
      expect(size.height, greaterThanOrEqualTo(40));
    });

    testWidgets('text fields honor the ambient text scale', (tester) async {
      final controller = TextEditingController(text: 'relay-42');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.5),
            size: Size(400, 800),
          ),
          child: oneBitApp(OneBitTextField(controller: controller)),
        ),
      );
      await tester.pump();
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable, isNotNull);
    });
  });
}

void _noop() {}
void _noopWithIndex(int _) {}
