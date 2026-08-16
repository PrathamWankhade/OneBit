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

  /// Primary surface (#111111).
  static const Color darkSurface = Color(0xFF111111);

  /// Secondary / elevated surface — menus, sheets, search (#161616).
  static const Color darkSurfaceAlt = Color(0xFF161616);

  /// Elevated surface (#171717).
  static const Color darkElevated = Color(0xFF171717);

  /// Card surface (#1D1D1D).
  static const Color darkCard = Color(0xFF1D1D1D);

  /// Hairline borders (#2C2C2C).
  static const Color darkBorder = Color(0xFF2C2C2C);

  /// Divider lines (#232323).
  static const Color darkDivider = Color(0xFF232323);

  /// Primary text (#FFFFFF).
  static const Color darkTextPrimary = Color(0xFFFFFFFF);

  /// Secondary text (#A8A8A8).
  static const Color darkTextSecondary = Color(0xFFA8A8A8);

  /// Muted text — metadata, timestamps (#777777).
  static const Color darkTextMuted = Color(0xFF777777);

  /// Disabled text (#5E5E5E).
  static const Color darkTextDisabled = Color(0xFF5E5E5E);

  // ─── Light identity ─────────────────────────────────────────────────────

  /// App background — near-white (#FAFAFA).
  static const Color lightBackground = Color(0xFFFAFAFA);

  /// Primary surface — white (#FFFFFF).
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Secondary surface — slightly off-white (#F5F5F5).
  static const Color lightSurfaceAlt = Color(0xFFF5F5F5);

  /// Elevated surface — for dropdowns, popovers (#EEEEEE).
  static const Color lightElevated = Color(0xFFEEEEEE);

  /// Card surface — white (#FFFFFF).
  static const Color lightCard = Color(0xFFFFFFFF);

  /// Hairline borders — light gray (#D8D8D8).
  static const Color lightBorder = Color(0xFFD8D8D8);

  /// Divider lines — lighter gray (#E4E4E4).
  static const Color lightDivider = Color(0xFFE4E4E4);

  /// Primary text / controls — near-black (#111111).
  static const Color lightPrimary = Color(0xFF111111);

  /// Secondary text — dark gray (#666666).
  static const Color lightSecondary = Color(0xFF666666);

  /// Muted text — medium gray (#999999).
  static const Color lightTextMuted = Color(0xFF999999);

  /// Disabled text — medium gray (#BBBBBB).
  static const Color lightTextDisabled = Color(0xFFBBBBBB);

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

  // ─── Selection / navigation tokens ─────────────────────────────────────

  /// Dark-theme selected background (charcoal on near-black).
  static const Color darkSelectedBackground = Color(0xFF2A2A2A);

  /// Dark-theme selected foreground/icon (white on charcoal).
  static const Color darkSelectedForeground = Color(0xFFFFFFFF);

  /// Light-theme selected background (light gray on white).
  static const Color lightSelectedBackground = Color(0xFFE0E0E0);

  /// Light-theme selected foreground/icon (near-black on light gray).
  static const Color lightSelectedForeground = Color(0xFF111111);

  // ─── IBM 5153 / ANSI semantic palette ───────────────────────────────────
  //
  // Normal intensity — used as the base semantic set on dark backgrounds.
  // On light backgrounds, the bright variants are used for better contrast.
  static const Color ansiBlack = Color(0xFF000000);
  static const Color ansiRed = Color(0xFFAA0000);
  static const Color ansiGreen = Color(0xFF00AA00);
  static const Color ansiYellow = Color(0xFFAA5500);
  static const Color ansiBlue = Color(0xFF0000AA);
  static const Color ansiPurple = Color(0xFFAA00AA);
  static const Color ansiCyan = Color(0xFF00AAAA);
  static const Color ansiWhite = Color(0xFFAAAAAA);

  // Bright intensity — elevated emphasis, hover, active states.
  // On dark backgrounds these are vivid; on light backgrounds these
  // provide sufficient contrast against white.
  static const Color ansiBrightBlack = Color(0xFF555555);
  static const Color ansiBrightRed = Color(0xFFFF5555);
  static const Color ansiBrightGreen = Color(0xFF55FF55);
  static const Color ansiBrightYellow = Color(0xFFFFFF55);
  static const Color ansiBrightBlue = Color(0xFF5555FF);
  static const Color ansiBrightPurple = Color(0xFFFF55FF);
  static const Color ansiBrightCyan = Color(0xFF55FFFF);
  static const Color ansiBrightWhite = Color(0xFFFFFFFF);

  // ─── Light-identity ANSI palette (for readability on white) ─────────────
  //
  // On light backgrounds, the normal ANSI palette is too dark/saturated.
  // These lighter variants maintain the semantic meaning while being
  // readable on white surfaces.

  /// Light-theme ANSI Red — readable on white.
  static const Color lightAnsiRed = Color(0xFFC93A3A);

  /// Light-theme ANSI Green — readable on white.
  static const Color lightAnsiGreen = Color(0xFF2F7D3B);

  /// Light-theme ANSI Yellow — readable on white.
  static const Color lightAnsiYellow = Color(0xFFB56400);

  /// Light-theme ANSI Blue — readable on white.
  static const Color lightAnsiBlue = Color(0xFF1C63D5);

  /// Light-theme ANSI Purple — readable on white.
  static const Color lightAnsiPurple = Color(0xFF7B3FA0);

  /// Light-theme ANSI Cyan — readable on white.
  static const Color lightAnsiCyan = Color(0xFF0E7C7B);

  /// Light-theme ANSI Bright Red — elevated emphasis on white.
  static const Color lightAnsiBrightRed = Color(0xFFA52828);

  /// Light-theme ANSI Bright Green — elevated emphasis on white.
  static const Color lightAnsiBrightGreen = Color(0xFF1E6B28);

  /// Light-theme ANSI Bright Yellow — elevated emphasis on white.
  static const Color lightAnsiBrightYellow = Color(0xFF8A4800);

  /// Light-theme ANSI Bright Blue — elevated emphasis on white.
  static const Color lightAnsiBrightBlue = Color(0xFF1249A8);

  /// Light-theme ANSI Bright Purple — elevated emphasis on white.
  static const Color lightAnsiBrightPurple = Color(0xFF5C2D80);

  /// Light-theme ANSI Bright Cyan — elevated emphasis on white.
  static const Color lightAnsiBrightCyan = Color(0xFF095C5B);

  /// Light-theme ANSI Bright Black — muted on white.
  static const Color lightAnsiBrightBlack = Color(0xFF888888);

  /// Light-theme ANSI Bright White — near-black on white.
  static const Color lightAnsiBrightWhite = Color(0xFF222222);

  const OneBitPalette._();
}
