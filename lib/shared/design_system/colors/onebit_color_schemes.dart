import 'package:flutter/material.dart';

import 'onebit_palette.dart';

/// Semantic color assignments for the two identities.
///
/// Each [ColorScheme] consumes palette values and assigns them to Material 3
/// roles. Feature code accesses only these semantic roles — never raw palette
/// values. The dark scheme stays close to neutral Material 3 Dark tones; the
/// light scheme is a clean white identity.
///
/// Accessibility: all combinations target a minimum 4.5:1 contrast ratio
/// for normal text and 3:1 for large text against their designated background.
abstract final class OneBitColorSchemes {
  // ─── Dark identity ──────────────────────────────────────────────────────

  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,

    // ── Surface hierarchy ──
    surface: OneBitPalette.darkSurface,
    surfaceContainerLowest: OneBitPalette.darkBackground,
    surfaceContainerLow: OneBitPalette.darkSurfaceAlt,
    surfaceContainer: OneBitPalette.darkElevated,
    surfaceContainerHigh: OneBitPalette.darkCard,
    surfaceContainerHighest: OneBitPalette.darkCard,

    // ── Primary ──
    primary: OneBitPalette.ansiBrightWhite,
    primaryContainer: OneBitPalette.darkCard,
    onPrimary: OneBitPalette.darkBackground,
    onPrimaryContainer: OneBitPalette.darkTextPrimary,

    // ── Secondary ──
    secondary: OneBitPalette.darkTextSecondary,
    secondaryContainer: OneBitPalette.darkElevated,
    onSecondary: OneBitPalette.darkBackground,
    onSecondaryContainer: OneBitPalette.darkTextPrimary,

    // ── Tertiary ──
    tertiary: OneBitPalette.ansiCyan,
    tertiaryContainer: OneBitPalette.darkInfoContainer,
    onTertiary: OneBitPalette.darkBackground,
    onTertiaryContainer: OneBitPalette.darkTextPrimary,

    // ── Error ──
    error: OneBitPalette.ansiBrightRed,
    errorContainer: OneBitPalette.darkErrorContainer,
    onError: OneBitPalette.darkBackground,
    onErrorContainer: OneBitPalette.darkTextPrimary,

    // ── On-surface ──
    onSurface: OneBitPalette.darkTextPrimary,
    onSurfaceVariant: OneBitPalette.darkTextSecondary,

    // ── Outline ──
    outline: OneBitPalette.darkBorder,
    outlineVariant: OneBitPalette.darkDivider,

    // ── Inverse ──
    inverseSurface: OneBitPalette.darkCard,
    onInverseSurface: OneBitPalette.darkTextPrimary,
    inversePrimary: OneBitPalette.ansiBrightBlack,

    // ── Shadows ──
    shadow: OneBitPalette.black,
    scrim: OneBitPalette.black,
  );

  // ─── Light identity ─────────────────────────────────────────────────────

  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,

    // ── Surface hierarchy ──
    surface: OneBitPalette.lightSurface,
    surfaceContainerLowest: OneBitPalette.lightBackground,
    surfaceContainerLow: OneBitPalette.lightSurfaceAlt,
    surfaceContainer: OneBitPalette.lightElevated,
    surfaceContainerHigh: OneBitPalette.lightCard,
    surfaceContainerHighest: OneBitPalette.lightCard,

    // ── Primary ──
    primary: OneBitPalette.lightPrimary,
    primaryContainer: OneBitPalette.lightCard,
    onPrimary: OneBitPalette.lightSurface,
    onPrimaryContainer: OneBitPalette.lightPrimary,

    // ── Secondary ──
    secondary: OneBitPalette.lightSecondary,
    secondaryContainer: OneBitPalette.lightElevated,
    onSecondary: OneBitPalette.lightSurface,
    onSecondaryContainer: OneBitPalette.lightPrimary,

    // ── Tertiary ──
    tertiary: OneBitPalette.lightAnsiCyan,
    tertiaryContainer: OneBitPalette.lightInfoContainer,
    onTertiary: OneBitPalette.lightSurface,
    onTertiaryContainer: OneBitPalette.lightPrimary,

    // ── Error ──
    error: OneBitPalette.lightAnsiRed,
    errorContainer: OneBitPalette.lightErrorContainer,
    onError: OneBitPalette.lightSurface,
    onErrorContainer: OneBitPalette.lightPrimary,

    // ── On-surface ──
    onSurface: OneBitPalette.lightPrimary,
    onSurfaceVariant: OneBitPalette.lightSecondary,

    // ── Outline ──
    outline: OneBitPalette.lightBorder,
    outlineVariant: OneBitPalette.lightDivider,

    // ── Inverse ──
    inverseSurface: OneBitPalette.lightPrimary,
    onInverseSurface: OneBitPalette.lightSurface,
    inversePrimary: OneBitPalette.lightAnsiBrightBlack,

    // ── Shadows ──
    shadow: OneBitPalette.black,
    scrim: OneBitPalette.black,
  );

  /// Dark-theme semantic tokens that go beyond Material 3's built-in roles.
  static const darkExtra = _ExtraColors(
    success: OneBitPalette.ansiGreen,
    successContainer: OneBitPalette.darkSuccessContainer,
    onSuccess: OneBitPalette.darkBackground,
    warning: OneBitPalette.ansiYellow,
    warningContainer: OneBitPalette.darkWarningContainer,
    onWarning: OneBitPalette.darkBackground,
    info: OneBitPalette.ansiCyan,
    infoContainer: OneBitPalette.darkInfoContainer,
    onInfo: OneBitPalette.darkBackground,
    accent: OneBitPalette.ansiBrightCyan,
    disabled: OneBitPalette.darkTextDisabled,
  );

  /// Light-theme semantic tokens that go beyond Material 3's built-in roles.
  static const lightExtra = _ExtraColors(
    success: OneBitPalette.lightAnsiGreen,
    successContainer: OneBitPalette.lightSuccessContainer,
    onSuccess: OneBitPalette.lightPrimary,
    warning: OneBitPalette.lightAnsiYellow,
    warningContainer: OneBitPalette.lightWarningContainer,
    onWarning: OneBitPalette.lightPrimary,
    info: OneBitPalette.lightAnsiCyan,
    infoContainer: OneBitPalette.lightInfoContainer,
    onInfo: OneBitPalette.lightPrimary,
    accent: OneBitPalette.lightAnsiBrightCyan,
    disabled: OneBitPalette.lightTextDisabled,
  );

  const OneBitColorSchemes._();
}

/// Extra semantic colors beyond Material 3's built-in roles.
///
/// These are delivered via [ThemeExtension] so they remain accessible through
/// `Theme.of(context).extension<OneBitExtraColors>()`.
class _ExtraColors {
  const _ExtraColors({
    required this.success,
    required this.successContainer,
    required this.onSuccess,
    required this.warning,
    required this.warningContainer,
    required this.onWarning,
    required this.info,
    required this.infoContainer,
    required this.onInfo,
    required this.accent,
    required this.disabled,
  });

  final Color success;
  final Color successContainer;
  final Color onSuccess;
  final Color warning;
  final Color warningContainer;
  final Color onWarning;
  final Color info;
  final Color infoContainer;
  final Color onInfo;
  final Color accent;
  final Color disabled;
}
