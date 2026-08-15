import 'package:flutter/material.dart';

/// Typography tokens: font families, type scale, weights and the TextTheme
/// builder.
///
/// OneBit uses a single font family for the entire interface:
///
/// * **Consolas** — a monospace typeface that gives the application its
///   terminal-inspired visual identity. Consolas ships with Windows; on
///   other platforms the system `monospace` family provides a graceful
///   fallback. A future assets phase may bundle a cross-platform monospace
///   font without touching consumers.
///
/// The `technicalStyle` helper exists so widgets that render IDs,
/// fingerprints, packet logs and diagnostics can request the same family
/// explicitly, but all body text, labels, titles and navigation also
/// render in the monospace family — this IS the OneBit visual identity.
abstract final class OneBitTypography {
  // ─── Families ───────────────────────────────────────────────────────────

  /// Primary application font — Consolas (monospace identity).
  ///
  /// On platforms where Consolas is unavailable, the platform monospace
  /// family takes over. The fallback chain is declared in [primaryFallback].
  static const String primaryFamily = 'Consolas';

  /// Fallback list for platforms without Consolas (Android, Linux, macOS).
  static const List<String> primaryFallback = ['monospace'];

  /// Technical font — same as primary (unified monospace identity).
  static const String technicalFamily = 'Consolas';

  /// Fallback list for the technical family.
  static const List<String> technicalFallback = ['monospace'];

  // ─── Type scale (pixels) ────────────────────────────────────────────────
  static const double display = 32;
  static const double headline = 24;
  static const double title = 20;
  static const double sectionTitle = 18;
  static const double body = 16;
  static const double bodyLarge = 18;
  static const double bodySmall = 13;
  static const double label = 14;
  static const double caption = 12;
  static const double overline = 10;
  static const double technical = 13;

  // ─── Technical sizes ────────────────────────────────────────────────────
  static const double nodeId = 13;
  static const double fingerprint = 12;
  static const double packetId = 12;
  static const double log = 12;
  static const double diagnostic = 11;

  // ─── Weights ────────────────────────────────────────────────────────────
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // ─── Letter spacing ─────────────────────────────────────────────────────

  /// Slight tightening for display faces.
  static const double displaySpacing = -0.5;

  /// Slight tightening for headline faces.
  static const double headlineSpacing = -0.25;

  /// Standard tracking for body text.
  static const double bodySpacing = 0;

  /// Slight loose tracking for technical monospace content.
  static const double technicalSpacing = 0.2;

  /// Tracking for overline labels.
  static const double overlineSpacing = 1.2;

  // ─── TextTheme builder ──────────────────────────────────────────────────

  /// Builds the full [TextTheme] on [scheme]'s colors.
  ///
  /// Every text style uses [primaryFamily] (Consolas) with [primaryFallback].
  /// The monospace identity is the visual language of OneBit — there is no
  /// separate "UI font" vs "technical font".
  static TextTheme buildTextTheme(ColorScheme scheme) {
    final base = TextTheme(
      displayLarge: TextStyle(
        fontSize: display,
        fontWeight: semibold,
        letterSpacing: displaySpacing,
        color: scheme.onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: semibold,
        letterSpacing: displaySpacing,
        color: scheme.onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: headline,
        fontWeight: semibold,
        letterSpacing: headlineSpacing,
        color: scheme.onSurface,
      ),
      headlineLarge: TextStyle(
        fontSize: headline,
        fontWeight: semibold,
        letterSpacing: headlineSpacing,
        color: scheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: title,
        fontWeight: semibold,
        color: scheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: body,
        fontWeight: semibold,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: title,
        fontWeight: semibold,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: body,
        fontWeight: medium,
        color: scheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: label,
        fontWeight: semibold,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: bodyLarge,
        fontWeight: regular,
        color: scheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: body,
        fontWeight: regular,
        color: scheme.onSurfaceVariant,
      ),
      bodySmall: TextStyle(
        fontSize: bodySmall,
        fontWeight: regular,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontSize: label,
        fontWeight: medium,
        color: scheme.onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: caption,
        fontWeight: medium,
        color: scheme.onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontSize: overline,
        fontWeight: bold,
        letterSpacing: overlineSpacing,
        color: scheme.onSurfaceVariant,
      ),
    );
    return base.apply(
      fontFamily: primaryFamily,
      fontFamilyFallback: primaryFallback,
    );
  }

  // ─── Named style helpers ────────────────────────────────────────────────

  /// Section title style (18px semibold).
  static TextStyle sectionTitleStyle({FontWeight? weight, Color? color}) {
    return TextStyle(
      fontFamily: primaryFamily,
      fontFamilyFallback: primaryFallback,
      fontSize: sectionTitle,
      fontWeight: weight ?? semibold,
      color: color,
    );
  }

  /// Style for node IDs (e.g. "7F4A...9C21").
  static TextStyle nodeIdStyle({Color? color}) {
    return TextStyle(
      fontFamily: technicalFamily,
      fontFamilyFallback: technicalFallback,
      fontSize: nodeId,
      fontWeight: medium,
      letterSpacing: technicalSpacing,
      color: color,
    );
  }

  /// Style for fingerprints (e.g. "SHA-256 hex digest").
  static TextStyle fingerprintStyle({Color? color}) {
    return TextStyle(
      fontFamily: technicalFamily,
      fontFamilyFallback: technicalFallback,
      fontSize: fingerprint,
      fontWeight: regular,
      letterSpacing: technicalSpacing,
      color: color,
    );
  }

  /// Style for packet IDs / message IDs.
  static TextStyle packetIdStyle({Color? color}) {
    return TextStyle(
      fontFamily: technicalFamily,
      fontFamilyFallback: technicalFallback,
      fontSize: packetId,
      fontWeight: regular,
      letterSpacing: technicalSpacing,
      color: color,
    );
  }

  /// Style for log output / console lines.
  static TextStyle logStyle({Color? color}) {
    return TextStyle(
      fontFamily: technicalFamily,
      fontFamilyFallback: technicalFallback,
      fontSize: log,
      fontWeight: regular,
      color: color,
    );
  }

  /// Style for diagnostic / debug information.
  static TextStyle diagnosticStyle({FontWeight? weight, Color? color}) {
    return TextStyle(
      fontFamily: technicalFamily,
      fontFamilyFallback: technicalFallback,
      fontSize: diagnostic,
      fontWeight: weight ?? regular,
      color: color,
    );
  }

  // ─── Technical style helper ─────────────────────────────────────────────

  /// Style skeleton for technical values (IDs, fingerprints, logs).
  ///
  /// Size defaults to [technical]; consumers may override `fontSize` for
  /// dense diagnostics. In practice this returns the same family as the
  /// main text theme — the helper exists for explicit intent at call sites.
  static TextStyle technicalStyle({
    double fontSize = technical,
    FontWeight? weight,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: technicalFamily,
      fontFamilyFallback: technicalFallback,
      fontSize: fontSize,
      fontWeight: weight,
      letterSpacing: technicalSpacing,
      color: color,
    );
  }

  const OneBitTypography._();
}
