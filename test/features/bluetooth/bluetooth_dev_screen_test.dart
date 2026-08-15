import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/logger/log_output.dart';
import 'package:onebit/core/logger/logger_providers.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_dev_screen.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_providers.dart';

import 'support/fake_bluetooth_platform.dart';

void main() {
  testWidgets('renders radio, scan and log panels', (tester) async {
    final platform = FakeBluetoothPlatform();
    platform.enqueue('getState', Ok(readySnapshot()));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [bluetoothPlatformProvider.overrideWithValue(platform)],
        child: const MaterialApp(home: BluetoothDevScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bluetooth Transport'), findsOneWidget);
    expect(find.textContaining('Radio: ready'), findsOneWidget);
    expect(find.textContaining('Permission: granted'), findsOneWidget);
    expect(find.text('Start scan'), findsOneWidget);
    expect(find.text('Stop scan'), findsOneWidget);
    expect(find.text('Request permissions'), findsOneWidget);
    expect(find.text('Recover'), findsOneWidget);
    expect(find.text('Advertise'), findsOneWidget);
    expect(find.text('GATT server on'), findsOneWidget);
    expect(find.text('Logs'), findsOneWidget);

    platform.dispose();
  });

  testWidgets('scan panel lists discovered devices', (tester) async {
    final platform = FakeBluetoothPlatform();
    platform.enqueue('getState', Ok(readySnapshot()));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [bluetoothPlatformProvider.overrideWithValue(platform)],
        child: const MaterialApp(home: BluetoothDevScreen()),
      ),
    );
    await tester.pumpAndSettle();

    platform.emit({
      'event': 'scanResult',
      'result': {
        'device': {'id': 'd-1', 'name': 'onebit-node'},
        'rssiDb': -55,
        'timestamp': 1,
        'connectable': true,
      },
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('onebit-node'), findsOneWidget);
    expect(find.textContaining('d-1'), findsWidgets);

    platform.dispose();
  });

  testWidgets('logs panel falls back to a friendly empty state', (
    tester,
  ) async {
    final platform = FakeBluetoothPlatform();
    platform.enqueue('getState', Ok(readySnapshot()));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bluetoothPlatformProvider.overrideWithValue(platform),
          appLogBufferProvider.overrideWithValue(BufferLogOutput()),
        ],
        child: const MaterialApp(home: BluetoothDevScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No log lines yet.'), findsOneWidget);

    platform.dispose();
  });
}
