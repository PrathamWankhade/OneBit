# ADR-0006 — Design tokens as the only visual source of truth

Status: Accepted

## Context

A terminal-first operator console plus light/dark themes tends to spiral into
hard-coded colors/fonts duplicated across features. Without a single source of
truth, theme changes require hunting literals and tokens drift from the
Material 3 color roles.

## Decision

- All visual values live in `shared/design_system/tokens/`:
  `app_palette` (raw colors), `app_spacing` (space/radius/elevation tiers),
  `app_typography` (font families/sizes/weights), `app_icons`,
  `app_component_tokens` (sized by component), `app_motion` (durations/curves).
- `app_theme_data.dart` is the ONLY place tokens are bound to
  `ThemeData`/`newThemeData`; it exposes `AppTheme` variants
  (system / light / dark / terminal) created by `AppThemeController`.
- Widgets read colors via extensions (`context.appColors`) and never mix
  literal hex; spacing/Radius always reference tiers, not magic numbers.
- Component styles (buttons, cards, fields) are parameterized tokens; padding/
  typography in widgets come from tokens (no inline values).

## Consequences

- Dark/light/terminal themes are produced by composing the same palette;
  changing the token set globally in one file.
- New features consume tokens without designing ad-hoc values → visual parity.
- Lint (avoid-using-hex-literals enforced along with tokens in
  `analysis_options.yaml`) rejects regressions in CI.

## Related

- ADR-0001 (Clean Architecture), ADR-0004 (Riverpod).