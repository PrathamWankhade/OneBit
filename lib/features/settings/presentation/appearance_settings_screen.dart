import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/theme/theme_preference.dart';
import 'package:onebit/core/theme/theme_preference_provider.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';
import 'package:onebit/shared/design_system/colors/onebit_palette.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Appearance settings: theme identity selection, terminal palette
/// display and reduced-motion preference.
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
        padding: EdgeInsets.fromLTRB(
          OneBitSpacing.xxl,
          OneBitSpacing.lg,
          OneBitSpacing.xxl,
          OneBitScrollClearance.bottom(context),
        ),
        children: [
          // ── Theme selection ─────────────────────────────────────────
          OneBitSectionHeader(title: l10n.settingsTheme),
          OneBitCard(
            child: Column(
              children: [
                for (final option in ThemePreference.values)
                  _TerminalRadioTile<ThemePreference>(
                    value: option,
                    groupValue: preference,
                    label: switch (option) {
                      ThemePreference.system => l10n.settingsThemeSystem,
                      ThemePreference.light => l10n.settingsThemeLight,
                      ThemePreference.dark => l10n.settingsThemeDark,
                    },
                    onChanged: (selected) {
                      if (selected != null) {
                        ref
                            .read(themePreferenceProvider.notifier)
                            .setTheme(selected);
                      }
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: OneBitSpacing.xxl),

          // ── Terminal palette ────────────────────────────────────────
          OneBitSectionHeader(
            title: l10n.settingsTerminalPalette,
            subtitle: l10n.settingsTerminalPaletteDescription,
          ),
          OneBitCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PaletteTile(
                  icon: OneBitIcons.shellDeveloper,
                  title: l10n.settingsTerminalPaletteIbm5153,
                  subtitle: l10n.settingsTerminalPaletteIbm5153Description,
                  selected: true,
                ),
                const SizedBox(height: OneBitSpacing.md),
                const _AnsiSwatchRow(),
                const SizedBox(height: OneBitSpacing.md),
                const _TerminalPreview(),
                const SizedBox(height: OneBitSpacing.sm),
                _FuturePaletteNote(message: l10n.settingsTerminalPaletteFuture),
              ],
            ),
          ),

          const SizedBox(height: OneBitSpacing.xxl),

          // ── Reduced motion ──────────────────────────────────────────
          OneBitSectionHeader(title: l10n.settingsReducedMotion),
          OneBitCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.animation_outlined,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: OneBitSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsReducedMotion,
                        style: context.textTheme.titleSmall,
                      ),
                      const SizedBox(height: OneBitSpacing.xs),
                      Text(
                        reduceMotion
                            ? l10n.settingsReducedMotionOn
                            : l10n.settingsReducedMotionOff,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: OneBitSpacing.sm),
                      Text(
                        l10n.settingsReducedMotionDescription,
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

// ─── Terminal-styled radio tile ──────────────────────────────────────────────

/// Square-indicator radio tile matching the OneBit terminal aesthetic.
class _TerminalRadioTile<T> extends StatelessWidget {
  const _TerminalRadioTile({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.onChanged,
  });

  final T value;
  final T? groupValue;
  final String label;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = value == groupValue;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: () => onChanged(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: OneBitSpacing.md),
          child: Row(
            children: [
              // Square radio indicator
              AnimatedContainer(
                duration: OneBitMotion.fast,
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: isSelected ? scheme.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? scheme.primary : scheme.outline,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: isSelected
                    ? Icon(Icons.check_rounded, size: 12, color: scheme.onPrimary)
                    : null,
              ),
              const SizedBox(width: OneBitSpacing.md),
              Text(
                label,
                style: context.textTheme.titleSmall?.copyWith(
                  color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Palette tile ────────────────────────────────────────────────────────────

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
        const SizedBox(width: OneBitSpacing.md),
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
        if (selected)
          Icon(OneBitIcons.check, size: 18, color: scheme.primary),
      ],
    );
  }
}

// ─── ANSI color swatch row ───────────────────────────────────────────────────

/// Horizontal row of IBM 5153 ANSI color swatches.
class _AnsiSwatchRow extends StatelessWidget {
  const _AnsiSwatchRow();

  static const _darkColors = [
    OneBitPalette.ansiRed,
    OneBitPalette.ansiGreen,
    OneBitPalette.ansiYellow,
    OneBitPalette.ansiBlue,
    OneBitPalette.ansiPurple,
    OneBitPalette.ansiCyan,
  ];

  static const _lightColors = [
    OneBitPalette.lightAnsiRed,
    OneBitPalette.lightAnsiGreen,
    OneBitPalette.lightAnsiYellow,
    OneBitPalette.lightAnsiBlue,
    OneBitPalette.lightAnsiPurple,
    OneBitPalette.lightAnsiCyan,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final colors = isDark ? _darkColors : _lightColors;

    return Row(
      children: [
        for (final color in colors) ...[
          Expanded(
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          if (color != colors.last)
            const SizedBox(width: OneBitSpacing.xs),
        ],
      ],
    );
  }
}

// ─── Terminal preview ────────────────────────────────────────────────────────

/// Mini terminal preview showing the IBM 5153 palette in context.
class _TerminalPreview extends StatelessWidget {
  const _TerminalPreview();

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final scheme = Theme.of(context).colorScheme;

    final bgColor = isDark ? OneBitPalette.darkBackground : OneBitPalette.lightSurface;
    final promptColor = isDark ? OneBitPalette.ansiGreen : OneBitPalette.lightAnsiGreen;
    final textColor = isDark ? OneBitPalette.ansiWhite : OneBitPalette.lightPrimary;
    final pathColor = isDark ? OneBitPalette.ansiCyan : OneBitPalette.lightAnsiCyan;
    final errorColor = isDark ? OneBitPalette.ansiRed : OneBitPalette.lightAnsiRed;
    final mutedColor = isDark ? OneBitPalette.ansiBrightBlack : OneBitPalette.lightTextMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OneBitSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: DefaultTextStyle(
        style: OneBitTypography.technicalStyle(
          fontSize: 12,
          color: textColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '~', style: TextStyle(color: mutedColor)),
                  TextSpan(text: '/onebit', style: TextStyle(color: pathColor)),
                  TextSpan(text: ' \$ ', style: TextStyle(color: mutedColor)),
                  TextSpan(
                    text: 'mesh.status',
                    style: TextStyle(color: promptColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: OneBitSpacing.xs),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '[OK] ',
                    style: TextStyle(color: promptColor),
                  ),
                  TextSpan(
                    text: '3 peers connected',
                    style: TextStyle(color: textColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: OneBitSpacing.xs),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '[!!] ',
                    style: TextStyle(color: errorColor),
                  ),
                  TextSpan(
                    text: 'RSSI weak on node-7f',
                    style: TextStyle(color: mutedColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Future palette note ─────────────────────────────────────────────────────

class _FuturePaletteNote extends StatelessWidget {
  const _FuturePaletteNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          OneBitIcons.schedule,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: OneBitSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: context.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
