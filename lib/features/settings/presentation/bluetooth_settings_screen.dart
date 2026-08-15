import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_permission_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_radio_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_state.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Bluetooth settings: display current adapter state, permission status,
/// and scanning/connection information. Read-only; no BLE implementation.
class BluetoothSettingsScreen extends ConsumerWidget {
  const BluetoothSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final radioAsync = ref.watch(bluetoothRadioControllerProvider);
    final machineView = ref.watch(bluetoothMachineControllerProvider);

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.settingsBluetoothTitle)),
      body: ListView(
        padding: const EdgeInsets.all(OneBitSpacing.m),
        children: [
          OneBitSectionHeader(title: l10n.settingsBluetoothStateLabel),
          radioAsync.when(
            loading: () => const OneBitCard(
              child: SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => OneBitCard(
              child: Text(
                l10n.commonError,
                style: context.textTheme.bodyMedium,
              ),
            ),
            data: (snapshot) {
              final btState = _resolveState(
                snapshot.radio,
                snapshot.permission,
              );
              return _BluetoothStateCard(
                state: btState,
                radio: snapshot.radio,
                permission: snapshot.permission,
              );
            },
          ),
          const SizedBox(height: OneBitSpacing.m),
          OneBitSectionHeader(title: l10n.settingsBluetoothDescription),
          _ConnectionInfoCard(machineState: machineView.state),
        ],
      ),
    );
  }

  BluetoothState _resolveState(
    BluetoothRadioState radio,
    BluetoothPermissionState permission,
  ) {
    if (radio == BluetoothRadioState.off) return BluetoothState.bluetoothOff;
    if (radio == BluetoothRadioState.unknown) {
      return BluetoothState.bluetoothUnavailable;
    }
    if (permission == BluetoothPermissionState.denied ||
        permission == BluetoothPermissionState.deniedForever) {
      return BluetoothState.error;
    }
    return BluetoothState.ready;
  }
}

class _BluetoothStateCard extends StatelessWidget {
  const _BluetoothStateCard({
    required this.state,
    required this.radio,
    required this.permission,
  });

  final BluetoothState state;
  final BluetoothRadioState radio;
  final BluetoothPermissionState permission;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    final preset = switch (state) {
      BluetoothState.ready ||
      BluetoothState.scanning ||
      BluetoothState.advertising => OneBitStatusPreset.online,
      BluetoothState.connected ||
      BluetoothState.linkReady => OneBitStatusPreset.online,
      BluetoothState.bluetoothOff => OneBitStatusPreset.offline,
      BluetoothState.bluetoothUnavailable => OneBitStatusPreset.offline,
      BluetoothState.error => OneBitStatusPreset.failed,
      _ => OneBitStatusPreset.pending,
    };

    final label = switch (state) {
      BluetoothState.bluetoothOff => l10n.settingsBluetoothDisabled,
      BluetoothState.bluetoothUnavailable => l10n.settingsBluetoothUnavailable,
      BluetoothState.error => l10n.settingsBluetoothPermissionDenied,
      BluetoothState.scanning => l10n.settingsBluetoothScanning,
      BluetoothState.connected ||
      BluetoothState.linkReady => l10n.settingsBluetoothConnected,
      _ => l10n.settingsBluetoothEnabled,
    };

    return OneBitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(OneBitIcons.bluetooth, color: scheme.onSurfaceVariant),
              const SizedBox(width: OneBitSpacing.s),
              Expanded(
                child: Text(
                  l10n.settingsBluetoothTitle,
                  style: context.textTheme.titleMedium,
                ),
              ),
              OneBitStatusChip.preset(preset, label: label),
            ],
          ),
          const SizedBox(height: OneBitSpacing.s),
          _InfoRow(label: l10n.settingsBluetoothStateLabel, value: label),
          _InfoRow(label: 'Radio', value: radio.name),
          _InfoRow(label: 'Permission', value: permission.name),
        ],
      ),
    );
  }
}

class _ConnectionInfoCard extends StatelessWidget {
  const _ConnectionInfoCard({required this.machineState});

  final BluetoothState machineState;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    final connectionPreset = switch (machineState) {
      BluetoothState.connected ||
      BluetoothState.linkReady => OneBitStatusPreset.online,
      BluetoothState.scanning => OneBitStatusPreset.pending,
      BluetoothState.advertising => OneBitStatusPreset.pending,
      _ => OneBitStatusPreset.offline,
    };

    final connectionLabel = switch (machineState) {
      BluetoothState.connected => l10n.meshConnectionConnected,
      BluetoothState.scanning => l10n.settingsBluetoothScanning,
      BluetoothState.advertising => l10n.meshConnectionAdvertising,
      BluetoothState.connecting => l10n.meshConnectionConnecting,
      BluetoothState.disconnecting => l10n.meshConnectionDisconnecting,
      BluetoothState.disconnected => l10n.meshConnectionDisconnected,
      _ => machineState.name,
    };

    return OneBitCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.meshConnectionStateTitle,
                  style: context.textTheme.titleSmall,
                ),
                const SizedBox(height: OneBitSpacing.xs),
                Text(
                  connectionLabel,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          OneBitStatusChip.preset(connectionPreset),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: OneBitTypography.technicalStyle(
              fontSize: OneBitTypography.caption,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
