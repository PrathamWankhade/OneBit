# OneBit

A fully decentralized, offline-first **Bluetooth Low Energy mesh
communication platform**.

> No internet · No cloud · No servers · No phone numbers · No accounts.
> Every device is a node, router, relay, packet cache and secure endpoint.

## Status — Phase 1: Foundation

This repository currently contains the **production-ready project foundation
only**. Bluetooth, messaging, cryptography, routing and database schemas are
deliberately **not implemented**; the foundation declares the seams where
those subsystems will land (see `docs/`).

- Strict Clean Architecture (presentation → domain → data → platform)
- Feature-first slices: `home`, `nearby`, `mesh`, `nodes`, `channels`,
  `settings`, `developer`, `about`
- Riverpod (DI + state, no codegen) · GoRouter · Material 3
- Design token system with Light / Dark / **Terminal** themes
- Result/Failure error framework, tagged logger, ring buffer
- Build tiers: `dev` (debug) / `beta` / `prod` (release)
- L10n (en, hi) via ARB + `flutter gen-l10n`
- CI: analyze → test → flavor build matrix

## Quick start

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter run --flavor dev
```

## Structure

```
lib/
  main.dart, bootstrap.dart       entry + composition root
  app/                            OneBitApp + AppShell
  core/                           framework (config, errors, logger,
                                  result, platform, theme, navigation, widgets)
  shared/                         base classes, design system, localization
  features/<x>/                   presentation · domain · data
android/  cpp/  assets/  docs/  test/  integration_test/
```

See `docs/architecture/` for the full design series, `docs/adr/` for
decision records, and `docs/guidelines/` for standards.
# OneBit
