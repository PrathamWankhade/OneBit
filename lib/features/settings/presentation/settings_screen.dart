import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/developer_mode_controller.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/shared/design_system/components/onebit_section_label.dart';
import 'package:onebit/shared/design_system/components/onebit_settings_card.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Global Settings screen: application-wide preferences only.
///
/// Page-specific settings (channel, node, nearby, mesh) live in their
/// respective contexts. This screen is accessed via the gear icon in
/// the top app bar of primary pages.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final developerEnabled = ref.watch(developerModeProvider).value == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Go back',
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: OneBitSpacing.xl,
          vertical: OneBitSpacing.m,
        ),
        children: [
          // ── Preferences ──
          OneBitSectionLabel(title: l10n.settingsSectionPreferences),
          _SettingsTile(
            icon: OneBitIcons.palette,
            title: l10n.settingsAppearance,
            path: AppRoutePaths.appearance,
          ),
          const SizedBox(height: OneBitSpacing.s),
          _SettingsTile(
            icon: OneBitIcons.privacy,
            title: l10n.settingsPrivacy,
            path: AppRoutePaths.privacy,
          ),
          const SizedBox(height: OneBitSpacing.s),
          _SettingsTile(
            icon: OneBitIcons.storage,
            title: l10n.settingsStorage,
            path: AppRoutePaths.storage,
          ),
          const SizedBox(height: OneBitSpacing.s),
          _SettingsTile(
            icon: OneBitIcons.notifications,
            title: l10n.settingsNotifications,
            path: AppRoutePaths.notifications,
          ),
          const SizedBox(height: OneBitSpacing.s),
          _SettingsTile(
            icon: OneBitIcons.bluetooth,
            title: l10n.settingsBluetooth,
            path: AppRoutePaths.bluetooth,
          ),

          // ── Application ──
          OneBitSectionLabel(title: l10n.settingsSectionAbout),
          _SettingsTile(
            icon: OneBitIcons.shellAbout,
            title: l10n.settingsAbout,
            path: AppRoutePaths.about,
          ),
          const SizedBox(height: OneBitSpacing.s),
          _SettingsTile(
            icon: OneBitIcons.licenses,
            title: l10n.aboutLicenses,
            path: AppRoutePaths.licenses,
          ),

          // ── Developer (conditional) ──
          if (developerEnabled) ...[
            OneBitSectionLabel(title: l10n.settingsSectionTools),
            _SettingsTile(
              icon: OneBitIcons.shellDeveloper,
              title: l10n.settingsDeveloper,
              path: AppRoutePaths.developer,
            ),
          ],
        ],
      ),
    );
  }
}

/// One settings row that pushes its route.
final class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.path,
  });

  final IconData icon;
  final String title;
  final String path;

  @override
  Widget build(BuildContext context) {
    return OneBitSettingsCard(
      icon: icon,
      title: title,
      trailing: const Icon(OneBitIcons.chevronRight),
      onTap: () => context.push(path),
    );
  }
}
