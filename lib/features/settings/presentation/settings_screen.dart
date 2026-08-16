import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/developer_mode_controller.dart';
import 'package:onebit/core/config/app_config.dart';
import 'package:onebit/core/config/app_config_provider.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/l10n/app_localizations.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/components/onebit_section_label.dart';
import 'package:onebit/shared/design_system/components/onebit_settings_card.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/responsive/onebit_responsive.dart';
import 'package:onebit/shared/design_system/spacing/onebit_radius.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Global Settings screen: application-wide preferences only.
///
/// Page-specific settings (channel, node, nearby, mesh) live in their
/// respective contexts. This screen is accessed via the gear icon in
/// the top app bar of primary pages.
///
/// On tablets, uses a master-detail layout with the settings list on the
/// left and the detail content on the right.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const double _masterWidth = 320;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final developerEnabled = ref.watch(developerModeProvider).value == true;
    final config = ref.watch(appConfigProvider);

    return OneBitScaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        leading: OneBitIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: l10n.commonGoBack,
          onPressed: () => context.pop(),
        ),
      ),
      body: context.isTablet
          ? _TabletSettingsLayout(
              developerEnabled: developerEnabled,
              config: config,
            )
          : _PhoneSettingsList(
              developerEnabled: developerEnabled,
              config: config,
            ),
    );
  }
}

/// Phone layout: standard push navigation.
class _PhoneSettingsList extends StatelessWidget {
  const _PhoneSettingsList({
    required this.developerEnabled,
    required this.config,
  });

  final bool developerEnabled;
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        OneBitSpacing.xxl,
        0,
        OneBitSpacing.xxl,
        OneBitScrollClearance.bottom(context),
      ),
      children: _buildSettingsTiles(context, l10n, developerEnabled, config),
    );
  }
}

/// Tablet layout: settings list on left, detail on right.
class _TabletSettingsLayout extends StatelessWidget {
  const _TabletSettingsLayout({
    required this.developerEnabled,
    required this.config,
  });

  final bool developerEnabled;
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: SettingsScreen._masterWidth,
          child: Container(
            color: scheme.surfaceContainerLow,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                0,
                OneBitSpacing.m,
                0,
                OneBitScrollClearance.bottom(context),
              ),
              children: _buildSettingsTiles(context, l10n, developerEnabled, config),
            ),
          ),
        ),
        Container(
          width: 1,
          color: scheme.outlineVariant,
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: OneBitBreakpoints.maxContentWidth),
              child: Padding(
                padding: const EdgeInsets.all(OneBitSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      OneBitIcons.shellSettings,
                      size: 48,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: OneBitSpacing.m),
                    Text(
                      l10n.settingsTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: OneBitSpacing.s),
                    Text(
                      l10n.settingsSectionPreferences,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared settings tiles builder.
List<Widget> _buildSettingsTiles(
  BuildContext context,
  AppLocalizations l10n,
  bool developerEnabled,
  AppConfig config,
) {
  return [
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

    // ── About ──
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

    // ── Footer ──
    const SizedBox(height: OneBitSpacing.xxxl),
    _SettingsFooter(
      version: config.version,
      buildNumber: config.buildNumber.toString(),
    ),
    const SizedBox(height: OneBitSpacing.m),
  ];
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

/// Terminal-style footer showing version and build information.
class _SettingsFooter extends StatelessWidget {
  const _SettingsFooter({
    required this.version,
    required this.buildNumber,
  });

  final String version;
  final String buildNumber;

  @override
  Widget build(BuildContext context) {
    final colors = context.oneBitColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: OneBitSpacing.lg,
        vertical: OneBitSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: colors.monoBackground,
        borderRadius: BorderRadius.circular(OneBitRadius.sm),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'onebit v$version+$buildNumber',
            style: OneBitTypography.oneBitCaption(
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: OneBitSpacing.xs),
          Text(
            context.l10n.homeSubtitle,
            style: OneBitTypography.oneBitCaption(
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
