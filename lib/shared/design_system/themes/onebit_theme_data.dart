import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:onebit/core/theme/theme_preference.dart';
import 'package:onebit/shared/design_system/colors/onebit_color_schemes.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Builds the complete [ThemeData] for both identities.
///
/// All geometry and colors come from the design tokens; this file is the
/// single place where tokens are bound into Material 3 component themes.
abstract final class OneBitThemeData {
  const OneBitThemeData._();

  /// Builds the theme for [preference].
  ///
  /// `system` has no rendering meaning here — devices resolve it at runtime
  /// via `ThemeMode.system` — so it resolves to the light identity; callers
  /// that need `ThemeData` for both identities should use
  /// [OneBitLightTheme.build] and [OneBitDarkTheme.build] directly.
  static ThemeData build(ThemePreference preference) => switch (preference) {
    ThemePreference.dark => OneBitDarkTheme.build(),
    ThemePreference.light || ThemePreference.system => OneBitLightTheme.build(),
  };
}

/// The dark identity: near-black monochrome.
abstract final class OneBitDarkTheme {
  const OneBitDarkTheme._();

  static ThemeData build() =>
      _buildBase(OneBitColorSchemes.dark(), OneBitThemeExtension.dark);
}

/// The light identity: paper-white monochrome.
abstract final class OneBitLightTheme {
  const OneBitLightTheme._();

  static ThemeData build() =>
      _buildBase(OneBitColorSchemes.light(), OneBitThemeExtension.light);
}

ThemeData _buildBase(ColorScheme scheme, OneBitThemeExtension extension) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: OneBitTypography.buildTextTheme(scheme),
    extensions: [extension],
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    splashFactory: InkRipple.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OneBitInputTokens.fillRadius),
        borderSide: BorderSide(
          width: OneBitInputTokens.borderWidth,
          color: scheme.outlineVariant,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OneBitInputTokens.fillRadius),
        borderSide: BorderSide(
          width: OneBitInputTokens.borderWidth,
          color: scheme.outlineVariant,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OneBitInputTokens.fillRadius),
        borderSide: BorderSide(
          width: OneBitInputTokens.errorBorderWidth,
          color: scheme.primary,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: OneBitInputTokens.horizontalPadding,
        vertical: OneBitInputTokens.verticalPadding,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OneBitButtonTokens.cornerRadius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OneBitButtonTokens.cornerRadius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OneBitButtonTokens.cornerRadius),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OneBitShapeTokens.chipRadius),
      ),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OneBitShapeTokens.dialogRadius),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(OneBitShapeTokens.bottomSheetRadius),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: OneBitNavigationTokens.barHeight,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontSize: OneBitNavigationTokens.labelFontSize,
          fontWeight: OneBitTypography.medium,
        ),
      ),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          OneBitNavigationTokens.indicatorRadius,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OneBitCardTokens.cornerRadius),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: OneBitSpacing.xl,
    ),
  );
}
