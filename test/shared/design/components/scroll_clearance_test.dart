import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

void main() {
  group('OneBitScrollClearance', () {
    testWidgets('bottom returns correct clearance for light theme', (
      tester,
    ) async {
      double? clearance;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              clearance = OneBitScrollClearance.bottom(context);
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );
      expect(clearance, isNotNull);
      expect(
        clearance,
        greaterThanOrEqualTo(
          OneBitFloatingNavigationTokens.barHeight +
              OneBitFloatingNavigationTokens.barBottomMargin +
              OneBitFloatingNavigationTokens.readingGap,
        ),
      );
    });

    testWidgets('bottom returns correct clearance for dark theme', (
      tester,
    ) async {
      double? clearance;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              clearance = OneBitScrollClearance.bottom(context);
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );
      expect(clearance, isNotNull);
      expect(
        clearance,
        greaterThanOrEqualTo(
          OneBitFloatingNavigationTokens.barHeight +
              OneBitFloatingNavigationTokens.barBottomMargin +
              OneBitFloatingNavigationTokens.readingGap,
        ),
      );
    });

    testWidgets('bottom accounts for safe area inset', (tester) async {
      double? clearance;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
            child: Builder(
              builder: (context) {
                clearance = OneBitScrollClearance.bottom(context);
                return const Scaffold(body: SizedBox());
              },
            ),
          ),
        ),
      );
      expect(clearance, isNotNull);
      // Should include the 34px safe area inset
      expect(
        clearance,
        greaterThanOrEqualTo(
          OneBitFloatingNavigationTokens.barHeight +
              OneBitFloatingNavigationTokens.barBottomMargin +
              34 + // safe area
              OneBitFloatingNavigationTokens.readingGap,
        ),
      );
    });

    test('clearance tokens are consistent', () {
      // The floating navigation bar height should be at least 60dp
      expect(
        OneBitFloatingNavigationTokens.barHeight,
        greaterThanOrEqualTo(60),
      );
      // The bottom margin should be 16dp
      expect(OneBitFloatingNavigationTokens.barBottomMargin, 16);
      // The reading gap should be at least 24dp
      expect(
        OneBitFloatingNavigationTokens.readingGap,
        greaterThanOrEqualTo(24),
      );
    });

    testWidgets('scrollable content gets proper bottom padding', (
      tester,
    ) async {
      final items = List.generate(20, (i) => 'Item $i');
      double? clearance;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                clearance = OneBitScrollClearance.bottom(context);
                return ListView.builder(
                  padding: EdgeInsets.only(bottom: clearance ?? 0),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return SizedBox(
                      height: 50,
                      child: Center(child: Text(items[index])),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verify the padding was applied
      expect(clearance, isNotNull);
      expect(clearance, greaterThanOrEqualTo(100));
    });

    testWidgets('ListView preserve maintains existing padding', (tester) async {
      const existing = EdgeInsets.fromLTRB(16, 8, 16, 0);
      EdgeInsets? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              result = OneBitScrollClearance.preserve(
                context: context,
                existing: existing,
              );
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );
      expect(result, isNotNull);
      expect(result?.left, existing.left);
      expect(result?.top, existing.top);
      expect(result?.right, existing.right);
      expect(
        result?.bottom,
        greaterThanOrEqualTo(
          OneBitFloatingNavigationTokens.barHeight +
              OneBitFloatingNavigationTokens.barBottomMargin +
              OneBitFloatingNavigationTokens.readingGap,
        ),
      );
    });
  });
}
