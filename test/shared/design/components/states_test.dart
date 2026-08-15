import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import '../support/design_support.dart';

void main() {
  group('OneBitLoadingIndicator', () {
    testWidgets('shows a spinner with an optional label', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitLoadingIndicator(label: 'Connectingâ€¦')),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Connectingâ€¦'), findsOneWidget);
    });

    testWidgets('renders without a label', (tester) async {
      await tester.pumpWidget(oneBitApp(const OneBitLoadingIndicator()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('OneBitAnimatedProgress', () {
    testWidgets('shows content when idle and spinner while progressing', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitAnimatedProgress(
            inProgress: false,
            child: Text('loaded'),
          ),
        ),
      );
      expect(find.text('loaded'), findsOneWidget);

      await tester.pumpWidget(
        oneBitApp(
          const OneBitAnimatedProgress(inProgress: true, child: Text('loaded')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('OneBitEmptyState', () {
    testWidgets('renders title and message', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitEmptyState(
            title: 'No nodes nearby',
            message: 'Scanning keeps running in the background.',
          ),
        ),
      );
      expect(find.text('No nodes nearby'), findsOneWidget);
      expect(
        find.text('Scanning keeps running in the background.'),
        findsOneWidget,
      );
    });

    testWidgets('renders an action when provided', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitEmptyState(
            title: 'No nodes nearby',
            action: OneBitOutlinedButton(label: 'Scan', onPressed: _noop),
          ),
        ),
      );
      expect(find.text('Scan'), findsOneWidget);
    });
  });

  group('OneBitErrorState', () {
    testWidgets('renders message, detail and retry', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        oneBitApp(
          OneBitErrorState(
            message: 'Sync failed',
            detail: 'dtn.e2e.timeout',
            onRetry: () => retried++,
          ),
        ),
      );
      expect(find.text('Sync failed'), findsOneWidget);
      expect(find.text('dtn.e2e.timeout'), findsOneWidget);
      await tester.tap(find.byType(OutlinedButton));
      expect(retried, 1);
    });

    testWidgets('fromFailure adopts the failure text', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          OneBitErrorState.fromFailure(
            failure: const FormatException('bad row'),
          ),
        ),
      );
      expect(find.text('FormatException: bad row'), findsOneWidget);
      expect(find.text('FormatException'), findsOneWidget);
    });
  });
}

void _noop() {}
