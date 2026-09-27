import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/theme/app_motion.dart';

/// Finds the [Opacity] that [MotionEnter] puts above [finder], rather than
/// any stray Opacity Flutter may render elsewhere in the tree.
Finder entranceOpacityFor(Finder finder) => find.ancestor(
      of: finder,
      matching: find.byType(Opacity),
    );

void main() {
  group('MotionEnter', () {
    testWidgets('fades content in instead of showing it outright',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MotionEnter(child: Text('Incoming')),
          ),
        ),
      );

      // First frame: still travelling, so it is not fully opaque yet.
      final starting = tester.widget<Opacity>(
        entranceOpacityFor(find.text('Incoming')),
      );
      expect(starting.opacity, lessThan(1.0));

      await tester.pump(kMotionBase + const Duration(milliseconds: 50));

      final settled = tester.widget<Opacity>(
        entranceOpacityFor(find.text('Incoming')),
      );
      expect(settled.opacity, 1.0);
    });

    testWidgets('stays out of the way when animations are disabled',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: MotionEnter(child: Text('Instant')),
            ),
          ),
        ),
      );

      // No Opacity wrapper at all: reduced motion gets the plain child.
      expect(
        entranceOpacityFor(find.text('Instant')),
        findsNothing,
      );
      expect(find.text('Instant'), findsOneWidget);
    });

    testWidgets('leaves content visible for the whole test window',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MotionEnter(child: Text('Tappable')),
          ),
        ),
      );

      // Hit testing must work while the entrance is still running.
      await tester.tap(find.text('Tappable'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('MotionCrossFade', () {
    testWidgets('replaces the outgoing child rather than cutting',
        (tester) async {
      const first = MotionCrossFade(child: Text('First', key: ValueKey('1')));
      const second = MotionCrossFade(child: Text('Second', key: ValueKey('2')));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: first)),
      );
      expect(find.text('First'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: second)),
      );
      expect(find.text('Second'), findsOneWidget);

      await tester.pump(kMotionFast + const Duration(milliseconds: 50));

      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
    });
  });
}
