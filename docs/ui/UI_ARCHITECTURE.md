# UI Architecture

## Presentation layer

OneBit follows Clean Architecture. The presentation layer lives in two places:

- `lib/shared/design_system/` — the token, theme and component foundation. It
  is framework-agnostic UI infrastructure owned by no single feature.
- `lib/features/*/presentation/` — feature screens, controllers (Riverpod
  `Notifier`/`AsyncNotifier`) and feature-local widgets.
- `lib/core/theme/` — the theme facade and `ThemePreference` that the app
  shell binds into `MaterialApp`.
- `lib/core/widgets/` — app-wide scaffolds (`OneBitScaffold`,
  `OneBitAsyncView`) that compose design-system components.

There is no separate `lib/presentation/` tree; the folder structure was
adapted to the existing feature-first architecture (see
`docs/architecture/02-folder-structure.md`). Do not introduce one.

## Dependency direction

```
features/*/presentation  ──►  shared/design_system  ──►  core/theme
        │                                  ▲
        └──► core/widgets ─────────────────┘
```

Presentation may import the design system and core theme. It never imports
data, database, transport or cross-feature domain directly; feature state is
reached through feature providers.

## Loading the theme

`MaterialApp` binds:

```dart
MaterialApp(
  theme: OneBitTheme.light,
  darkTheme: OneBitTheme.dark,
  themeMode: themePreferenceProvider.themeMode,
)
```

The `themePreferenceProvider` (Riverpod) owns the `ThemePreference`
(`system` | `light` | `dark`). `OneBitTheme.of(preference)` exists for
contexts that need a resolved identity; `system` resolves to the light
identity because runtime resolution is delegated to `ThemeMode.system`.

## Rules for screens

1. Import `package:onebit/shared/design_system/design_system.dart` for
   tokens (colors, spacing, typography, motion, icons, responsive).
2. Import concrete component files (`onebit_card.dart`, `onebit_button.dart`,
   …) only; the barrel intentionally does not export components.
3. Screens never construct `ThemeData`, `ColorScheme` or `TextStyle` literals;
   they read colors from `Theme.of(context).colorScheme` /
   `context.oneBitColors` and styles from the ambient `TextTheme`.
4. Screens never hardcode sizes, radii or durations — tokens only.
5. Every screen composes from the component foundation; do not re-implement
   buttons, cards, inputs or states inline.
6. `OneBitScaffold` provides the shell chrome (app bar, navigation,
   responsive layout, async state). New screens build inside it instead of a
   raw `Scaffold` where the app shell applies.
7. All user-facing strings are localizable (ARB) — never inline literals in
   production code; screens localize through the l10n layer
   (`lib/l10n/`, `l10n.yaml`).

## Testability

- Widget tests mount components under `oneBitApp` / `oneBitDarkApp`
  (`test/shared/design/support/design_support.dart`).
- Screens are tested against real design-system widgets — no fake
  repositories, no fake data services inside component tests.
- See `docs/architecture/06-testing.md` for the overall strategy.