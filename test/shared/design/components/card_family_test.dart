import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/components/onebit_diagnostic_card.dart';
import 'package:onebit/shared/design_system/components/onebit_mesh_card.dart';
import 'package:onebit/shared/design_system/components/onebit_node_card.dart';
import 'package:onebit/shared/design_system/components/onebit_settings_card.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/components/onebit_technical_card.dart';
import '../support/design_support.dart';

void main() {
  group('OneBitNodeCard', () {
    Widget card() => oneBitApp(
      const OneBitNodeCard(
        name: 'Relay-42',
        nodeId: '0x8F2A:11',
        fingerprint: 'A1:B2:C3:D4:E5',
        verification: OneBitStatusPreset.verified,
        connection: OneBitStatusPreset.online,
        rssi: -62,
        lastSeen: '2 min ago',
      ),
    );

    testWidgets('renders name, id and technical details', (tester) async {
      await tester.pumpWidget(card());
      expect(find.text('Relay-42'), findsOneWidget);
      expect(find.text('0x8F2A:11'), findsOneWidget);
      expect(find.text('A1:B2:C3:D4:E5'), findsOneWidget);
      expect(find.text('-62 dBm'), findsOneWidget);
      expect(find.text('2 min ago'), findsOneWidget);
    });

    testWidgets('status chips announce their labels', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitNodeCard(
            name: 'N',
            nodeId: '1',
            verification: OneBitStatusPreset.unverified,
            connection: OneBitStatusPreset.connecting,
          ),
        ),
      );
      final semantics = tester.getSemantics(
        find.ancestor(
          of: find.text('Unverified'),
          matching: find.byType(OneBitStatusChip),
        ),
      );
      expect(semantics, isSemantics(label: 'Unverified'));
      expect(find.text('Connecting'), findsOneWidget);
    });

    testWidgets('fires tap on the card surface', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        oneBitApp(OneBitNodeCard(name: 'N', nodeId: '1', onTap: () => taps++)),
      );
      await tester.tap(find.text('N'));
      expect(taps, 1);
    });

    testWidgets('hides optional rows when absent', (tester) async {
      await tester.pumpWidget(
        oneBitApp(const OneBitNodeCard(name: 'N', nodeId: '1')),
      );
      expect(find.text('-62 dBm'), findsNothing);
      expect(find.text('2 min ago'), findsNothing);
    });

    testWidgets('grows with large text instead of clipping', (tester) async {
      final controller = await _heightAt(tester, 1.0, card);
      final scaled = await _heightAt(tester, 2.0, card);
      expect(scaled, greaterThan(controller));
    });
  });

  group('OneBitMeshCard', () {
    testWidgets('renders the status chip and stats', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitMeshCard(
            networkStatus: OneBitStatusPreset.online,
            activeNodes: 12,
            routes: 8,
            rssi: -55,
            latency: '38 ms',
            packets: '1.2k',
          ),
        ),
      );
      expect(find.text('Mesh'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('-55'), findsOneWidget);
      expect(find.text('38 ms'), findsOneWidget);
      expect(find.text('1.2k'), findsOneWidget);
      expect(find.text('Nodes'), findsOneWidget);
    });

    testWidgets('renders in the dark identity', (tester) async {
      await tester.pumpWidget(
        oneBitDarkApp(
          const OneBitMeshCard(networkStatus: OneBitStatusPreset.offline),
        ),
      );
      expect(find.text('Mesh'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
    });
  });

  group('OneBitSettingsCard', () {
    testWidgets('renders title, icon and trailing', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitSettingsCard(
            title: 'Radio',
            icon: Icons.bluetooth,
            subtitle: 'BLE 5.0',
            trailing: OneBitStatusChip(
              label: 'Online',
              tone: OneBitStatusTone.success,
            ),
          ),
        ),
      );
      expect(find.text('Radio'), findsOneWidget);
      expect(find.text('BLE 5.0'), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
    });

    testWidgets('disabled row blocks taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        oneBitApp(
          OneBitSettingsCard(
            title: 'Radio',
            enabled: false,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('Radio'), warnIfMissed: false);
      expect(taps, 0);
    });
  });

  group('OneBitDiagnosticCard', () {
    testWidgets('renders ordered key/value rows', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitDiagnosticCard(
            title: 'Identity',
            rows: [
              MapEntry('node_id', '0x8F2A:11'),
              MapEntry('cipher', 'XChaCha20'),
            ],
          ),
        ),
      );
      expect(find.text('Identity'), findsOneWidget);
      expect(find.text('node_id'), findsOneWidget);
      expect(find.text('0x8F2A:11'), findsOneWidget);
      expect(find.text('cipher'), findsOneWidget);
      expect(find.text('XChaCha20'), findsOneWidget);
    });
  });

  group('OneBitTechnicalCard', () {
    testWidgets('renders mono content and optional header', (tester) async {
      await tester.pumpWidget(
        oneBitApp(
          const OneBitTechnicalCard(
            title: 'log.txt',
            content: '2026-08-11 10:00 relay hello',
          ),
        ),
      );
      expect(find.text('log.txt'), findsOneWidget);
      expect(find.text('2026-08-11 10:00 relay hello'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('dark identity keeps the mono surface', (tester) async {
      await tester.pumpWidget(
        oneBitDarkApp(const OneBitTechnicalCard(content: 'FF:8F')),
      );
      expect(find.byType(SelectableText), findsOneWidget);
    });
  });
}

Future<double> _heightAt(
  WidgetTester tester,
  double scale,
  Widget Function() builder,
) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(scale),
        size: const Size(400, 800),
      ),
      child: builder(),
    ),
  );
  await tester.pump();
  return tester.getSize(find.byType(OneBitNodeCard)).height;
}
