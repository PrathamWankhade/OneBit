# Coding Standards

Enforced by `analysis_options.yaml` (strict-casts/inference, plus the lints
below) and reviewed in CI via `flutter analyze` with **zero issues**
requirement.

## Architecture rules

1. Dependency flow is inward only: presentation → domain ← data → platform.
2. `features/*/domain/**` must not import Flutter. (Enforced by review; a
   dedicated analyzer rule set lands with the CI hardening phase.)
3. UI never reads repositories; it reads controllers (providers).
4. Repositories never know about widgets.
5. No raw exceptions across feature boundaries — `Result<T>` / `Failure`.
6. No feature imports another feature's presentation layer.

## Code rules

1. Every public class and public member has a doc comment explaining *why*.
2. Single responsibility per file; files ≤ 300 lines; widgets ≤ 150 lines.
3. Immutable models (`final` fields, `copyWith` where mutation is needed).
4. No magic numbers: use design tokens (`AppSpacing`, `AppRadius`,
   `AppMotion`, `AppComponentTokens`).
5. No hardcoded colors: `ColorScheme` / `context.appColors` only.
6. No hardcoded strings: ARB keys via `context.l10n` / `AppLocalizations`.
7. No `print` — use `AppLogger` (injected).
8. `const` constructors everywhere possible; `final` locals by default.
9. Trailing commas; 80-column formatting via `dart format`.

## Workflow

1. `dart format .`
2. `flutter analyze` — must be clean.
3. `flutter test` — must pass.
4. Add a test alongside every new behavior (test/ mirrors lib/).
5. Record structural decisions in `docs/adr/`.
