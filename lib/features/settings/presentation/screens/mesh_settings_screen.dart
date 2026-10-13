import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/ble/ble_providers.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/settings/data/settings_providers.dart';
import 'package:onebit/features/settings/presentation/widgets/settings_section.dart';
import 'package:onebit/features/settings/presentation/widgets/settings_tile.dart';
import 'package:onebit/features/settings/presentation/widgets/settings_toggle.dart';

class MeshSettingsScreen extends ConsumerWidget {
  const MeshSettingsScreen({super.key});

  /// Highest negotiated MTU across live links, or a dash when nothing has
  /// negotiated one yet (ATT defaults to 23 until then).
  static String _mtuLabel(BleState bleState) {
    final mtus = bleState.connections.values
        .map((c) => c.mtu)
        .whereType<int>()
        .toList();
    if (mtus.isEmpty) return '—';
    return '${mtus.reduce((a, b) => a > b ? a : b)} B';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearbyDiscovery = ref.watch(settingsDiscoveryEnabledProvider);
    final alwaysAdvertise = ref.watch(settingsAlwaysAdvertiseProvider);
    final relayParticipation = ref.watch(settingsRelayEnabledProvider);
    final bleState = ref.watch(bleStateProvider);
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: AppTheme.bgBase,
        title: Text(
          'Mesh & Connectivity',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 8),

          // ── Bluetooth ───────────────────────────────────────
          SettingsSection(
            title: 'Bluetooth',
            children: [
              const SettingsTile(
                icon: Icons.bluetooth,
                title: 'Bluetooth status',
                value: 'ON',
              ),
              SettingsTile(
                icon: Icons.settings,
                title: 'Open Bluetooth settings',
                onTap: () {},
              ),
            ],
          ),

          // ── Discovery ───────────────────────────────────────
          SettingsSection(
            title: 'Discovery',
            children: [
              SettingsToggle(
                icon: Icons.wifi_tethering,
                title: 'Nearby discovery',
                description: 'Allow other devices to discover you via BLE',
                value: nearbyDiscovery,
                onChanged: (v) {
                  ref.read(settingsDiscoveryEnabledProvider.notifier).state =
                      v;
                  ref.read(settingsRepositoryProvider).setDiscoveryEnabled(v);
                },
              ),
              SettingsTile(
                icon: Icons.badge_outlined,
                title: 'Device name for discovery',
                value: 'OneBit',
                onTap: () {},
              ),
              SettingsToggle(
                icon: Icons.visibility_outlined,
                title: 'OneBit visible to others',
                description: 'Show your device in nearby scans',
                value: nearbyDiscovery,
                onChanged: (v) {
                  ref.read(settingsDiscoveryEnabledProvider.notifier).state = v;
                  ref.read(settingsRepositoryProvider).setDiscoveryEnabled(v);
                },
              ),
              SettingsToggle(
                icon: Icons.cell_tower,
                title: 'Advertise continuously',
                description: 'Stay visible without keeping Nearby open',
                value: alwaysAdvertise,
                onChanged: (v) {
                  ref.read(settingsAlwaysAdvertiseProvider.notifier).state = v;
                  ref.read(settingsRepositoryProvider).setAlwaysAdvertise(v);
                },
              ),
            ],
          ),

          // ── Relay ───────────────────────────────────────────
          SettingsSection(
            title: 'Relay',
            children: [
              SettingsToggle(
                icon: Icons.swap_horiz,
                title: 'Relay participation',
                description: 'Help route messages for other peers',
                value: relayParticipation,
                onChanged: (v) {
                  ref.read(settingsRelayEnabledProvider.notifier).state = v;
                  ref.read(settingsRepositoryProvider).setRelayEnabled(v);
                },
              ),
              const SettingsTile(
                icon: Icons.route,
                title: 'Max relay hops',
                value: '2',
              ),
              SettingsTile(
                icon: Icons.battery_3_bar,
                title: 'Relay battery usage',
                value: relayParticipation ? 'Low' : 'None',
              ),
            ],
          ),

          // ── Diagnostics ─────────────────────────────────────
          SettingsSection(
            title: 'Diagnostics',
            children: [
              SettingsTile(
                icon: Icons.device_hub,
                title: 'Active connections',
                value: '${bleState.connections.length}',
              ),
              SettingsTile(
                icon: Icons.radar,
                title: 'Active scan',
                value: bleState.isScanning ? 'Yes' : 'No',
              ),
              SettingsTile(
                icon: Icons.broadcast_on_personal,
                title: 'Advertising',
                value: bleState.isAdvertising ? 'Yes' : 'No',
              ),
              SettingsTile(
                icon: Icons.speed,
                title: 'Negotiated MTU',
                value: _mtuLabel(bleState),
              ),
              SettingsTile(
                icon: Icons.analytics_outlined,
                title: 'View detailed diagnostics',
                onTap: () => context.push('/settings/routing-diagnostics'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
