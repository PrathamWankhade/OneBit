# Theme System

## Identities

OneBit ships exactly two visual identities plus a system-follow mode:

| Identity | Personality | Scheme |
| --- | --- | --- |
| `OneBitDarkTheme` | near-black monochrome | `OneBitColorSchemes.dark()` |
| `OneBitLightTheme` | paper-white monochrome | `OneBitColorSchemes.light()` |
| `ThemePreference.system` | follows platform brightness | resolved via `ThemeMode.system` |

There is no third "terminal" identity — the whole design language is
monochrome in both directions.

## Structure

```
core/theme/
├── onebit_theme.dart                  OneBitTheme facade
├── theme_preference.dart              ThemePreference (system|light|dark)
└── theme_preference_provider.dart     Riverpod provider (presentation state)

shared/design_system/
├── colors/onebit_palette.dart         raw hex values (the only literals)
├── colors/onebit_color_schemes.dart   ColorScheme + OneBitThemeExtension
├── typography/onebit_typography.dart  type scale + TextTheme builder
├── themes/onebit_theme_data.dart      OneBitDarkTheme / OneBitLightTheme /
│                                       OneBitThemeData (tokens → ThemeData)
```

## Color tokens

Dark palette: background `#090909`, surface `#111111`, secondary surface
`#171717`, card `#1D1D1D`, border `#2C2C2C`, divider `#2D2D2D`, primary text
`#FFFFFF`, secondary text `#A8A8A8`, disabled `#5E5E5E`.

Light palette: background `#FAFAFA`, surface `#FFFFFF`, border `#D8D8D8`,
primary `#111111`, secondary `#666666`.

All `ColorScheme` fields are hand-assembled from these values —
never `ColorScheme.fromSeed` — so Material's tonal derivation cannot dilute
the monochrome identity. `surfaceTint` is transparent and card elevation is
zero: depth comes from surfaces and hairline borders, not shadows.

Semantic state colors (success/warning/error/info) are neutral-tinted
containers exposed on `OneBitThemeExtension` (`context.oneBitColors`).
Widgets must never read `OneBitPalette` directly.

## ThemeData binding

`OneBitThemeData` is the single place tokens are bound into Material 3
component themes:

- `inputDecorationTheme` — filled fields, `OneBitRadius.md` corners,
  1dp outline border, 2dp primary focus border
- `filledButtonTheme` / `outlinedButtonTheme` / `textButtonTheme` —
  button radius token
- `chipTheme` — pill radius, outline variant side
- `dialogTheme` / `bottomSheetTheme` — surfaceContainerLow, `OneBitRadius.xl`
  radius
- `navigationBarTheme` — 72dp height, tokenized labels/indicator
- `cardTheme` — zero elevation, `OneBitRadius.lg` radius
- `dividerTheme` — outline variant color, 1dp thickness
- `snackBarTheme` — floating, inverse surface
- `pageTransitionsTheme` — restrained fades on Android/macOS/Windows/Linux,
  native iOS transitions

## Theme selection

`ThemePreference` (`system`, `light`, `dark`) is the single selection model.
`MaterialApp` receives:

```dart
themeMode: themePreferenceProvider.themeMode
```

Persistence of the preference is owned by the settings feature when it ships;
the presentation layer only exposes the provider. Mode resolution never
happens inside widgets.

## Rules

1. Never build a `ThemeData` inside a widget — call `OneBitTheme.*` or read
   the ambient theme.
2. Never introduce a color into a widget that is not already in the
   `ColorScheme` or `OneBitThemeExtension`.
3. Component themes are customized here, not per-widget.
4. `flutter analyze` gates the palette — any literal color outside
   `onebit_palette.dart` is a violation.