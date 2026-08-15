import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_channel_card.dart';
import 'package:onebit/shared/design_system/components/onebit_progress.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/components/onebit_transfer_card.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import '../support/design_support.dart';

void main() {
  group('OneBitChannelCard', () {
    testWidgets('renders name, preview, badge and status', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitChannelCard(
            name: 'Relay Alpha',
            unreadCount: 5,
            lastMessage: 'rx id 0x21 seq 42',
            timestamp: '14:32',
            delivery: OneBitStatusPreset.failed,
          ),
        ),
      );
      expect(find.text('Relay Alpha'), findsOneWidget);
      expect(find.text('rx id 0x21 seq 42'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('14:32'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
    });

    testWidgets('pin and mute glyphs render', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitChannelCard(name: 'Alpha', pinned: true, muted: true),
        ),
      );
      expect(find.byIcon(OneBitIcons.pin), findsOneWidget);
      expect(find.byIcon(OneBitIcons.mute), findsOneWidget);
    });

    testWidgets('zero or missing unread renders no badge', (tester) async {
      await tester.pumpWidget(oneBitApp(const OneBitChannelCard(name: 'A')));
      expect(find.text('0'), findsNothing);
    });

    testWidgets('fires tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        oneBitApp(OneBitChannelCard(name: 'Alpha', onTap: () => taps++)),
      );
      await tester.tap(find.text('Alpha'));
      expect(taps, 1);
    });

    testWidgets('renders in the dark identity', (tester) async {
      await tester.pumpWidget(
        oneBitDarkApp(const OneBitChannelCard(name: 'Alpha', unreadCount: 2)),
      );
      expect(find.text('Alpha'), findsOneWidget);
    });
  });

  group('OneBitTransferCard', () {
    testWidgets('renders direction, progress and byte counters', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitTransferCard(
            title: 'node-snapshot.pb',
            direction: OneBitTransferDirection.download,
            progress: 0.5,
            transferred: '12.4 MB',
            total: '24 MB',
            rate: '1.2 MB/s',
          ),
        ),
      );
      expect(find.text('node-snapshot.pb'), findsOneWidget);
      expect(find.byIcon(OneBitIcons.download), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('12.4 MB'), findsOneWidget);
      expect(find.text(' / 24 MB'), findsOneWidget);
      expect(find.text('1.2 MB/s'), findsOneWidget);
    });

    testWidgets('exposes determinate progress to screen readers', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitTransferCard(
            title: 't',
            direction: OneBitTransferDirection.upload,
            progress: 0.25,
          ),
        ),
      );
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, 0.25);
      final semantics = tester.getSemantics(find.byType(OneBitLinearProgress));
      expect(semantics, isSemantics(value: '25 percent'));
    });

    testWidgets('indeterminate when progress is null', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitTransferCard(
            title: 't',
            direction: OneBitTransferDirection.upload,
          ),
        ),
      );
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, isNull);
    });

    testWidgets('renders the status chip preset', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitTransferCard(
            title: 't',
            direction: OneBitTransferDirection.upload,
            status: OneBitStatusPreset.pending,
          ),
        ),
      );
      expect(find.text('Pending'), findsOneWidget);
    });
  });
}
