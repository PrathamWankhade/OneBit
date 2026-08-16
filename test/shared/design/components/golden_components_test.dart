import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/theme/onebit_theme.dart';
import 'package:onebit/shared/design_system/components/onebit_badge.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_list_item.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_offline_state.dart';
import 'package:onebit/shared/design_system/components/onebit_permission_state.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';

const _phoneSize = Size(390, 844);

MaterialApp _wrapApp(Widget child, {required ThemeData theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: Center(child: SizedBox(width: 390, child: child)),
  ),
);

void main() {
  group('Golden · OneBitButton', () {
    testWidgets('dark theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OneBitButton(label: 'Primary', onPressed: _noop),
              SizedBox(height: 8),
              OneBitButton(
                label: 'Secondary',
                variant: OneBitButtonVariant.secondary,
                onPressed: _noop,
              ),
              SizedBox(height: 8),
              OneBitButton(
                label: 'Tonal',
                variant: OneBitButtonVariant.tonal,
                onPressed: _noop,
              ),
              SizedBox(height: 8),
              OneBitButton(
                label: 'Text',
                variant: OneBitButtonVariant.text,
                onPressed: _noop,
              ),
              SizedBox(height: 8),
              OneBitButton(
                label: 'Destructive',
                variant: OneBitButtonVariant.destructive,
                onPressed: _noop,
              ),
              SizedBox(height: 8),
              OneBitButton(label: 'Loading', loading: true, onPressed: _noop),
              SizedBox(height: 8),
              OneBitButton(label: 'Disabled', onPressed: null),
            ],
          ),
          theme: OneBitTheme.dark,
        ),
      );
      // The loading button spins indefinitely; pump a fixed duration instead
      // of pumpAndSettle.
      await tester.pump(const Duration(seconds: 1));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/components/dark/onebit_buttons.png'),
      );
    });

    testWidgets('light theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OneBitButton(label: 'Primary', onPressed: _noop),
              SizedBox(height: 8),
              OneBitButton(
                label: 'Secondary',
                variant: OneBitButtonVariant.secondary,
                onPressed: _noop,
              ),
              SizedBox(height: 8),
              OneBitButton(
                label: 'Tonal',
                variant: OneBitButtonVariant.tonal,
                onPressed: _noop,
              ),
              SizedBox(height: 8),
              OneBitButton(
                label: 'Text',
                variant: OneBitButtonVariant.text,
                onPressed: _noop,
              ),
              SizedBox(height: 8),
              OneBitButton(
                label: 'Destructive',
                variant: OneBitButtonVariant.destructive,
                onPressed: _noop,
              ),
              SizedBox(height: 8),
              OneBitButton(label: 'Loading', loading: true, onPressed: _noop),
              SizedBox(height: 8),
              OneBitButton(label: 'Disabled', onPressed: null),
            ],
          ),
          theme: OneBitTheme.light,
        ),
      );
      // The loading button spins indefinitely; pump a fixed duration instead
      // of pumpAndSettle.
      await tester.pump(const Duration(seconds: 1));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/components/light/onebit_buttons.png'),
      );
    });
  });

  group('Golden · OneBitCard', () {
    testWidgets('dark theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OneBitCard(child: Text('Default card content')),
              SizedBox(height: 8),
              OneBitCard(outlined: true, child: Text('Outlined card')),
              SizedBox(height: 8),
              OneBitCard(compact: true, child: Text('Compact card')),
            ],
          ),
          theme: OneBitTheme.dark,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/components/dark/onebit_cards.png'),
      );
    });

    testWidgets('light theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OneBitCard(child: Text('Default card content')),
              SizedBox(height: 8),
              OneBitCard(outlined: true, child: Text('Outlined card')),
              SizedBox(height: 8),
              OneBitCard(compact: true, child: Text('Compact card')),
            ],
          ),
          theme: OneBitTheme.light,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/components/light/onebit_cards.png'),
      );
    });
  });

  group('Golden · OneBitListItem', () {
    testWidgets('dark theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OneBitListItem(
                title: 'Relay Alpha',
                subtitle: '0x8F2A:11',
                leading: Icons.circle,
                trailing: Text('2 min'),
                showChevron: true,
              ),
              OneBitListItem(title: 'Simple row', subtitle: 'No trailing'),
              OneBitListItem(
                title: 'Tappable row',
                subtitle: 'Has callback',
                onTap: _noop,
                showChevron: true,
              ),
            ],
          ),
          theme: OneBitTheme.dark,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/components/dark/onebit_list_items.png'),
      );
    });

    testWidgets('light theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OneBitListItem(
                title: 'Relay Alpha',
                subtitle: '0x8F2A:11',
                leading: Icons.circle,
                trailing: Text('2 min'),
                showChevron: true,
              ),
              OneBitListItem(title: 'Simple row', subtitle: 'No trailing'),
              OneBitListItem(
                title: 'Tappable row',
                subtitle: 'Has callback',
                onTap: _noop,
                showChevron: true,
              ),
            ],
          ),
          theme: OneBitTheme.light,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/components/light/onebit_list_items.png'),
      );
    });
  });

  group('Golden · OneBitEmptyState', () {
    testWidgets('dark theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const OneBitEmptyState(
            title: 'No nodes nearby',
            message: 'Scanning keeps running in the background.',
          ),
          theme: OneBitTheme.dark,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/components/dark/onebit_empty_state.png'),
      );
    });

    testWidgets('light theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const OneBitEmptyState(
            title: 'No nodes nearby',
            message: 'Scanning keeps running in the background.',
          ),
          theme: OneBitTheme.light,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/components/light/onebit_empty_state.png'),
      );
    });
  });

  group('Golden · OneBitErrorState', () {
    testWidgets('dark theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const OneBitErrorState(
            message: 'Sync failed',
            detail: 'dtn.e2e.timeout',
            onRetry: _noop,
          ),
          theme: OneBitTheme.dark,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/components/dark/onebit_error_state.png'),
      );
    });

    testWidgets('light theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const OneBitErrorState(
            message: 'Sync failed',
            detail: 'dtn.e2e.timeout',
            onRetry: _noop,
          ),
          theme: OneBitTheme.light,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/components/light/onebit_error_state.png'),
      );
    });
  });

  group('Golden · OneBitLoadingIndicator', () {
    testWidgets('dark theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const OneBitLoadingIndicator(label: 'Connecting…'),
          theme: OneBitTheme.dark,
        ),
      );
      // The spinner spins indefinitely; pump a fixed duration instead of
      // pumpAndSettle.
      await tester.pump(const Duration(seconds: 1));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'golden/components/dark/onebit_loading_indicator.png',
        ),
      );
    });

    testWidgets('light theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const OneBitLoadingIndicator(label: 'Connecting…'),
          theme: OneBitTheme.light,
        ),
      );
      // The spinner spins indefinitely; pump a fixed duration instead of
      // pumpAndSettle.
      await tester.pump(const Duration(seconds: 1));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'golden/components/light/onebit_loading_indicator.png',
        ),
      );
    });
  });

  group('Golden · OneBitBadge', () {
    testWidgets('dark theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OneBitBadge(count: 3),
              SizedBox(height: 8),
              OneBitBadge(count: 99),
              SizedBox(height: 8),
              OneBitBadge(count: 150),
            ],
          ),
          theme: OneBitTheme.dark,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/components/dark/onebit_badges.png'),
      );
    });

    testWidgets('light theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OneBitBadge(count: 3),
              SizedBox(height: 8),
              OneBitBadge(count: 99),
              SizedBox(height: 8),
              OneBitBadge(count: 150),
            ],
          ),
          theme: OneBitTheme.light,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/components/light/onebit_badges.png'),
      );
    });
  });

  group('Golden · OneBitStatusChip', () {
    testWidgets('dark theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OneBitStatusChip(label: 'Online', tone: OneBitStatusTone.success),
              SizedBox(height: 8),
              OneBitStatusChip(label: 'Degraded', tone: OneBitStatusTone.error),
              SizedBox(height: 8),
              OneBitStatusChip(
                label: 'Pending',
                tone: OneBitStatusTone.warning,
              ),
              SizedBox(height: 8),
              OneBitStatusChip(
                label: 'Neutral',
                tone: OneBitStatusTone.neutral,
              ),
              SizedBox(height: 8),
              OneBitStatusChip(label: 'Info', tone: OneBitStatusTone.info),
            ],
          ),
          theme: OneBitTheme.dark,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/components/dark/onebit_status_chips.png'),
      );
    });

    testWidgets('light theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OneBitStatusChip(label: 'Online', tone: OneBitStatusTone.success),
              SizedBox(height: 8),
              OneBitStatusChip(label: 'Degraded', tone: OneBitStatusTone.error),
              SizedBox(height: 8),
              OneBitStatusChip(
                label: 'Pending',
                tone: OneBitStatusTone.warning,
              ),
              SizedBox(height: 8),
              OneBitStatusChip(
                label: 'Neutral',
                tone: OneBitStatusTone.neutral,
              ),
              SizedBox(height: 8),
              OneBitStatusChip(label: 'Info', tone: OneBitStatusTone.info),
            ],
          ),
          theme: OneBitTheme.light,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/components/light/onebit_status_chips.png'),
      );
    });
  });

  group('Golden · OneBitOfflineState', () {
    testWidgets('dark theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          OneBitOfflineState(
            title: 'No connection',
            message: 'No transport available.',
            action: OneBitStatusChip.preset(OneBitStatusPreset.offline),
          ),
          theme: OneBitTheme.dark,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/components/dark/onebit_offline_state.png'),
      );
    });

    testWidgets('light theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          OneBitOfflineState(
            title: 'No connection',
            message: 'No transport available.',
            action: OneBitStatusChip.preset(OneBitStatusPreset.offline),
          ),
          theme: OneBitTheme.light,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/components/light/onebit_offline_state.png'),
      );
    });
  });

  group('Golden · OneBitPermissionState', () {
    testWidgets('dark theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const OneBitPermissionState(
            title: 'Bluetooth required',
            message: 'Scanning needs the radio.',
            onRequest: _noop,
          ),
          theme: OneBitTheme.dark,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/components/dark/onebit_permission_state.png'),
      );
    });

    testWidgets('light theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapApp(
          const OneBitPermissionState(
            title: 'Bluetooth required',
            message: 'Scanning needs the radio.',
            onRequest: _noop,
          ),
          theme: OneBitTheme.light,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'golden/components/light/onebit_permission_state.png',
        ),
      );
    });
  });
}

void _noop() {}
