import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/settings/data/settings_providers.dart';
import 'package:onebit/features/settings/data/settings_repository.dart';
import 'package:onebit/features/settings/presentation/widgets/settings_section.dart';
import 'package:onebit/features/settings/presentation/widgets/settings_toggle.dart';

/// F8 — Appearance settings screen.
///
/// Sections: Theme, Accent Color, Message Appearance, Animations.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeIndex = ref.watch(settingsThemeProvider);
    final accentIndex = ref.watch(settingsAccentColorProvider);
    final fontSizeIndex = ref.watch(settingsFontSizeProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: AppTheme.bgBase,
        title: Text(
          'Appearance',
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

          // ── Theme ───────────────────────────────────────────
          SettingsSection(
            title: 'Theme',
            children: [
              _ThemeOption(
                label: 'System default',
                isSelected: themeModeIndex == 0,
                onTap: () {
                  ref.read(settingsThemeProvider.notifier).state = 0;
                  ref.read(settingsRepositoryProvider).setThemeMode(0);
                },
              ),
              _ThemeOption(
                label: 'Dark',
                isSelected: themeModeIndex == 2,
                onTap: () {
                  ref.read(settingsThemeProvider.notifier).state = 2;
                  ref.read(settingsRepositoryProvider).setThemeMode(2);
                },
              ),
              _ThemeOption(
                label: 'Light',
                isSelected: themeModeIndex == 1,
                onTap: () {
                  ref.read(settingsThemeProvider.notifier).state = 1;
                  ref.read(settingsRepositoryProvider).setThemeMode(1);
                },
              ),
            ],
          ),

          // ── Accent Color ────────────────────────────────────
          SettingsSection(
            title: 'Accent Color',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final color in AccentColor.values)
                      _AccentColorChip(
                        color: color,
                        isSelected: accentIndex == color.index,
                        onTap: () {
                          ref.read(settingsAccentColorProvider.notifier).state =
                              color.index;
                          ref
                              .read(settingsRepositoryProvider)
                              .setAccentColor(color.index);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),

          // ── Message Appearance ──────────────────────────────
          SettingsSection(
            title: 'Message Appearance',
            children: [
              _FontSizeOption(
                label: FontSize.values[fontSizeIndex].name[0].toUpperCase() +
                    FontSize.values[fontSizeIndex].name.substring(1),
                onTap: () => _showFontSizePicker(context, ref, fontSizeIndex),
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

          // ── Animations ──────────────────────────────────────
          SettingsSection(
            title: 'Animations',
            children: [
              SettingsToggle(
                icon: Icons.animation,
                title: 'Reduced motion',
                value: ref.watch(settingsReducedMotionProvider),
                onChanged: (v) {
                  ref.read(settingsReducedMotionProvider.notifier).state = v;
                  ref.read(settingsRepositoryProvider).setReducedMotion(v);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFontSizePicker(
    BuildContext context,
    WidgetRef ref,
    int currentIndex,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Font Size',
                style: AppTheme.titleLarge.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            for (final size in FontSize.values)
              ListTile(
                title: Text(
                  size.name[0].toUpperCase() + size.name.substring(1),
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                trailing: currentIndex == size.index
                    ? const Icon(Icons.check, color: AppTheme.accent)
                    : null,
                onTap: () {
                  ref.read(settingsFontSizeProvider.notifier).state =
                      size.index;
                  ref.read(settingsRepositoryProvider).setFontSize(size.index);
                  Navigator.of(context).pop();
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Private widgets ────────────────────────────────────────────

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: isSelected ? AppTheme.accent : AppTheme.textTertiary,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FontSizeOption extends StatelessWidget {
  const _FontSizeOption({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(
              Icons.text_fields,
              size: 24,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Font size',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentColorChip extends StatelessWidget {
  const _AccentColorChip({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final AccentColor color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppTheme.textPrimary : Colors.transparent,
            width: 3,
          ),
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: ThemeData.estimateBrightnessForColor(color.color) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black,
              )
            : null,
      ),
    );
  }
}
