import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/settings/data/settings_providers.dart';
import 'package:onebit/features/settings/presentation/widgets/settings_section.dart';
import 'package:onebit/features/settings/presentation/widgets/settings_tile.dart';
import 'package:onebit/features/settings/presentation/widgets/settings_toggle.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: AppTheme.bgBase,
        title: Text(
          'Privacy & Security',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsSection(
            title: 'VERIFICATION',
            children: [
              SettingsTile(
                icon: Icons.verified_user,
                title: 'Verification settings',
                onTap: () => context.push('/identity/verify'),
              ),
            ],
          ),
          SettingsSection(
            title: 'ENCRYPTION',
            children: [
              SettingsTile(
                icon: Icons.lock_outline,
                title: 'Message encryption',
                description: 'End-to-end encryption enabled',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.trust.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'E2EE',
                    style: AppTheme.technicalSmall.copyWith(
                      color: AppTheme.trust,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: 'DISAPPEARING MESSAGES',
            children: [
              SettingsTile(
                icon: Icons.timer_outlined,
                title: 'Default lifetime',
                description: _ttlLabel(ref.watch(
                  settingsDisappearingHoursProvider,
                )),
                onTap: () {
                  const options = [0, 1, 24, 168];
                  final notifier = ref.read(
                    settingsDisappearingHoursProvider.notifier,
                  );
                  final next = options[
                      (options.indexOf(notifier.state) + 1) % options.length];
                  notifier.state = next;
                  ref
                      .read(settingsRepositoryProvider)
                      .setDisappearingHours(next);
                },
              ),
            ],
          ),
          SettingsSection(
            title: 'RECEIPTS',
            children: [
              SettingsToggle(
                icon: Icons.done_all,
                title: 'Send receipts',
                description:
                    'Tell senders when a message arrives and is read',
                value: ref.watch(settingsReadReceiptsEnabledProvider),
                onChanged: (v) {
                  ref
                      .read(settingsReadReceiptsEnabledProvider.notifier)
                      .state = v;
                  ref
                      .read(settingsRepositoryProvider)
                      .setReadReceiptsEnabled(v);
                },
              ),
            ],
          ),
          SettingsSection(
            title: 'STEALTH',
            children: [
              SettingsToggle(
                icon: Icons.visibility_off,
                title: 'Stealth mode',
                description:
                    'No advertising, no topology, no receipts — still listening',
                value: ref.watch(settingsStealthEnabledProvider),
                onChanged: (v) {
                  ref.read(settingsStealthEnabledProvider.notifier).state = v;
                  ref.read(settingsRepositoryProvider).setStealthEnabled(v);
                },
              ),
            ],
          ),
          SettingsSection(
            title: 'BLOCKED PEERS',
            children: [
              SettingsTile(
                icon: Icons.block,
                title: 'Blocked peers',
                description: 'No blocked contacts',
                onTap: () {},
              ),
            ],
          ),
          SettingsSection(
            title: 'VISIBILITY',
            children: [
              SettingsToggle(
                icon: Icons.visibility_off,
                title: 'Hide online status',
                value: !ref.watch(settingsDiscoveryEnabledProvider),
                onChanged: (v) {
                  ref
                      .read(settingsDiscoveryEnabledProvider.notifier)
                      .state = !v;
                  ref
                      .read(settingsRepositoryProvider)
                      .setDiscoveryEnabled(!v);
                },
              ),
              SettingsToggle(
                icon: Icons.people,
                title: 'Show in nearby list',
                value: ref.watch(settingsDiscoveryEnabledProvider),
                onChanged: (v) {
                  ref.read(settingsDiscoveryEnabledProvider.notifier).state =
                      v;
                  ref
                      .read(settingsRepositoryProvider)
                      .setDiscoveryEnabled(v);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Human label for a disappearing-messages lifetime in hours.
String _ttlLabel(int hours) => switch (hours) {
      0 => 'Off — messages are kept',
      1 => '1 hour',
      24 => '24 hours',
      168 => '7 days',
      _ => '$hours hours',
    };
