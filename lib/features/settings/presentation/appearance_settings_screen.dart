import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/theme/theme_preference.dart';
import 'package:onebit/core/theme/theme_preference_provider.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Appearance settings: theme identity selection, terminal palette
/// and animation preferences.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final preference = ref.watch(themePreferenceProvider);
    final reduceMotion = context.reduceMotion;
    final scheme = Theme.of(context).colorScheme;

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.settingsAppearance)),
      body: ListView(
        padding: const EdgeInsets.all(OneBitSpacing.m),
        children: [
          OneBitSectionHeader(title: l10n.settingsTheme),
          OneBitCard(
            child: RadioGroup<ThemePreference>(
              groupValue: preference,
              onChanged: (selected) {
                if (selected != null) {
                  ref.read(themePreferenceProvider.notifier).setTheme(selected);
                }
              },
              child: Column(
                children: [
                  for (final option in ThemePreference.values)
                    RadioListTile<ThemePreference>(
                      value: option,
                      title: Text(switch (option) {
                        ThemePreference.system => l10n.settingsThemeSystem,
                        ThemePreference.light => l10n.settingsThemeLight,
                        ThemePreference.dark => l10n.settingsThemeDark,
                      }),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: OneBitSpacing.xl),
          OneBitSectionHeader(
            title: l10n.settingsTerminalPalette,
            subtitle: l10n.settingsTerminalPaletteDescription,
          ),
          OneBitCard(
            child: Column(
              children: [
                _PaletteTile(
                  icon: OneBitIcons.shellDeveloper,
                  title: l10n.settingsTerminalPaletteIbm5153,
                  subtitle: l10n.settingsTerminalPaletteIbm5153Description,
                  selected: true,
                ),
                const SizedBox(height: OneBitSpacing.s),
                _FuturePaletteNote(message: l10n.settingsTerminalPaletteFuture),
              ],
            ),
          ),
          const SizedBox(height: OneBitSpacing.xl),
          OneBitSectionHeader(title: l10n.settingsAppearanceDescription),
          OneBitCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.animation_outlined,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: OneBitSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reduced motion',
                        style: context.textTheme.titleSmall,
                      ),
                      const SizedBox(height: OneBitSpacing.xs),
                      Text(
                        reduceMotion
                            ? 'System setting: animations are reduced'
                            : 'System setting: full animations enabled',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: OneBitSpacing.s),
                      Text(
                        'Controlled by your device accessibility settings. '
                        'OneBit respects the system reduced-motion preference.',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: OneBitSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.textTheme.titleSmall),
              const SizedBox(height: OneBitSpacing.xs),
              Text(
                subtitle,
                style: context.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (selected) Icon(OneBitIcons.check, size: 18, color: scheme.primary),
      ],
    );
  }
}

class _FuturePaletteNote extends StatelessWidget {
  const _FuturePaletteNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: OneBitSpacing.xs),
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: OneBitSpacing.s),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
