import 'package:flutter/material.dart';

/// Raw color values for the OneBit monochrome identities.
///
/// These are the **only** literal colors in the codebase. Widgets must never
/// hardcode a `Color`; they read semantic colors from `ColorScheme` /
/// `OneBitThemeExtension`, which are built from these values.
///
/// The Product identity is monochrome: pure black, charcoal greys and a single
/// accent-free scale. Gradients, neon and saturated tints are deliberately
/// absent.
abstract final class OneBitPalette {
  // ─── Dark identity ──────────────────────────────────────────────────────

  /// App background — pure black (#000000).
  static const Color darkBackground = Color(0xFF000000);

  /// Primary surface (#050505).
  static const Color darkSurface = Color(0xFF050505);

  /// Secondary / elevated surface — menus, sheets, search (#101010).
  static const Color darkSurfaceAlt = Color(0xFF101010);

  /// Elevated surface (#171717).
  static const Color darkElevated = Color(0xFF171717);

  /// Card surface (#1E1E1E).
  static const Color darkCard = Color(0xFF1E1E1E);

  /// Hairline borders (#3A3A3A).
  static const Color darkBorder = Color(0xFF3A3A3A);

  /// Divider lines (#2D2D2D).
  static const Color darkDivider = Color(0xFF2D2D2D);

  /// Primary text (#FFFFFF).
  static const Color darkTextPrimary = Color(0xFFFFFFFF);

  /// Secondary text (#B8B8B8).
  static const Color darkTextSecondary = Color(0xFFB8B8B8);

  /// Muted text — metadata, timestamps (#777777).
  static const Color darkTextMuted = Color(0xFF777777);

  /// Disabled text (#555555).
  static const Color darkTextDisabled = Color(0xFF555555);

  // ─── Light identity ─────────────────────────────────────────────────────

  /// App background.
  static const Color lightBackground = Color(0xFFFAFAFA);

  /// Primary surface.
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Hairline borders.
  static const Color lightBorder = Color(0xFFD8D8D8);

  /// Primary text / controls.
  static const Color lightPrimary = Color(0xFF111111);

  /// Secondary text.
  static const Color lightSecondary = Color(0xFF666666);

  // ─── Semantic states (both identities) ──────────────────────────────────

  /// Deep neutrals used for tinted status containers on dark surfaces.
  static const Color darkSuccessContainer = Color(0xFF1C3624);
  static const Color darkWarningContainer = Color(0xFF3A2E14);
  static const Color darkErrorContainer = Color(0xFF3A1818);
  static const Color darkInfoContainer = Color(0xFF16273D);

  /// Pale neutrals used for tinted status containers on light surfaces.
  static const Color lightSuccessContainer = Color(0xFFE3F2E6);
  static const Color lightWarningContainer = Color(0xFFFDF0DB);
  static const Color lightErrorContainer = Color(0xFFFBE0E0);
  static const Color lightInfoContainer = Color(0xFFE2ECFA);

  /// Fixed black used for mono surfaces (drop shadows, console blocks).
  static const Color black = Color(0xFF000000);

  // ─── IBM 5153 / ANSI semantic palette ───────────────────────────────────
  //
  // Normal intensity — used as the base semantic set.
  static const Color ansiBlack = Color(0xFF000000);
  static const Color ansiRed = Color(0xFFAA0000);
  static const Color ansiGreen = Color(0xFF00AA00);
  static const Color ansiYellow = Color(0xFFAA5500);
  static const Color ansiBlue = Color(0xFF0000AA);
  static const Color ansiPurple = Color(0xFFAA00AA);
  static const Color ansiCyan = Color(0xFF00AAAA);
  static const Color ansiWhite = Color(0xFFAAAAAA);

  // Bright intensity — elevated emphasis, hover, active states.
  static const Color ansiBrightBlack = Color(0xFF555555);
  static const Color ansiBrightRed = Color(0xFFFF5555);
  static const Color ansiBrightGreen = Color(0xFF55FF55);
  static const Color ansiBrightYellow = Color(0xFFFFFF55);
  static const Color ansiBrightBlue = Color(0xFF5555FF);
  static const Color ansiBrightPurple = Color(0xFFFF55FF);
  static const Color ansiBrightCyan = Color(0xFF55FFFF);
  static const Color ansiBrightWhite = Color(0xFFFFFFFF);

  const OneBitPalette._();
}
