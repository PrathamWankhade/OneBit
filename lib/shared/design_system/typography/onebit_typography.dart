import 'package:flutter/material.dart';

/// Typography tokens: font families, type scale, weights and the TextTheme
/// builder.
///
/// OneBit uses a single font family for the entire interface:
///
/// * **Consolas** — a monospace typeface that gives the application its
///   terminal-inspired visual identity. Consolas ships with Windows; on
///   other platforms the system `monospace` family provides a graceful
///   fallback.
///
/// The visual hierarchy is achieved through weight, size and letter-spacing
/// variations — not by mixing font families.
abstract final class OneBitTypography {
  // ─── Families ───────────────────────────────────────────────────────────

  /// Primary application font — Consolas (monospace identity).
  static const String primaryFamily = 'Consolas';

  /// Fallback list for platforms without Consolas (Android, Linux, macOS).
  static const List<String> primaryFallback = ['monospace'];

  /// Technical font — same as primary (unified monospace identity).
  static const String technicalFamily = 'Consolas';

  /// Fallback list for the technical family.
  static const List<String> technicalFallback = ['monospace'];

  // ─── Type scale (pixels) ────────────────────────────────────────────────
  //
  // The scale follows a clear hierarchy:
  //   display (32) > pageTitle (28) > headline (24) > sectionTitle (18) >
  //   cardTitle (17) > body (16) > bodySecondary (14) > caption (12) >
  //   overline (10)

  /// Display — hero text, splash branding. Largest and strongest.
  static const double display = 32;

  /// Page title — primary screen heading.
  static const double pageTitle = 28;

  /// Headline — secondary page heading, large section intro.
  static const double headline = 24;

  /// Section heading — group headers within a page.
  static const double sectionTitle = 18;

  /// Card title — primary text inside cards and list tiles.
  static const double cardTitle = 17;

  /// Body — primary readable content.
  static const double body = 16;

  /// Body secondary — descriptions, supporting content.
  static const double bodySecondary = 14;

  /// Caption — metadata, timestamps, helper text.
  static const double caption = 12;

  /// Overline — section labels, overline headers. Smallest readable size.
  static const double overline = 10;

  /// Terminal — diagnostic, log, technical data. Same as body for readability.
  static const double terminal = 16;

  /// Numeric — tabular data, counters, IDs. Optimized for alignment.
  static const double numeric = 13;

  /// Button — label text inside buttons.
  static const double button = 14;

  // ─── Legacy aliases (kept for backward compatibility) ────────────────────

  /// @deprecated Use [pageTitle] instead.
  static const double title = pageTitle;

  /// @deprecated Use [bodySecondary] instead.
  static const double label = bodySecondary;

  /// @deprecated Use [numeric] instead.
  static const double bodySmall = numeric;

  /// @deprecated Use [numeric] instead.
  static const double technical = numeric;

  /// @deprecated Use [numeric] instead.
  static const double nodeId = numeric;

  /// @deprecated Use [caption] instead.
  static const double fingerprint = caption;

  /// @deprecated Use [caption] instead.
  static const double packetId = caption;

  /// @deprecated Use [caption] instead.
  static const double log = caption;

  /// @deprecated Use [overline] instead.
  static const double diagnostic = overline;

  // ─── Weights ────────────────────────────────────────────────────────────

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // ─── Letter spacing ─────────────────────────────────────────────────────

  /// Tightening for display faces.
  static const double displaySpacing = -0.5;

  /// Tightening for headline faces.
  static const double headlineSpacing = -0.25;

  /// Standard tracking for body text.
  static const double bodySpacing = 0;

  /// Slight loose tracking for technical monospace content.
  static const double technicalSpacing = 0.2;

  /// Tracking for overline labels.
  static const double overlineSpacing = 1.2;

  // ─── Named text style helpers ───────────────────────────────────────────
  //
  // Each helper returns a complete TextStyle with the correct font family,
  // size, weight and spacing. Use these instead of raw TextStyle constructors
  // to keep the design language uniform.

  /// Display — hero text, splash branding (32px semibold, tight tracking).
  static TextStyle oneBitDisplay({Color? color}) {
    return TextStyle(
      fontFamily: primaryFamily,
      fontFamilyFallback: primaryFallback,
      fontSize: display,
      fontWeight: semibold,
      letterSpacing: displaySpacing,
      color: color,
    );
  }

  /// Page title — primary screen heading (28px semibold, tight tracking).
  static TextStyle oneBitPageTitle({Color? color}) {
    return TextStyle(
      fontFamily: primaryFamily,
      fontFamilyFallback: primaryFallback,
      fontSize: pageTitle,
      fontWeight: semibold,
      letterSpacing: headlineSpacing,
      color: color,
    );
  }

  /// Title — primary screen heading. Alias of [oneBitPageTitle].
  static TextStyle oneBitTitle({Color? color}) => oneBitPageTitle(color: color);

  /// Headline — secondary page heading (24px semibold).
  static TextStyle oneBitHeadline({Color? color}) {
    return TextStyle(
      fontFamily: primaryFamily,
      fontFamilyFallback: primaryFallback,
      fontSize: headline,
      fontWeight: semibold,
      letterSpacing: headlineSpacing,
      color: color,
    );
  }

  /// Section heading — group headers (18px semibold).
  static TextStyle oneBitSectionTitle({Color? color}) {
    return TextStyle(
      fontFamily: primaryFamily,
      fontFamilyFallback: primaryFallback,
      fontSize: sectionTitle,
      fontWeight: semibold,
      color: color,
    );
  }

  /// Card title — primary text inside cards (17px semibold).
  static TextStyle oneBitCardTitle({Color? color}) {
    return TextStyle(
      fontFamily: primaryFamily,
      fontFamilyFallback: primaryFallback,
      fontSize: cardTitle,
      fontWeight: semibold,
      color: color,
    );
  }

  /// Body — primary readable content (16px regular).
  static TextStyle oneBitBody({Color? color}) {
    return TextStyle(
      fontFamily: primaryFamily,
      fontFamilyFallback: primaryFallback,
      fontSize: body,
      fontWeight: regular,
      color: color,
    );
  }

  /// Body secondary — descriptions, supporting content (14px regular).
  static TextStyle oneBitBodySecondary({Color? color}) {
    return TextStyle(
      fontFamily: primaryFamily,
      fontFamilyFallback: primaryFallback,
      fontSize: bodySecondary,
      fontWeight: regular,
      color: color,
    );
  }

  /// Label — buttons, labels, interactive text (14px medium).
  static TextStyle oneBitLabel({Color? color}) {
    return TextStyle(
      fontFamily: primaryFamily,
      fontFamilyFallback: primaryFallback,
      fontSize: button,
      fontWeight: medium,
      color: color,
    );
  }

  /// Caption — metadata, timestamps, helper text (12px regular).
  static TextStyle oneBitCaption({Color? color}) {
    return TextStyle(
      fontFamily: primaryFamily,
      fontFamilyFallback: primaryFallback,
      fontSize: caption,
      fontWeight: regular,
      color: color,
    );
  }

  /// Terminal — diagnostic, log, technical data (16px regular, loose tracking).
  static TextStyle oneBitTerminal({Color? color}) {
    return TextStyle(
      fontFamily: technicalFamily,
      fontFamilyFallback: technicalFallback,
      fontSize: terminal,
      fontWeight: regular,
      letterSpacing: technicalSpacing,
      color: color,
    );
  }

  /// Numeric — tabular data, counters, IDs (13px medium, loose tracking).
  static TextStyle oneBitNumeric({Color? color}) {
    return TextStyle(
      fontFamily: technicalFamily,
      fontFamilyFallback: technicalFallback,
      fontSize: numeric,
      fontWeight: medium,
      letterSpacing: technicalSpacing,
      color: color,
    );
  }

  /// Button — label text inside buttons (14px medium).
  static TextStyle oneBitButton({Color? color}) {
    return TextStyle(
      fontFamily: primaryFamily,
      fontFamilyFallback: primaryFallback,
      fontSize: button,
      fontWeight: medium,
      color: color,
    );
  }

  // ─── Legacy style helpers (kept for backward compatibility) ──────────────

  /// @deprecated Use [oneBitSectionTitle] instead.
  static TextStyle sectionTitleStyle({FontWeight? weight, Color? color}) {
    return TextStyle(
      fontFamily: primaryFamily,
      fontFamilyFallback: primaryFallback,
      fontSize: sectionTitle,
      fontWeight: weight ?? semibold,
      color: color,
    );
  }

  /// @deprecated Use [oneBitNumeric] instead.
  static TextStyle nodeIdStyle({Color? color}) {
    return TextStyle(
      fontFamily: technicalFamily,
      fontFamilyFallback: technicalFallback,
      fontSize: numeric,
      fontWeight: medium,
      letterSpacing: technicalSpacing,
      color: color,
    );
  }

  /// @deprecated Use [oneBitCaption] with technical family instead.
  static TextStyle fingerprintStyle({Color? color}) {
    return TextStyle(
      fontFamily: technicalFamily,
      fontFamilyFallback: technicalFallback,
      fontSize: caption,
      fontWeight: regular,
      letterSpacing: technicalSpacing,
      color: color,
    );
  }

  /// @deprecated Use [oneBitCaption] with technical family instead.
  static TextStyle packetIdStyle({Color? color}) {
    return TextStyle(
      fontFamily: technicalFamily,
      fontFamilyFallback: technicalFallback,
      fontSize: caption,
      fontWeight: regular,
      letterSpacing: technicalSpacing,
      color: color,
    );
  }

  /// @deprecated Use [oneBitCaption] with technical family instead.
  static TextStyle logStyle({Color? color}) {
    return TextStyle(
      fontFamily: technicalFamily,
      fontFamilyFallback: technicalFallback,
      fontSize: caption,
      fontWeight: regular,
      color: color,
    );
  }

  /// @deprecated Use [oneBitOverline] instead.
  static TextStyle diagnosticStyle({FontWeight? weight, Color? color}) {
    return TextStyle(
      fontFamily: technicalFamily,
      fontFamilyFallback: technicalFallback,
      fontSize: overline,
      fontWeight: weight ?? regular,
      color: color,
    );
  }

  /// Style skeleton for technical values (IDs, fingerprints, logs).
  ///
  /// Size defaults to [numeric]; consumers may override `fontSize` for
  /// dense diagnostics.
  static TextStyle technicalStyle({
    double fontSize = numeric,
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

  // ─── TextTheme builder ──────────────────────────────────────────────────

  /// Builds the full [TextTheme] on [scheme]'s colors.
  ///
  /// Every text style uses [primaryFamily] (Consolas) with [primaryFallback].
  static TextTheme buildTextTheme(ColorScheme scheme) {
    final base = TextTheme(
      displayLarge: TextStyle(
        fontSize: display,
        fontWeight: semibold,
        letterSpacing: displaySpacing,
        color: scheme.onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: pageTitle,
        fontWeight: semibold,
        letterSpacing: headlineSpacing,
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
        fontSize: sectionTitle,
        fontWeight: semibold,
        color: scheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: body,
        fontWeight: semibold,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: cardTitle,
        fontWeight: semibold,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: body,
        fontWeight: medium,
        color: scheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: bodySecondary,
        fontWeight: semibold,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: body,
        fontWeight: regular,
        color: scheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: bodySecondary,
        fontWeight: regular,
        color: scheme.onSurfaceVariant,
      ),
      bodySmall: TextStyle(
        fontSize: caption,
        fontWeight: regular,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontSize: button,
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

  const OneBitTypography._();
}
