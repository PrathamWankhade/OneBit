# Theming & Design Tokens

## Source of truth

One directory, `shared/design_system/`, holds **every** visual decision:

```
tokens (raw values)
  ├── AppSpacing     4/8/12/16/20/24/32/48
  ├── AppRadius      xs…xl, pill, circular
  ├── AppElevation   flat…level3
  ├── AppMotion      durations + curves
  └── AppComponentTokens  button / input / card / navigation / icon
colors/
  ├── AppPalette     raw hex values (the ONLY literals in the codebase)
  └── AppColorSchemes→ 3 ColorSchemes + AppThemeExtension
typography/
  └── AppTypography  type scale + TextTheme builder
themes/
  └── AppThemeData   tokens → ThemeData (component themes bound here)
```

`app_theme_data.dart` is the single place where tokens are bound into
Material 3 component themes (`FilledButton`, `InputDecoration`,
`NavigationBar`, `Card`, `SnackBar`…). Widgets never build their own theme
objects.

## Consumption rules

1. Widgets read semantic colors from `ColorScheme` or
   `context.appColors` (the `AppThemeExtension`) — **never** `AppPalette`.
2. Widgets read size/radius/motion from tokens (`AppSpacing`, `AppMotion`) —
   **never** literal numbers.
3. Component geometry lives in `app_component_tokens.dart`; components
   (`AppButton`, `AppCard`, …) reference it.
4. Icons resolve through `AppIcons`; labels through ARB; everything else
   through tokens. Result: no magic numbers, no hardcoded colors/strings.

## The three identities

| Theme | ColorScheme | Notes |
| --- | --- | --- |
| `light` | seeded teal, light surfaces | classic |
| `dark` | seeded teal, dark surfaces | default Phase 1 |
| `terminal` | hand-built phosphor palette + `monospace` family | console aesthetic; border-based elevation (no ambient light) |

Selection is owned by `appThemeProvider` (`AppThemeController`); `OneBitApp`
rebuilds `MaterialApp` with `AppTheme.of(type)`. `AppThemeData.build(type)`
is fully unit-tested (`test/shared/design/app_theme_test.dart`).