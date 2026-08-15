import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/colors/onebit_palette.dart';

/// Builders for the two [ColorScheme]s and the brand `ThemeExtension`.
///
/// Schemes are hand-assembled from [OneBitPalette] — never `fromSeed` — so
/// the monochrome identity cannot be diluted by Material's tonal derivation.
abstract final class OneBitColorSchemes {
  const OneBitColorSchemes._();

  /// Light scheme.
  static ColorScheme light() => const ColorScheme(
    brightness: Brightness.light,
    primary: OneBitPalette.lightPrimary,
    onPrimary: OneBitPalette.lightSurface,
    primaryContainer: Color(0xFFE6E6E6),
    onPrimaryContainer: OneBitPalette.lightPrimary,
    secondary: OneBitPalette.lightSecondary,
    onSecondary: OneBitPalette.lightSurface,
    secondaryContainer: Color(0xFFECECEC),
    onSecondaryContainer: OneBitPalette.lightPrimary,
    tertiary: Color(0xFF444444),
    onTertiary: OneBitPalette.lightSurface,
    tertiaryContainer: Color(0xFFE8E8E8),
    onTertiaryContainer: OneBitPalette.lightPrimary,
    error: Color(0xFFC93A3A),
    onError: OneBitPalette.lightSurface,
    errorContainer: OneBitPalette.lightErrorContainer,
    onErrorContainer: Color(0xFF7A1D1D),
    surface: OneBitPalette.lightSurface,
    onSurface: OneBitPalette.lightPrimary,
    surfaceContainerLowest: OneBitPalette.lightBackground,
    surfaceContainerLow: Color(0xFFF7F7F7),
    surfaceContainer: Color(0xFFF2F2F2),
    surfaceContainerHigh: Color(0xFFECECEC),
    surfaceContainerHighest: Color(0xFFE6E6E6),
    onSurfaceVariant: OneBitPalette.lightSecondary,
    outline: OneBitPalette.lightBorder,
    outlineVariant: Color(0xFFE4E4E4),
    inverseSurface: OneBitPalette.lightPrimary,
    onInverseSurface: OneBitPalette.lightSurface,
    surfaceTint: Color(0x00000000),
    shadow: Color(0x1A000000),
  );

  /// Dark scheme.
  static ColorScheme dark() => const ColorScheme(
    brightness: Brightness.dark,
    primary: OneBitPalette.darkTextPrimary,
    onPrimary: Color(0xFF0A0A0A),
    primaryContainer: Color(0xFF2A2A2A),
    onPrimaryContainer: OneBitPalette.darkTextPrimary,
    secondary: OneBitPalette.darkTextSecondary,
    onSecondary: Color(0xFF141414),
    secondaryContainer: Color(0xFF232323),
    onSecondaryContainer: Color(0xFFE6E6E6),
    tertiary: OneBitPalette.darkTextMuted,
    onTertiary: Color(0xFF111111),
    tertiaryContainer: OneBitPalette.darkCard,
    onTertiaryContainer: Color(0xFFCDCDCD),
    error: OneBitPalette.ansiBrightRed,
    onError: Color(0xFF1A0C0C),
    errorContainer: OneBitPalette.darkErrorContainer,
    onErrorContainer: OneBitPalette.ansiBrightRed,
    surface: OneBitPalette.darkSurface,
    onSurface: OneBitPalette.darkTextPrimary,
    surfaceContainerLowest: OneBitPalette.darkBackground,
    surfaceContainerLow: OneBitPalette.darkSurfaceAlt,
    surfaceContainer: OneBitPalette.darkCard,
    surfaceContainerHigh: OneBitPalette.darkElevated,
    surfaceContainerHighest: Color(0xFF262626),
    onSurfaceVariant: OneBitPalette.darkTextSecondary,
    outline: OneBitPalette.darkBorder,
    outlineVariant: OneBitPalette.darkDivider,
    inverseSurface: OneBitPalette.darkTextPrimary,
    onInverseSurface: OneBitPalette.darkSurface,
    surfaceTint: Color(0x00000000),
    shadow: Color(0xFF000000),
  );
}

/// Semantic color tokens exposed to widgets via `Theme.extension`.
///
/// Read it with `Theme.of(context).extension<OneBitThemeExtension>()` or the
/// handy `context.oneBitColors` accessor. Widgets must not reach into
/// [OneBitPalette] directly.
///
/// ## ANSI semantic mapping
///
/// Colors follow the IBM 5153 / ANSI terminal palette. They are **not**
/// decorative — every hue carries a specific meaning:
///
/// * **Green** — connected, delivered, verified, trusted, healthy, successful
/// * **Red** — error, failed, blocked, invalid, security warning
/// * **Yellow** — warning, pending, retrying, degraded, expiring
/// * **Cyan** — nearby, discovery, network activity, technical state
/// * **Blue** — links, navigation, selected technical references
/// * **Purple** — identity, cryptographic state, developer information
/// * **White** — normal active content, primary text
/// * **Bright black** — muted metadata, secondary information
@immutable
final class OneBitThemeExtension extends ThemeExtension<OneBitThemeExtension> {
  const OneBitThemeExtension({
    // ── Surface tokens ────────────────────────────────────────────────
    required this.background,
    required this.surface,
    required this.surfaceSecondary,
    required this.surfaceElevated,
    required this.card,
    required this.border,
    required this.divider,
    // ── Text tokens ──────────────────────────────────────────────────
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.disabled,
    // ── Semantic ANSI colors ─────────────────────────────────────────
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
    // ── Domain semantic colors ───────────────────────────────────────
    required this.identity,
    required this.network,
    required this.relay,
    required this.pending,
    // ── Mono surfaces ────────────────────────────────────────────────
    required this.monoBackground,
    // ── Full ANSI palette (normal) ───────────────────────────────────
    required this.ansiBlack,
    required this.ansiRed,
    required this.ansiGreen,
    required this.ansiYellow,
    required this.ansiBlue,
    required this.ansiPurple,
    required this.ansiCyan,
    required this.ansiWhite,
    // ── Full ANSI palette (bright) ───────────────────────────────────
    required this.ansiBrightBlack,
    required this.ansiBrightRed,
    required this.ansiBrightGreen,
    required this.ansiBrightYellow,
    required this.ansiBrightBlue,
    required this.ansiBrightPurple,
    required this.ansiBrightCyan,
    required this.ansiBrightWhite,
  });

  // ── Surface tokens ────────────────────────────────────────────────────

  /// App background color.
  final Color background;

  /// Primary surface color.
  final Color surface;

  /// Secondary surface (menus, sheets, search).
  final Color surfaceSecondary;

  /// Elevated surface (dropdowns, popovers).
  final Color surfaceElevated;

  /// Card surface (distinct from the app surface in both identities).
  final Color card;

  /// Hairline border color.
  final Color border;

  /// Divider line color.
  final Color divider;

  // ── Text tokens ──────────────────────────────────────────────────────

  /// Primary text color.
  final Color textPrimary;

  /// Secondary text color.
  final Color textSecondary;

  /// Muted text (metadata, timestamps).
  final Color textMuted;

  /// Disabled text color.
  final Color disabled;

  // ── Semantic ANSI colors ─────────────────────────────────────────────

  /// Positive outcome color (connected, delivered, verified, trusted).
  final Color success;

  /// Container tint behind [success] content.
  final Color successContainer;

  /// Caution color (warning, pending, retrying).
  final Color warning;

  /// Container tint behind [warning] content.
  final Color warningContainer;

  /// Informational color (nearby, discovery, network).
  final Color info;

  /// Container tint behind [info] content.
  final Color infoContainer;

  // ── Domain semantic colors ───────────────────────────────────────────

  /// Identity / cryptographic state (purple family).
  final Color identity;

  /// Network connectivity (cyan family).
  final Color network;

  /// Relay / mesh forwarding (blue family).
  final Color relay;

  /// Pending / in-progress (yellow family).
  final Color pending;

  // ── Mono surfaces ────────────────────────────────────────────────────

  /// Fixed black used for mono surfaces (console blocks, code).
  final Color monoBackground;

  // ── Full ANSI palette (normal) ───────────────────────────────────────

  /// ANSI Black.
  final Color ansiBlack;

  /// ANSI Red — error, failed, blocked, invalid, security warning.
  final Color ansiRed;

  /// ANSI Green — connected, delivered, verified, trusted, healthy.
  final Color ansiGreen;

  /// ANSI Yellow — warning, pending, retrying, degraded, expiring.
  final Color ansiYellow;

  /// ANSI Blue — links, navigation, selected technical references.
  final Color ansiBlue;

  /// ANSI Purple — identity, cryptographic state, developer information.
  final Color ansiPurple;

  /// ANSI Cyan — nearby, discovery, network activity, technical state.
  final Color ansiCyan;

  /// ANSI White — normal active content, primary text, primary icons.
  final Color ansiWhite;

  // ── Full ANSI palette (bright) ───────────────────────────────────────

  /// ANSI Bright Black — muted metadata, secondary information.
  final Color ansiBrightBlack;

  /// ANSI Bright Red — elevated error emphasis.
  final Color ansiBrightRed;

  /// ANSI Bright Green — elevated success emphasis.
  final Color ansiBrightGreen;

  /// ANSI Bright Yellow — elevated warning emphasis.
  final Color ansiBrightYellow;

  /// ANSI Bright Blue — elevated link emphasis.
  final Color ansiBrightBlue;

  /// ANSI Bright Purple — elevated identity emphasis.
  final Color ansiBrightPurple;

  /// ANSI Bright Cyan — elevated network emphasis.
  final Color ansiBrightCyan;

  /// ANSI Bright White — maximum contrast text.
  final Color ansiBrightWhite;

  // ─── Dark identity ──────────────────────────────────────────────────────

  static const OneBitThemeExtension dark = OneBitThemeExtension(
    background: OneBitPalette.darkBackground,
    surface: OneBitPalette.darkSurface,
    surfaceSecondary: OneBitPalette.darkSurfaceAlt,
    surfaceElevated: OneBitPalette.darkElevated,
    card: OneBitPalette.darkCard,
    border: OneBitPalette.darkBorder,
    divider: OneBitPalette.darkDivider,
    textPrimary: OneBitPalette.darkTextPrimary,
    textSecondary: OneBitPalette.darkTextSecondary,
    textMuted: OneBitPalette.darkTextMuted,
    disabled: OneBitPalette.darkTextDisabled,
    success: OneBitPalette.ansiGreen,
    successContainer: OneBitPalette.darkSuccessContainer,
    warning: OneBitPalette.ansiYellow,
    warningContainer: OneBitPalette.darkWarningContainer,
    info: OneBitPalette.ansiCyan,
    infoContainer: OneBitPalette.darkInfoContainer,
    identity: OneBitPalette.ansiPurple,
    network: OneBitPalette.ansiCyan,
    relay: OneBitPalette.ansiBlue,
    pending: OneBitPalette.ansiYellow,
    monoBackground: OneBitPalette.black,
    ansiBlack: OneBitPalette.ansiBlack,
    ansiRed: OneBitPalette.ansiRed,
    ansiGreen: OneBitPalette.ansiGreen,
    ansiYellow: OneBitPalette.ansiYellow,
    ansiBlue: OneBitPalette.ansiBlue,
    ansiPurple: OneBitPalette.ansiPurple,
    ansiCyan: OneBitPalette.ansiCyan,
    ansiWhite: OneBitPalette.ansiWhite,
    ansiBrightBlack: OneBitPalette.ansiBrightBlack,
    ansiBrightRed: OneBitPalette.ansiBrightRed,
    ansiBrightGreen: OneBitPalette.ansiBrightGreen,
    ansiBrightYellow: OneBitPalette.ansiBrightYellow,
    ansiBrightBlue: OneBitPalette.ansiBrightBlue,
    ansiBrightPurple: OneBitPalette.ansiBrightPurple,
    ansiBrightCyan: OneBitPalette.ansiBrightCyan,
    ansiBrightWhite: OneBitPalette.ansiBrightWhite,
  );

  // ─── Light identity ─────────────────────────────────────────────────────

  /// Light-identity ANSI palette uses brighter variants for readability on
  /// white backgrounds.
  static const OneBitThemeExtension light = OneBitThemeExtension(
    background: OneBitPalette.lightBackground,
    surface: OneBitPalette.lightSurface,
    surfaceSecondary: Color(0xFFF7F7F7),
    surfaceElevated: Color(0xFFECECEC),
    card: OneBitPalette.lightSurface,
    border: OneBitPalette.lightBorder,
    divider: Color(0xFFE4E4E4),
    textPrimary: OneBitPalette.lightPrimary,
    textSecondary: OneBitPalette.lightSecondary,
    textMuted: Color(0xFF999999),
    disabled: Color(0xFFBBBBBB),
    success: Color(0xFF2F7D3B),
    successContainer: OneBitPalette.lightSuccessContainer,
    warning: Color(0xFFB56400),
    warningContainer: OneBitPalette.lightWarningContainer,
    info: Color(0xFF1C63D5),
    infoContainer: OneBitPalette.lightInfoContainer,
    identity: Color(0xFF7B3FA0),
    network: Color(0xFF0E7C7B),
    relay: Color(0xFF1C63D5),
    pending: Color(0xFFB56400),
    monoBackground: Color(0xFF111111),
    ansiBlack: OneBitPalette.ansiBlack,
    ansiRed: Color(0xFFC93A3A),
    ansiGreen: Color(0xFF2F7D3B),
    ansiYellow: Color(0xFFB56400),
    ansiBlue: Color(0xFF1C63D5),
    ansiPurple: Color(0xFF7B3FA0),
    ansiCyan: Color(0xFF0E7C7B),
    ansiWhite: Color(0xFF111111),
    ansiBrightBlack: Color(0xFF666666),
    ansiBrightRed: Color(0xFFC93A3A),
    ansiBrightGreen: Color(0xFF2F7D3B),
    ansiBrightYellow: Color(0xFFB56400),
    ansiBrightBlue: Color(0xFF1C63D5),
    ansiBrightPurple: Color(0xFF7B3FA0),
    ansiBrightCyan: Color(0xFF0E7C7B),
    ansiBrightWhite: Color(0xFF111111),
  );

  @override
  OneBitThemeExtension copyWith({
    Color? background,
    Color? surface,
    Color? surfaceSecondary,
    Color? surfaceElevated,
    Color? card,
    Color? border,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? disabled,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
    Color? identity,
    Color? network,
    Color? relay,
    Color? pending,
    Color? monoBackground,
    Color? ansiBlack,
    Color? ansiRed,
    Color? ansiGreen,
    Color? ansiYellow,
    Color? ansiBlue,
    Color? ansiPurple,
    Color? ansiCyan,
    Color? ansiWhite,
    Color? ansiBrightBlack,
    Color? ansiBrightRed,
    Color? ansiBrightGreen,
    Color? ansiBrightYellow,
    Color? ansiBrightBlue,
    Color? ansiBrightPurple,
    Color? ansiBrightCyan,
    Color? ansiBrightWhite,
  }) {
    return OneBitThemeExtension(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      card: card ?? this.card,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      disabled: disabled ?? this.disabled,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      identity: identity ?? this.identity,
      network: network ?? this.network,
      relay: relay ?? this.relay,
      pending: pending ?? this.pending,
      monoBackground: monoBackground ?? this.monoBackground,
      ansiBlack: ansiBlack ?? this.ansiBlack,
      ansiRed: ansiRed ?? this.ansiRed,
      ansiGreen: ansiGreen ?? this.ansiGreen,
      ansiYellow: ansiYellow ?? this.ansiYellow,
      ansiBlue: ansiBlue ?? this.ansiBlue,
      ansiPurple: ansiPurple ?? this.ansiPurple,
      ansiCyan: ansiCyan ?? this.ansiCyan,
      ansiWhite: ansiWhite ?? this.ansiWhite,
      ansiBrightBlack: ansiBrightBlack ?? this.ansiBrightBlack,
      ansiBrightRed: ansiBrightRed ?? this.ansiBrightRed,
      ansiBrightGreen: ansiBrightGreen ?? this.ansiBrightGreen,
      ansiBrightYellow: ansiBrightYellow ?? this.ansiBrightYellow,
      ansiBrightBlue: ansiBrightBlue ?? this.ansiBrightBlue,
      ansiBrightPurple: ansiBrightPurple ?? this.ansiBrightPurple,
      ansiBrightCyan: ansiBrightCyan ?? this.ansiBrightCyan,
      ansiBrightWhite: ansiBrightWhite ?? this.ansiBrightWhite,
    );
  }

  @override
  OneBitThemeExtension lerp(OneBitThemeExtension? other, double t) {
    if (other is! OneBitThemeExtension) return this;
    return OneBitThemeExtension(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSecondary: Color.lerp(
        surfaceSecondary,
        other.surfaceSecondary,
        t,
      )!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      identity: Color.lerp(identity, other.identity, t)!,
      network: Color.lerp(network, other.network, t)!,
      relay: Color.lerp(relay, other.relay, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      monoBackground: Color.lerp(monoBackground, other.monoBackground, t)!,
      ansiBlack: Color.lerp(ansiBlack, other.ansiBlack, t)!,
      ansiRed: Color.lerp(ansiRed, other.ansiRed, t)!,
      ansiGreen: Color.lerp(ansiGreen, other.ansiGreen, t)!,
      ansiYellow: Color.lerp(ansiYellow, other.ansiYellow, t)!,
      ansiBlue: Color.lerp(ansiBlue, other.ansiBlue, t)!,
      ansiPurple: Color.lerp(ansiPurple, other.ansiPurple, t)!,
      ansiCyan: Color.lerp(ansiCyan, other.ansiCyan, t)!,
      ansiWhite: Color.lerp(ansiWhite, other.ansiWhite, t)!,
      ansiBrightBlack: Color.lerp(ansiBrightBlack, other.ansiBrightBlack, t)!,
      ansiBrightRed: Color.lerp(ansiBrightRed, other.ansiBrightRed, t)!,
      ansiBrightGreen: Color.lerp(ansiBrightGreen, other.ansiBrightGreen, t)!,
      ansiBrightYellow: Color.lerp(
        ansiBrightYellow,
        other.ansiBrightYellow,
        t,
      )!,
      ansiBrightBlue: Color.lerp(ansiBrightBlue, other.ansiBrightBlue, t)!,
      ansiBrightPurple: Color.lerp(
        ansiBrightPurple,
        other.ansiBrightPurple,
        t,
      )!,
      ansiBrightCyan: Color.lerp(ansiBrightCyan, other.ansiBrightCyan, t)!,
      ansiBrightWhite: Color.lerp(ansiBrightWhite, other.ansiBrightWhite, t)!,
    );
  }
}

/// Convenience accessor mounted on [BuildContext].
extension OneBitThemeExtensionContextX on BuildContext {
  /// The resolved semantic color tokens for the active theme.
  OneBitThemeExtension get oneBitColors =>
      Theme.of(this).extension<OneBitThemeExtension>() ??
      OneBitThemeExtension.light;
}
