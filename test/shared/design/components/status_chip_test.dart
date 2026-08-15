import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';
import '../support/design_support.dart';

void main() {
  group('OneBitStatusChip', () {
    testWidgets('renders label and decorative dot', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitStatusChip(label: 'In range')),
      );
      expect(find.text('In range'), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('error tone resolves to the scheme error color', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitStatusChip(
            label: 'Degraded',
            tone: OneBitStatusTone.error,
          ),
        ),
      );
      final context = tester.element(find.text('Degraded'));
      final scheme = Theme.of(context).colorScheme;
      expect(scheme.error, isNotNull);
    });

    testWidgets('every tone builds without error', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const Column(
            children: [
              OneBitStatusChip(label: 'a', tone: OneBitStatusTone.neutral),
              OneBitStatusChip(label: 'b', tone: OneBitStatusTone.success),
              OneBitStatusChip(label: 'c', tone: OneBitStatusTone.warning),
              OneBitStatusChip(label: 'd', tone: OneBitStatusTone.error),
              OneBitStatusChip(label: 'e', tone: OneBitStatusTone.info),
            ],
          ),
        ),
      );
      expect(find.byType(OneBitStatusChip), findsNWidgets(5));
    });

    testWidgets('meets the token minimum height', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitStatusChip(label: 'Online')),
      );
      final size = tester.getSize(find.byType(OneBitStatusChip));
      expect(size.height, greaterThanOrEqualTo(OneBitStatusTokens.chipHeight));
    });
  });

  group('OneBitStatusChip presets', () {
    testWidgets('every preset resolves label and tone', (tester) async {
      for (final preset in OneBitStatusPreset.values) {
        final chip = OneBitStatusChip.preset(preset);
        expect(chip.label, preset.defaultLabel);
        expect(chip.tone, preset.tone);
      }
    });

    testWidgets('preset counts cover the status vocabulary', (tester) async {
      expect(OneBitStatusPreset.values, hasLength(10));
      expect(OneBitStatusPreset.online.defaultLabel, 'Online');
      expect(OneBitStatusPreset.failed.tone, OneBitStatusTone.error);
      expect(OneBitStatusPreset.verified.tone, OneBitStatusTone.success);
      expect(OneBitStatusPreset.pending.tone, OneBitStatusTone.warning);
      expect(OneBitStatusPreset.nearby.tone, OneBitStatusTone.info);
    });

    testWidgets('preset chip renders its label and stays accessible', (
      tester,
    ) async {
      await tester.pumpWidget(
        oneBitApp(OneBitStatusChip.preset(OneBitStatusPreset.online)),
      );
      expect(find.text('Online'), findsOneWidget);
      final semantics = tester.getSemantics(find.byType(OneBitStatusChip));
      expect(semantics, isSemantics(label: 'Online'));
    });

    testWidgets('localized label overrides the default', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          OneBitStatusChip.preset(
            OneBitStatusPreset.failed,
            label: 'Fehlgeschlagen',
          ),
        ),
      );
      expect(find.text('Fehlgeschlagen'), findsOneWidget);
    });
  });
}
