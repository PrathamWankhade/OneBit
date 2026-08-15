import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/logger/log_record.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_connection_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_views.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_providers.dart';

/// Scan controls, device list and per-device links.
final class ScanPanel extends ConsumerWidget {
  const ScanPanel({required this.scan, required this.links, super.key});

  final BluetoothScanView scan;
  final BluetoothLinksView links;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FilledButton(
                  onPressed: scan.scanning
                      ? null
                      : () => ref
                            .read(bluetoothScanControllerProvider.notifier)
                            .startScan(),
                  child: const Text('Start scan'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: scan.scanning
                      ? () => ref
                            .read(bluetoothScanControllerProvider.notifier)
                            .stopScan()
                      : null,
                  child: const Text('Stop scan'),
                ),
                const SizedBox(width: 8),
                Text(
                  scan.scanning ? 'scanning…' : 'idle',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Devices (${scan.devices.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final device in scan.devices)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(device.name ?? device.id),
                subtitle: Text(
                  '${device.id}  '
                  '${_stateOf(links, device.id)}  '
                  '${_rssiOf(links, device.id)} dBm',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: _connectedOf(links, device.id)
                    ? TextButton(
                        onPressed: () => ref
                            .read(bluetoothMachineControllerProvider.notifier)
                            .disconnect(device.id),
                        child: const Text('Disconnect'),
                      )
                    : TextButton(
                        onPressed: () => ref
                            .read(bluetoothMachineControllerProvider.notifier)
                            .connect(device.id),
                        child: const Text('Connect'),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  String _stateOf(BluetoothLinksView links, String id) =>
      links.connections[id]?.rawName ?? 'idle';

  String _rssiOf(BluetoothLinksView links, String id) =>
      links.rssi[id] == null ? '—' : '${links.rssi[id]!.rssiDb}';

  bool _connectedOf(BluetoothLinksView links, String id) {
    final state = links.connections[id];
    return state != null &&
        state != BluetoothConnectionState.idle &&
        state != BluetoothConnectionState.disconnected;
  }
}

/// Native/transport log lines.
final class LogsPanel extends StatelessWidget {
  const LogsPanel({required this.logs, super.key});

  final List<LogRecord> logs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Logs', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            if (logs.isEmpty)
              Text(
                'No log lines yet.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              for (final record in logs)
                Text(
                  '${record.time.toIso8601String().substring(11, 19)} '
                  '${record.tag ?? ''} ${record.level.name}  ${record.message}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          ],
        ),
      ),
    );
  }
}
