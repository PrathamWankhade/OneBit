import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_inline_error.dart';
import 'package:onebit/shared/design_system/components/onebit_offline_state.dart';
import 'package:onebit/shared/design_system/components/onebit_permission_state.dart';
import 'package:onebit/shared/design_system/components/onebit_snackbar.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import '../support/design_support.dart';

void main() {
  group('OneBitSnackBars', () {
    testWidgets('shows a neutral message', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () =>
                    OneBitSnackBars.show(context, message: 'Relay cached'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(find.text('Relay cached'), findsOneWidget);
    });

    testWidgets('error variant offers an action', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        oneBitApp(
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => OneBitSnackBars.error(
                  context,
                  message: 'Send failed',
                  actionLabel: 'Retry',
                  onAction: () => retried++,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Send failed'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, 1);
    });
  });

  group('OneBitInlineError', () {
    testWidgets('renders message and retry action', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        oneBitApp(
          OneBitInlineError(
            message: 'Checksum mismatch',
            actionLabel: 'Retry',
            onAction: () => retried++,
          ),
        ),
      );
      expect(find.text('Checksum mismatch'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, 1);
    });

    testWidgets('announces the message live', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitInlineError(message: 'Timed out')),
      );
      final semantics = tester.getSemantics(find.byType(OneBitInlineError));
      expect(semantics, isSemantics(label: 'Timed out'));
    });
  });

  group('OneBitOfflineState', () {
    testWidgets('renders headline, message and action', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          OneBitOfflineState(
            title: 'No connection',
            message: 'No transport available.',
            action: OneBitStatusChip.preset(OneBitStatusPreset.offline),
          ),
        ),
      );
      expect(find.text('No connection'), findsOneWidget);
      expect(find.text('No transport available.'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
    });
  });

  group('OneBitPermissionState', () {
    testWidgets('requests permission', (tester) async {
      var requested = 0;
      await tester.pumpWidget(
        oneBitApp(
          OneBitPermissionState(
            title: 'Bluetooth required',
            message: 'Scanning needs the radio.',
            onRequest: () => requested++,
          ),
        ),
      );
      expect(find.text('Bluetooth required'), findsOneWidget);
      await tester.tap(find.text('Allow'));
      expect(requested, 1);
    });

    testWidgets('denied state shows the settings action', (tester) async {
      var settings = 0;
      await tester.pumpWidget(
        oneBitApp(
          OneBitPermissionState(
            title: 'Bluetooth required',
            message: 'Scanning needs the radio.',
            onRequest: () {},
            denied: true,
            onOpenSettings: () => settings++,
          ),
        ),
      );
      await tester.tap(find.text('Open settings'));
      expect(settings, 1);
    });

    testWidgets('requesting state disables the action', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          OneBitPermissionState(
            title: 'Bluetooth required',
            message: 'Scanning needs the radio.',
            requesting: true,
            onRequest: () {},
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
