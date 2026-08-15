# Accessibility

## Foundation

All accessibility behavior is provided once in
`lib/shared/design_system/accessibility/onebit_accessibility.dart` and
composed by components. It must never be re-implemented ad-hoc inside
individual screens.

The foundation covers:

- TalkBack / screen readers
- dynamic text (text scaling)
- high contrast
- reduced motion
- 48dp minimum interactive targets
- semantic labels and roles
- landscape, tablet and foldable layouts (see `RESPONSIVE_DESIGN.md`)

## Targets

- `OneBitAccessibility.minInteractiveSize` — 48dp, the minimum interactive
  target per Material guidance.
- `OneBitAccessibility.minVisualSize` — 24dp, minimum visual size for
  non-primary controls.

`OneBitTapTarget` wraps compact visuals (row chevrons, inline icons) and
guarantees a ≥48dp hit target while the visual stays compact. It exposes
`button`, `enabled` and `label` semantics and handles tap/long-press. Use it
whenever a small visual element carries an action.

`OneBitIconButton` already enforces the 48dp target internally — do not wrap
it again.

## Semantics conventions

- Every interactive element carries a semantic label; decorative glyphs are
  excluded with `OneBitSemantics.decorative(child)` (an `ExcludeSemantics`
  wrapper).
- Components that announce a container label (badges, status chips) exclude
  their inner `Text` from semantics so screen readers announce exactly one
  label (e.g. "Connected", "5 unread items") instead of a doubled
  "Connected\nConnected".
- Icon buttons take a `tooltip`, which doubles as the semantic label.
- Semantic labels for user-facing strings are localizable — pass localized
  strings (ARB) as `semanticsLabel`/`tooltip` parameters; never hardcode
  English in components.

## Text scaling

- Component heights are **minimums**, not fixed sizes: buttons, chips and
  inputs grow as the platform text scaler increases instead of clipping
  (verified by the dynamic-text tests under
  `test/shared/design/components/navigation_scaling_test.dart`).
- `EditableText`/`TextField` honor the ambient `MediaQuery.textScaler` — do
  not pin them.
- Never use `textScaleFactor` overrides to pin content.
- Test large scales (≥2.0–3.0) when changing geometry.

## Reduced motion

- All durations route through `OneBitMotion.resolve(context, duration)` (or
  `context.motionDuration(...)`), which collapses to `Duration.zero` when
  the platform requests reduced motion (`MediaQuery.disableAnimationsOf`).
- No infinite decorative animation may block screen-reader navigation or
  test settling.

## High contrast

- Semantic colors come from the `ColorScheme`/`OneBitThemeExtension` in both
  identities and pass WCAG AA for text-on-surface pairs.
- The monochrome scale guarantees strong text contrast; do not lower
  contrast by mixing in paler tokens.

## Rules for screens

1. Wrap every tappable compact visual in `OneBitTapTarget`.
2. Provide localized semantics labels for icon-only actions.
3. Exclude purely decorative graphics via `OneBitSemantics.decorative`.
4. Never rebuild these helpers per screen — compose them.
5. Keep interactive targets ≥48dp and let content grow with text scaling.