import 'package:flutter/material.dart';

/// F1 Design Foundation — Terminal + WhatsApp UI hybrid.
///
/// Pure black IBM 5153 palette with WhatsApp-style layout patterns.
/// Proportional font for headings/body, monospace for technical data.
class AppTheme {
  AppTheme._();

  // ── IBM 5153 Palette ─────────────────────────────────────────────

  // Backgrounds
  static const bgBase = Color(0xFF000000);
  static const bgSurface = Color(0xFF0A0A0A);
  static const bgElevated = Color(0xFF141414);
  static const bgOverlay = Color(0xFF1E1E1E);
  static const bgMuted = Color(0xFF282828);

  // Text
  static const textPrimary = Color(0xFFAAAAAA);
  static const textSecondary = Color(0xFF555555);
  static const textTertiary = Color(0xFF444444);
  static const textDisabled = Color(0xFF333333);

  // IBM 5153 — Standard
  static const red = Color(0xFFAA0000);
  static const green = Color(0xFF00AA00);
  static const yellow = Color(0xFFAA5500);
  static const blue = Color(0xFF0000AA);
  static const purple = Color(0xFFAA00AA);
  static const cyan = Color(0xFF00AAAA);
  static const white = Color(0xFFAAAAAA);

  // IBM 5153 — Bright
  static const brightRed = Color(0xFFFF5555);
  static const brightGreen = Color(0xFF55FF55);
  static const brightYellow = Color(0xFFFFFF55);
  static const brightBlue = Color(0xFF5555FF);
  static const brightPurple = Color(0xFFFF55FF);
  static const brightCyan = Color(0xFF55FFFF);
  static const brightWhite = Color(0xFFFFFFFF);

  // Accent — Cyan (IBM 5153 primary highlight)
  static const accent = Color(0xFF00AAAA);
  static const accentMuted = Color(0xFF005555);
  static const accentStrong = Color(0xFF55FFFF);

  // Semantic aliases — Meaning-based palette
  static const amber = yellow;
  static const purple_ = purple;

  // ── Semantic Colors ──────────────────────────────────────────────

  /// Trust / verification
  static const trust = green;
  static const trustMuted = Color(0xFF005500);

  /// Danger / destructive
  static const danger = brightRed;
  static const dangerMuted = Color(0xFF550000);

  /// Warning
  static const warning = amber;
  static const warningMuted = Color(0xFF553300);

  /// Mesh / network
  static const mesh = green;
  static const meshMuted = Color(0xFF003300);

  /// Biometric / QR
  static const biometric = brightPurple;
  static const biometricMuted = Color(0xFF330033);

  /// Secondary / muted
  static const secondary = Color(0xFF666666);

  // Border
  static const borderSubtle = Color(0xFF1E1E1E);
  static const borderDefault = Color(0xFF282828);
  static const divider = Color(0xFF1A1A1A);

  // Overlay
  static const overlayDark = Color(0xCC000000);

  // ── Spacing ──────────────────────────────────────────────────────

  static const double space0 = 0;
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;
  static const double space64 = 64;

  // ── Icon Sizes ───────────────────────────────────────────────────

  static const double iconXs = 14;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;
  static const double iconXl = 36;

  // ── Border Radius ────────────────────────────────────────────────

  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 14;
  static const double radiusXl = 20;
  static const double radiusFull = 999;

  // ── Typography ───────────────────────────────────────────────────

  static const _fontProportional = '.SF Pro Text';
  static const _fontMono = 'Consolas';

  // ── Theme Builder ─────────────────────────────────────────────────

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: _fontProportional,
        scaffoldBackgroundColor: bgBase,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: accent,
          onPrimary: bgBase,
          primaryContainer: accentMuted,
          onPrimaryContainer: brightWhite,
          secondary: bgElevated,
          onSecondary: brightWhite,
          secondaryContainer: bgOverlay,
          onSecondaryContainer: brightWhite,
          surface: bgSurface,
          onSurface: brightWhite,
          surfaceContainerHighest: bgElevated,
          onSurfaceVariant: white,
          outline: borderDefault,
          outlineVariant: borderDefault,
          error: brightRed,
          onError: bgBase,
          errorContainer: dangerMuted,
          onErrorContainer: brightRed,
          tertiary: brightBlue,
          onTertiary: bgBase,
          shadow: Colors.black,
          scrim: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bgSurface,
          foregroundColor: brightWhite,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: _fontProportional,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: brightWhite,
          ),
        ),
        cardTheme: CardThemeData(
          color: bgElevated,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            side: const BorderSide(color: borderSubtle, width: 0.5),
          ),
          margin: EdgeInsets.zero,
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
          tileColor: Colors.transparent,
          selectedTileColor: Color(0xFF003333),
        ),
        dividerTheme: const DividerThemeData(
          color: divider,
          thickness: 0.5,
          space: 0,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: bgElevated,
          contentTextStyle: const TextStyle(
            fontFamily: _fontProportional,
            color: brightWhite,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: bgElevated,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: bgElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bgMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusXl),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusXl),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusXl),
            borderSide: const BorderSide(color: accent, width: 1),
          ),
          hintStyle: const TextStyle(color: textTertiary, fontSize: 16),
          labelStyle: const TextStyle(color: textSecondary, fontSize: 16),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: bgBase,
            disabledBackgroundColor: bgMuted,
            disabledForegroundColor: textDisabled,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusXl),
            ),
            textStyle: const TextStyle(
              fontFamily: _fontProportional,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: brightWhite,
            disabledForegroundColor: textDisabled,
            side: const BorderSide(color: borderDefault),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusXl),
            ),
            textStyle: const TextStyle(
              fontFamily: _fontProportional,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusXl),
            ),
            textStyle: const TextStyle(
              fontFamily: _fontProportional,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: white,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: bgSurface,
          indicatorColor: const Color(0xFF003333),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontFamily: _fontProportional,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? brightCyan : white,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 24,
              color: selected ? brightCyan : white,
            );
          }),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: brightCyan,
          unselectedLabelColor: white,
          indicatorColor: brightCyan,
          labelStyle: TextStyle(
            fontFamily: _fontProportional,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: _fontProportional,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: bgMuted,
          selectedColor: const Color(0xFF003333),
          disabledColor: bgOverlay,
          labelStyle: const TextStyle(
            fontFamily: _fontProportional,
            fontSize: 13,
            color: brightWhite,
          ),
          secondaryLabelStyle: const TextStyle(
            fontFamily: _fontProportional,
            fontSize: 13,
            color: brightWhite,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusFull),
            side: const BorderSide(color: borderSubtle),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return bgBase;
            return textTertiary;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accent;
            return bgOverlay;
          }),
          trackOutlineColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accent;
            return borderDefault;
          }),
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accent;
            return textTertiary;
          }),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accent;
            return Colors.transparent;
          }),
          side: const BorderSide(color: textTertiary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: accent,
          linearTrackColor: bgMuted,
        ),
      );

  // ── Text Styles — Proportional (headings & body) ─────────────────

  static const displayLarge = TextStyle(
    fontFamily: _fontProportional,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 40 / 32,
    letterSpacing: -0.02,
    color: brightWhite,
  );

  static const headlineMedium = TextStyle(
    fontFamily: _fontProportional,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 32 / 24,
    letterSpacing: -0.01,
    color: brightWhite,
  );

  static const titleLarge = TextStyle(
    fontFamily: _fontProportional,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
    color: brightWhite,
  );

  static const titleMedium = TextStyle(
    fontFamily: _fontProportional,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 22 / 16,
    color: brightWhite,
  );

  static const bodyLarge = TextStyle(
    fontFamily: _fontProportional,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
    color: brightWhite,
  );

  static const bodyMedium = TextStyle(
    fontFamily: _fontProportional,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    color: brightWhite,
  );

  static const bodySmall = TextStyle(
    fontFamily: _fontProportional,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
    letterSpacing: 0.01,
    color: white,
  );

  static const labelMedium = TextStyle(
    fontFamily: _fontProportional,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    letterSpacing: 0.02,
    color: white,
  );

  static const caption = TextStyle(
    fontFamily: _fontProportional,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 14 / 11,
    letterSpacing: 0.02,
    color: textSecondary,
  );

  // ── Text Styles — Monospace (technical data, IDs, fingerprints) ──

  static const technical = TextStyle(
    fontFamily: _fontMono,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
    letterSpacing: 0.01,
    color: brightCyan,
  );

  static const technicalSmall = TextStyle(
    fontFamily: _fontMono,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 14 / 11,
    letterSpacing: 0.01,
    color: cyan,
  );

  static const technicalBody = TextStyle(
    fontFamily: _fontMono,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    color: brightWhite,
  );

  static const technicalTitle = TextStyle(
    fontFamily: _fontMono,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 22 / 16,
    color: brightWhite,
  );
}
