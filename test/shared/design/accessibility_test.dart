import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/accessibility/onebit_accessibility.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';
import 'package:onebit/shared/design_system/components/onebit_badge.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'support/design_support.dart';

void main() {
  group('OneBitAccessibility tokens', () {
    test('interactive targets meet the 48dp guidance', () {
      expect(OneBitAccessibility.minInteractiveSize, 48);
      expect(OneBitAccessibility.minVisualSize, 24);
    });
  });

  group('OneBitTapTarget', () {
    testWidgets('enforces a â‰¥48dp target for compact visuals', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitTapTarget(onTap: _noop, child: Icon(Icons.close)),
        ),
      );
      final size = tester.getSize(find.byType(OneBitTapTarget));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('fires the tap callback', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        oneBitApp(
          OneBitTapTarget(
            onTap: () => tapped++,
            child: const Icon(Icons.close),
          ),
        ),
      );
      await tester.tap(find.byType(OneBitTapTarget));
      expect(tapped, 1);
    });

    testWidgets('exposes the semantic label and button role to TalkBack', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitTapTarget(
            onTap: _noop,
            semanticsLabel: 'Close',
            child: Icon(Icons.close),
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitTapTarget));
      expect(semantics, isSemantics(label: 'Close'));
      expect(semantics, isSemantics(isButton: true));
      expect(semantics, isSemantics(isEnabled: true));
    });
  });

  group('Reduced motion', () {
    testWidgets('OneBitMotion.resolve collapses under disableAnimations', (
      tester,
    ) async {
      Duration? resolved;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              resolved = context.motionDuration(OneBitMotion.medium);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, Duration.zero);
    });

    testWidgets('durations pass through when animations are allowed', (
      tester,
    ) async {
      Duration? resolved;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: Builder(
            builder: (context) {
              resolved = OneBitMotion.resolve(context, OneBitMotion.medium);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, OneBitMotion.medium);
    });
  });

  group('Component semantics', () {
    testWidgets('status chips expose their label to TalkBack', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitStatusChip(label: 'Connected')),
      );
      final semantics = tester.getSemantics(find.byType(OneBitStatusChip));
      expect(semantics, isSemantics(label: 'Connected'));
    });

    testWidgets('badges announce counts', (tester) async {
      await tester.pumpWidget(oneBitApp(const OneBitBadge(count: 5)));
      final semantics = tester.getSemantics(find.byType(OneBitBadge));
      expect(semantics, isSemantics(label: '5 unread items'));
    });

    testWidgets('decorative helper wraps children in ExcludeSemantics', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(OneBitSemantics.decorative(const Icon(Icons.circle))),
      );
      expect(
        find.ancestor(
          of: find.byIcon(Icons.circle),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.circle), findsOneWidget);
    });
  });
}

void _noop() {}
