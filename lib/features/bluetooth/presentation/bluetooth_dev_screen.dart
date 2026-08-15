import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/logger/log_record.dart';
import 'package:onebit/core/logger/logger_providers.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_permission_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_radio_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_repository.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_views.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_dev_screen/widgets/bluetooth_panels.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_providers.dart';

/// Developer testing screen for the Bluetooth transport.
///
/// Not a product screen: it exists to exercise radio, scan, advertising,
/// connections, MTU, RSSI, permissions and to surface the native log lines
/// while developing. It watches the same providers the future mesh UI will
/// consume, so the panels double as contract documentation.
class BluetoothDevScreen extends ConsumerStatefulWidget {
  const BluetoothDevScreen({super.key});

  @override
  ConsumerState<BluetoothDevScreen> createState() => _BluetoothDevScreenState();
}

final class _BluetoothDevScreenState extends ConsumerState<BluetoothDevScreen> {
  Timer? _logTimer;
  List<LogRecord> _logs = const [];

  @override
  void initState() {
    super.initState();
    _logTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final snapshot = ref.read(appLogBufferProvider).snapshot();
      setState(() => _logs = snapshot.reversed.take(40).toList());
    });
  }

  @override
  void dispose() {
    _logTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radio = ref.watch(bluetoothRadioControllerProvider);
    final machine = ref.watch(bluetoothMachineControllerProvider);
    final scan = ref.watch(bluetoothScanControllerProvider);
    final links = ref.watch(bluetoothLinkControllerProvider);
    final permission = ref.watch(bluetoothPermissionControllerProvider);
    final advertising = ref.watch(bluetoothAdvertisingControllerProvider);

    return OneBitScaffold(
      appBar: AppBar(title: const Text('Bluetooth Transport')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _RadioPanel(radio: radio, machine: machine, permission: permission),
          const SizedBox(height: 12),
          _AdvertPanel(view: advertising),
          const SizedBox(height: 12),
          ScanPanel(scan: scan, links: links),
          const SizedBox(height: 12),
          LogsPanel(logs: _logs),
        ],
      ),
    );
  }
}

/// Radio state, permissions and battery-saver card.
final class _RadioPanel extends ConsumerWidget {
  const _RadioPanel({
    required this.radio,
    required this.machine,
    required this.permission,
  });

  final AsyncValue<BluetoothRadioSnapshot> radio;
  final BluetoothMachineView machine;
  final AsyncValue<BluetoothPermissionState> permission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot =
        radio.value ??
        const BluetoothRadioSnapshot(
          radio: BluetoothRadioState.unknown,
          permission: BluetoothPermissionState.notDetermined,
          batterySaver: false,
          maxConcurrentConnections: 1,
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Radio: ${snapshot.radio.rawName}  |  '
              'Permission: ${snapshot.permission.rawName}  |  '
              'Battery saver: ${snapshot.batterySaver}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Machine: ${machine.state.rawName}'
              '${machine.deviceId == null ? '' : '  ● ${machine.deviceId}'}'
              '${machine.state == BluetoothState.linkReady ? '  MTU ${machine.negotiatedMtu}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: () => ref
                      .read(bluetoothRadioControllerProvider.notifier)
                      .refresh(),
                  child: const Text('Refresh'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => ref
                      .read(bluetoothPermissionControllerProvider.notifier)
                      .request(),
                  child: const Text('Request permissions'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => ref
                      .read(bluetoothPermissionControllerProvider.notifier)
                      .recover(),
                  child: const Text('Recover'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Advertising + peripheral GATT server controls.
final class _AdvertPanel extends ConsumerWidget {
  const _AdvertPanel({required this.view});

  final BluetoothAdvertisingView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advertising: ${view.advertising ? 'active ${view.advertisingId}' : 'idle'}  |  '
              'GATT server: ${view.gattServer ? 'up' : 'down'}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: view.advertising
                      ? null
                      : () => ref
                            .read(
                              bluetoothAdvertisingControllerProvider.notifier,
                            )
                            .startAdvertising(),
                  child: const Text('Advertise'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: view.advertising
                      ? () => ref
                            .read(
                              bluetoothAdvertisingControllerProvider.notifier,
                            )
                            .stopAdvertising()
                      : null,
                  child: const Text('Stop'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: view.gattServer
                      ? () => ref
                            .read(
                              bluetoothAdvertisingControllerProvider.notifier,
                            )
                            .stopGattServer()
                      : () => ref
                            .read(
                              bluetoothAdvertisingControllerProvider.notifier,
                            )
                            .startGattServer(),
                  child: Text(
                    view.gattServer ? 'GATT server off' : 'GATT server on',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
