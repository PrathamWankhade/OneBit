import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/responsive/onebit_responsive.dart';

void main() {
  group('OneBitBreakpoint classification', () {
    Future<OneBitBreakpoint> classify(WidgetTester tester, double width) async {
      OneBitBreakpoint? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = context.breakpoint;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();
      return result!;
    }

    testWidgets('phones classify as compact', (tester) async {
      expect(await classify(tester, 400), OneBitBreakpoint.compact);
      expect(await classify(tester, 599), OneBitBreakpoint.compact);
    });

    testWidgets('large phones, foldables and small tablets are medium', (
      tester,
    ) async {
      expect(await classify(tester, 600), OneBitBreakpoint.medium);
      expect(await classify(tester, 720), OneBitBreakpoint.medium);
      expect(await classify(tester, 839), OneBitBreakpoint.medium);
    });

    testWidgets('tablets and desktop windows are expanded', (tester) async {
      expect(await classify(tester, 840), OneBitBreakpoint.expanded);
      expect(await classify(tester, 1024), OneBitBreakpoint.expanded);
    });

    testWidgets('compact viewports use a bottom navigation bar', (
      tester,
    ) async {
      expect(OneBitBreakpoint.compact.usesBottomNavigation, isTrue);
      expect(OneBitBreakpoint.medium.usesBottomNavigation, isFalse);
      expect(OneBitBreakpoint.expanded.usesBottomNavigation, isFalse);
    });
  });

  group('OneBitResponsiveContextX', () {
    Future<bool> isTabletAt(WidgetTester tester, double width) async {
      var result = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = context.isTablet;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();
      return result;
    }

    testWidgets('isTablet distinguishes compact from larger layouts', (
      tester,
    ) async {
      expect(await isTabletAt(tester, 400), isFalse);
      expect(await isTabletAt(tester, 720), isTrue);
      expect(await isTabletAt(tester, 1200), isTrue);
    });
  });

  group('OneBitResponsiveLayout', () {
    testWidgets('selects the compact builder on phone widths', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OneBitResponsiveLayout(
            compact: (_) => const Text('compact-branch'),
            medium: (_) => const Text('medium-branch'),
            expanded: (_) => const Text('expanded-branch'),
          ),
        ),
      );
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();
      expect(find.text('compact-branch'), findsOneWidget);
    });

    testWidgets('expanded builder wins on tablet widths', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OneBitResponsiveLayout(
            compact: (_) => const Text('compact-branch'),
            medium: (_) => const Text('medium-branch'),
            expanded: (_) => const Text('expanded-branch'),
          ),
        ),
      );
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();
      expect(find.text('expanded-branch'), findsOneWidget);
    });

    testWidgets('medium falls back to compact when not provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OneBitResponsiveLayout(
            compact: (_) => const Text('compact-branch'),
          ),
        ),
      );
      tester.view.physicalSize = const Size(720, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();
      expect(find.text('compact-branch'), findsOneWidget);
    });
  });
}
