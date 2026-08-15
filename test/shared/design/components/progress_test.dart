import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_progress.dart';
import '../support/design_support.dart';

void main() {
  group('OneBitLinearProgress', () {
    testWidgets('renders determinate and indeterminate bars', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const Column(
            children: [
              OneBitLinearProgress(value: 0.5),
              OneBitLinearProgress(),
            ],
          ),
        ),
      );
      final bars = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .toList();
      expect(bars[0].value, 0.5);
      expect(bars[1].value, isNull);
    });

    testWidgets('announces percentage semantics', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitLinearProgress(
            value: 0.25,
            semanticsLabel: 'Downloading firmware',
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(OneBitLinearProgress));
      expect(semantics, isSemantics(label: 'Downloading firmware'));
      expect(semantics, isSemantics(value: '25 percent'));
    });

    testWidgets('renders in the dark identity', (tester) async {
      await tester.pumpWidget(
        oneBitDarkApp(const OneBitLinearProgress(value: 0.5)),
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('OneBitTransferIndicator', () {
    testWidgets('renders direction, counters and cancel', (tester) async {
      var cancelled = 0;
      await tester.pumpWidget(
        oneBitApp(
          OneBitTransferIndicator(
            direction: OneBitTransferDirection.upload,
            progress: 0.4,
            transferred: '4 MB',
            total: '10 MB',
            rate: '2 MB/s',
            onCancel: () => cancelled++,
          ),
        ),
      );
      expect(find.text('Uploading'), findsOneWidget);
      expect(find.text('4 MB / 10 MB'), findsOneWidget);
      expect(find.text('2 MB/s'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(cancelled, 1);
    });

    testWidgets('combined semantics describe the transfer', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitTransferIndicator(
            direction: OneBitTransferDirection.download,
            progress: 0.5,
            transferred: '5 MB',
            total: '10 MB',
          ),
        ),
      );
      final semantics = tester.getSemantics(
        find.byType(OneBitTransferIndicator),
      );
      expect(semantics, isSemantics(value: '50 percent'));
    });

    testWidgets('grows under large text scaling', (tester) async {
      double height() {
        return tester.getSize(find.byKey(const Key('x'))).height;
      }

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.noScaling),
          child: oneBitApp(
            const KeyedSubtree(
              key: Key('x'),
              child: OneBitTransferIndicator(
                direction: OneBitTransferDirection.download,
                progress: 0.5,
                transferred: '5 MB',
                total: '10 MB',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final baseline = height();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: oneBitApp(
            const KeyedSubtree(
              key: Key('x'),
              child: OneBitTransferIndicator(
                direction: OneBitTransferDirection.download,
                progress: 0.5,
                transferred: '5 MB',
                total: '10 MB',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(height(), greaterThan(baseline));
    });
  });
}
