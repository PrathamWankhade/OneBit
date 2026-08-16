import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/colors/onebit_palette.dart';

/// Theme extension that delivers semantic colors beyond Material 3's roles.
///
/// Access via:
/// ```dart
/// final colors = Theme.of(context).extension<OneBitThemeExtension>()!;
/// ```
///
/// The extension carries:
/// * Neutral tint containers (success/warning/error/info)
/// * Muted / disabled text helpers
/// * Mono background for dev screens
/// * Primary surface for elevated cards
/// * Status dot / chip tokens
/// * Navigation tokens
class OneBitThemeExtension extends ThemeExtension<OneBitThemeExtension> {
  const OneBitThemeExtension({
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
    required this.monoBackground,
    required this.primarySurface,
    required this.statusDotOnline,
    required this.statusDotOffline,
    required this.statusDotSyncing,
    required this.statusDotError,
    required this.textMuted,
    required this.textDisabled,
    required this.statusBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.borderStrong,
    required this.surfaceElevated,
    required this.surfaceInteractive,
    required this.selectedBackground,
    required this.selectedForeground,
    required this.selectedIcon,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.identity,
  });

  factory OneBitThemeExtension.fromColorScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return isDark ? dark : light;
  }

  /// Dark-theme semantic tokens.
  static const dark = OneBitThemeExtension(
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
    monoBackground: OneBitPalette.darkSurfaceAlt,
    primarySurface: OneBitPalette.darkCard,
    statusDotOnline: OneBitPalette.ansiGreen,
    statusDotOffline: OneBitPalette.darkTextMuted,
    statusDotSyncing: OneBitPalette.ansiCyan,
    statusDotError: OneBitPalette.ansiRed,
    textMuted: OneBitPalette.darkTextMuted,
    textDisabled: OneBitPalette.darkTextDisabled,
    statusBorder: OneBitPalette.darkBorder,
    textPrimary: OneBitPalette.darkTextPrimary,
    textSecondary: OneBitPalette.darkTextSecondary,
    border: OneBitPalette.darkBorder,
    borderStrong: OneBitPalette.darkTextSecondary,
    surfaceElevated: OneBitPalette.darkCard,
    surfaceInteractive: OneBitPalette.darkSurfaceAlt,
    selectedBackground: OneBitPalette.darkSelectedBackground,
    selectedForeground: OneBitPalette.darkSelectedForeground,
    selectedIcon: OneBitPalette.darkSelectedForeground,
    iconPrimary: OneBitPalette.darkTextPrimary,
    iconSecondary: OneBitPalette.darkTextSecondary,
    identity: OneBitPalette.darkBackground,
  );

  /// Light-theme semantic tokens.
  static const light = OneBitThemeExtension(
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
    monoBackground: OneBitPalette.lightSurfaceAlt,
    primarySurface: OneBitPalette.lightCard,
    statusDotOnline: OneBitPalette.lightAnsiGreen,
    statusDotOffline: OneBitPalette.lightTextMuted,
    statusDotSyncing: OneBitPalette.lightAnsiCyan,
    statusDotError: OneBitPalette.lightAnsiRed,
    textMuted: OneBitPalette.lightTextMuted,
    textDisabled: OneBitPalette.lightTextDisabled,
    statusBorder: OneBitPalette.lightBorder,
    textPrimary: OneBitPalette.lightPrimary,
    textSecondary: OneBitPalette.lightSecondary,
    border: OneBitPalette.lightBorder,
    borderStrong: OneBitPalette.lightSecondary,
    surfaceElevated: OneBitPalette.lightCard,
    surfaceInteractive: OneBitPalette.lightElevated,
    selectedBackground: OneBitPalette.lightSelectedBackground,
    selectedForeground: OneBitPalette.lightSelectedForeground,
    selectedIcon: OneBitPalette.lightSelectedForeground,
    iconPrimary: OneBitPalette.lightPrimary,
    iconSecondary: OneBitPalette.lightSecondary,
    identity: OneBitPalette.lightBackground,
  );

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
  final Color monoBackground;
  final Color primarySurface;
  final Color statusDotOnline;
  final Color statusDotOffline;
  final Color statusDotSyncing;
  final Color statusDotError;
  final Color textMuted;
  final Color textDisabled;
  final Color statusBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color borderStrong;
  final Color surfaceElevated;
  final Color surfaceInteractive;
  final Color selectedBackground;
  final Color selectedForeground;
  final Color selectedIcon;
  final Color iconPrimary;
  final Color iconSecondary;
  final Color identity;

  @override
  OneBitThemeExtension copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccess,
    Color? warning,
    Color? warningContainer,
    Color? onWarning,
    Color? info,
    Color? infoContainer,
    Color? onInfo,
    Color? accent,
    Color? disabled,
    Color? monoBackground,
    Color? primarySurface,
    Color? statusDotOnline,
    Color? statusDotOffline,
    Color? statusDotSyncing,
    Color? statusDotError,
    Color? textMuted,
    Color? textDisabled,
    Color? statusBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? borderStrong,
    Color? surfaceElevated,
    Color? surfaceInteractive,
    Color? selectedBackground,
    Color? selectedForeground,
    Color? selectedIcon,
    Color? iconPrimary,
    Color? iconSecondary,
    Color? identity,
  }) {
    return OneBitThemeExtension(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarning: onWarning ?? this.onWarning,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfo: onInfo ?? this.onInfo,
      accent: accent ?? this.accent,
      disabled: disabled ?? this.disabled,
      monoBackground: monoBackground ?? this.monoBackground,
      primarySurface: primarySurface ?? this.primarySurface,
      statusDotOnline: statusDotOnline ?? this.statusDotOnline,
      statusDotOffline: statusDotOffline ?? this.statusDotOffline,
      statusDotSyncing: statusDotSyncing ?? this.statusDotSyncing,
      statusDotError: statusDotError ?? this.statusDotError,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      statusBorder: statusBorder ?? this.statusBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceInteractive: surfaceInteractive ?? this.surfaceInteractive,
      selectedBackground: selectedBackground ?? this.selectedBackground,
      selectedForeground: selectedForeground ?? this.selectedForeground,
      selectedIcon: selectedIcon ?? this.selectedIcon,
      iconPrimary: iconPrimary ?? this.iconPrimary,
      iconSecondary: iconSecondary ?? this.iconSecondary,
      identity: identity ?? this.identity,
    );
  }

  @override
  OneBitThemeExtension lerp(OneBitThemeExtension? other, double t) {
    if (other is! OneBitThemeExtension) return this;
    return OneBitThemeExtension(
      success: Color.lerp(success, other.success, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      monoBackground: Color.lerp(monoBackground, other.monoBackground, t)!,
      primarySurface: Color.lerp(primarySurface, other.primarySurface, t)!,
      statusDotOnline: Color.lerp(statusDotOnline, other.statusDotOnline, t)!,
      statusDotOffline:
          Color.lerp(statusDotOffline, other.statusDotOffline, t)!,
      statusDotSyncing:
          Color.lerp(statusDotSyncing, other.statusDotSyncing, t)!,
      statusDotError: Color.lerp(statusDotError, other.statusDotError, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      statusBorder: Color.lerp(statusBorder, other.statusBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      surfaceElevated:
          Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceInteractive:
          Color.lerp(surfaceInteractive, other.surfaceInteractive, t)!,
      selectedBackground:
          Color.lerp(selectedBackground, other.selectedBackground, t)!,
      selectedForeground:
          Color.lerp(selectedForeground, other.selectedForeground, t)!,
      selectedIcon: Color.lerp(selectedIcon, other.selectedIcon, t)!,
      iconPrimary: Color.lerp(iconPrimary, other.iconPrimary, t)!,
      iconSecondary: Color.lerp(iconSecondary, other.iconSecondary, t)!,
      identity: Color.lerp(identity, other.identity, t)!,
    );
  }
}

/// Convenience extension to access [OneBitThemeExtension] from [BuildContext].
extension OneBitThemeExtensionContextX on BuildContext {
  /// The app's semantic color tokens.
  OneBitThemeExtension get oneBitColors =>
      Theme.of(this).extension<OneBitThemeExtension>()!;
}
