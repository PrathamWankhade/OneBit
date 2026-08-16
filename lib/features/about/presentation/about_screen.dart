import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/developer_mode_controller.dart';
import 'package:onebit/core/config/app_config_provider.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/components/onebit_settings_card.dart';
import 'package:onebit/shared/design_system/components/onebit_snackbar.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// About OneBit: version, description, build info, licenses and the hidden
/// developer unlock (repeated taps on the version row).
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final config = ref.watch(appConfigProvider);

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          OneBitSpacing.xxl,
          OneBitSpacing.lg,
          OneBitSpacing.xxl,
          OneBitScrollClearance.bottom(context),
        ),
        children: [
          const SizedBox(height: OneBitSpacing.xl),
          Center(child: Image.asset('assets/icons/OneBit.png', width: 80)),
          const SizedBox(height: OneBitSpacing.m),
          Center(
            child: Text(l10n.appTitle, style: context.textTheme.headlineSmall),
          ),
          const SizedBox(height: OneBitSpacing.s),
          Center(
            child: Text(
              config.displayVersion,
              style: context.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: OneBitSpacing.xl),
          OneBitCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.aboutDescriptionShort,
                  style: context.textTheme.bodyMedium,
                ),
                const SizedBox(height: OneBitSpacing.s),
                Text(l10n.aboutEveryDevice, style: context.textTheme.bodySmall),
                const SizedBox(height: OneBitSpacing.s),
                Text(
                  l10n.aboutNoInternet,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: OneBitSpacing.m),
          OneBitSectionHeader(title: l10n.aboutTechnicalInfo),
          OneBitCard(
            child: Column(
              children: [
                _TechRow(
                  label: l10n.aboutVersion,
                  value: config.displayVersion,
                ),
                _TechRow(
                  label: l10n.aboutBuildLabel,
                  value: kIsWeb ? 'web' : Platform.operatingSystem,
                ),
                _TechRow(
                  label: l10n.aboutPlatformLabel,
                  value: kIsWeb
                      ? 'Web'
                      : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
                ),
                _TechRow(label: l10n.aboutEngineLabel, value: 'BLE mesh'),
              ],
            ),
          ),
          const SizedBox(height: OneBitSpacing.m),
          OneBitSettingsCard(
            icon: OneBitIcons.info,
            title: l10n.aboutVersion,
            subtitle: config.displayVersion,
            trailing: const Icon(OneBitIcons.chevronRight),
            onTap: () => _registerVersionTap(context, ref),
          ),
          const SizedBox(height: OneBitSpacing.s),
          OneBitSettingsCard(
            icon: OneBitIcons.licenses,
            title: l10n.aboutLicenses,
            trailing: const Icon(OneBitIcons.chevronRight),
            onTap: () => context.push(AppRoutePaths.licenses),
          ),
        ],
      ),
    );
  }

  void _registerVersionTap(BuildContext context, WidgetRef ref) {
    final unlocked = ref
        .read(developerModeProvider.notifier)
        .registerVersionTap();
    if (unlocked) {
      OneBitSnackBars.success(
        context,
        message: context.l10n.developerModeEnabledMessage,
      );
    }
  }
}

class _TechRow extends StatelessWidget {
  const _TechRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: OneBitSpacing.xs,
        horizontal: 0,
      ),
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
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: OneBitTypography.technicalStyle(
                fontSize: OneBitTypography.caption,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
