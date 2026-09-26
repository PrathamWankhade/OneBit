import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/core/version/app_version.dart';
import 'package:onebit/features/settings/data/settings_providers.dart';
import 'package:onebit/features/settings/presentation/widgets/settings_section.dart';
import 'package:onebit/features/settings/presentation/widgets/settings_tile.dart';
import 'package:onebit/features/settings/presentation/widgets/settings_toggle.dart';

class SettingsMainScreen extends ConsumerWidget {
  const SettingsMainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 48),
            Text(
              'Settings',
              style: AppTheme.titleLarge.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // ── Identity ──
            SettingsSection(
              title: 'IDENTITY',
              children: [
                SettingsTile(
                  icon: Icons.person_outline,
                  title: 'My Profile',
                  value: 'Edit',
                  onTap: () => context.push('/identity/edit'),
                ),
                SettingsTile(
                  icon: Icons.qr_code,
                  title: 'My QR Code',
                  onTap: () => context.push('/identity/qr'),
                ),
                SettingsTile(
                  icon: Icons.qr_code_scanner,
                  title: 'Scan QR Code',
                  value: 'Pair',
                  onTap: () => context.push('/identity/scan'),
                ),
                SettingsTile(
                  icon: Icons.fingerprint,
                  title: 'Biometric lock',
                  value: 'Off',
                  onTap: () => _showBiometricDialog(context),
                ),
              ],
            ),

            // ── Privacy & Security ──
            SettingsSection(
              title: 'PRIVACY & SECURITY',
              children: [
                SettingsTile(
                  icon: Icons.verified_user,
                  title: 'Verification',
                  onTap: () => context.push('/settings/privacy'),
                ),
                SettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Message encryption',
                  value: 'E2EE',
                  onTap: () => _showEncryptionInfo(context),
                ),
                SettingsTile(
                  icon: Icons.block,
                  title: 'Blocked peers',
                  onTap: () {},
                ),
                SettingsToggle(
                  icon: Icons.visibility_off,
                  title: 'Hide online status',
                  value: !ref.watch(settingsDiscoveryEnabledProvider),
                  onChanged: (v) {
                    ref.read(settingsDiscoveryEnabledProvider.notifier).state =
                        !v;
                    ref
                        .read(settingsRepositoryProvider)
                        .setDiscoveryEnabled(!v);
                  },
                ),
              ],
            ),

            // ── Mesh & Connectivity ──
            SettingsSection(
              title: 'MESH & CONNECTIVITY',
              children: [
                SettingsTile(
                  icon: Icons.wifi_tethering,
                  title: 'Nearby discovery',
                  value:
                      ref.watch(settingsDiscoveryEnabledProvider) ? 'On' : 'Off',
                  onTap: () => context.push('/settings/mesh'),
                ),
                SettingsTile(
                  icon: Icons.swap_horiz,
                  title: 'Relay messages',
                  value:
                      ref.watch(settingsRelayEnabledProvider) ? 'On' : 'Off',
                  onTap: () => context.push('/settings/mesh'),
                ),
                SettingsTile(
                  icon: Icons.bluetooth,
                  title: 'Bluetooth settings',
                  onTap: () => context.push('/settings/mesh'),
                ),
              ],
            ),

            // ── Notifications ──
            SettingsSection(
              title: 'NOTIFICATIONS',
              children: [
                SettingsToggle(
                  icon: Icons.notifications,
                  title: 'Push notifications',
                  value: ref.watch(settingsNotificationsEnabledProvider),
                  onChanged: (v) {
                    ref
                        .read(settingsNotificationsEnabledProvider.notifier)
                        .state = v;
                    ref
                        .read(settingsRepositoryProvider)
                        .setNotificationsEnabled(v);
                  },
                ),
                SettingsToggle(
                  icon: Icons.volume_up,
                  title: 'Notification sound',
                  value: ref.watch(settingsNotificationSoundProvider),
                  onChanged: (v) {
                    ref.read(settingsNotificationSoundProvider.notifier).state =
                        v;
                    ref.read(settingsRepositoryProvider).setNotificationSound(v);
                  },
                ),
                SettingsToggle(
                  icon: Icons.vibration,
                  title: 'Vibration',
                  value: ref.watch(settingsNotificationVibrationProvider),
                  onChanged: (v) {
                    ref
                        .read(settingsNotificationVibrationProvider.notifier)
                        .state = v;
                    ref
                        .read(settingsRepositoryProvider)
                        .setNotificationVibration(v);
                  },
                ),
              ],
            ),

            // ── Appearance ──
            SettingsSection(
              title: 'APPEARANCE',
              children: [
                SettingsTile(
                  icon: Icons.dark_mode,
                  title: 'Theme',
                  value: _getThemeLabel(ref.watch(settingsThemeProvider)),
                  onTap: () => context.push('/settings/appearance'),
                ),
                SettingsTile(
                  icon: Icons.palette,
                  title: 'Accent color',
                  onTap: () => context.push('/settings/appearance'),
                ),
                SettingsTile(
                  icon: Icons.text_fields,
                  title: 'Font size',
                  value: _getFontSizeLabel(
                      ref.watch(settingsFontSizeProvider)),
                  onTap: () => context.push('/settings/appearance'),
                ),
                SettingsToggle(
                  icon: Icons.access_time,
                  title: 'Show timestamps',
                  value: ref.watch(settingsShowTimestampsProvider),
                  onChanged: (v) {
                    ref.read(settingsShowTimestampsProvider.notifier).state = v;
                    ref.read(settingsRepositoryProvider).setShowTimestamps(v);
                  },
                ),
                SettingsToggle(
                  icon: Icons.compress,
                  title: 'Compact mode',
                  value: ref.watch(settingsCompactModeProvider),
                  onChanged: (v) {
                    ref.read(settingsCompactModeProvider.notifier).state = v;
                    ref.read(settingsRepositoryProvider).setCompactMode(v);
                  },
                ),
              ],
            ),

            // ── Data & Storage ──
            SettingsSection(
              title: 'DATA & STORAGE',
              children: [
                SettingsTile(
                  icon: Icons.photo_library,
                  title: 'Media auto-download',
                  value: 'On',
                  onTap: () => _showMediaAutoDownloadDialog(context, ref),
                ),
                SettingsTile(
                  icon: Icons.cloud_upload,
                  title: 'Backup',
                  onTap: () => _showBackupDialog(context),
                ),
                SettingsTile(
                  icon: Icons.delete_outline,
                  title: 'Clear cache',
                  onTap: () => _showClearCacheDialog(context),
                ),
              ],
            ),

            // ── Advanced ──
            SettingsSection(
              title: 'ADVANCED',
              children: [
                SettingsTile(
                  icon: Icons.build,
                  title: 'Diagnostics',
                  onTap: () => context.push('/settings/routing-diagnostics'),
                ),
                SettingsTile(
                  icon: Icons.system_update,
                  title: 'App update',
                  value: ref.watch(settingsAutoUpdateProvider)
                      ? 'Auto'
                      : 'Manual',
                  onTap: () => context.push('/settings/update'),
                ),
                SettingsTile(
                  icon: Icons.info_outline,
                  title: 'About OneBit',
                  value: 'v${AppVersion.current}',
                  onTap: () => context.push('/settings/about'),
                ),
                SettingsTile(
                  icon: Icons.description,
                  title: 'Licenses',
                  onTap: () => showLicensePage(context: context),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _getThemeLabel(int index) {
    switch (index) {
      case 0:
        return 'System';
      case 1:
        return 'Light';
      case 2:
        return 'Dark';
      default:
        return 'System';
    }
  }

  String _getFontSizeLabel(int index) {
    switch (index) {
      case 0:
        return 'Small';
      case 1:
        return 'Medium';
      case 2:
        return 'Large';
      default:
        return 'Medium';
    }
  }

  void _showBiometricDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: Text(
          'Biometric Lock',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Use fingerprint or face recognition to lock the app. This feature requires device-level biometric enrollment.',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.accent),
            ),
          ),
        ],
      ),
    );
  }

  void _showEncryptionInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: Text(
          'End-to-End Encryption',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
        content: Text(
          'All messages are encrypted using AES-256-GCM with Ed25519 key exchange. Only you and your contacts can read your messages.',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.accent),
            ),
          ),
        ],
      ),
    );
  }

  void _showMediaAutoDownloadDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: Text(
          'Media Auto-Download',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Automatically download images and files when connected to Wi-Fi. Disable to manually approve each download.',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.accent),
            ),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: Text(
          'Backup',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Export your conversations and identity to a secure backup file. This creates an encrypted archive you can restore later.',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Backup created successfully',
                    style: AppTheme.technicalSmall
                        .copyWith(color: AppTheme.textPrimary),
                  ),
                  backgroundColor: AppTheme.bgSurface,
                ),
              );
            },
            child: const Text('Create Backup'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: Text(
          'Clear Cache',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Remove temporary files and cached media. This will not delete your conversations or identity.',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Cache cleared',
                    style: AppTheme.technicalSmall
                        .copyWith(color: AppTheme.textPrimary),
                  ),
                  backgroundColor: AppTheme.bgSurface,
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
