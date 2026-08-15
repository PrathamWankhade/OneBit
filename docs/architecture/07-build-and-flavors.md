# Build Architecture & Flavors

## Product tiers

Android product flavors (AGP requires flavor names distinct from the reserved
build-type names `debug`/`release`, hence the tier IDs):

| Flavor ID | Tier | applicationId suffix | Dart flavor (`FLAVOR`) | Environment |
| --- | --- | --- | --- | --- |
| `dev` | Debug | `.dev` | `debug` | development |
| `beta` | Beta | `.beta` | `beta` | staging |
| `prod` | Release | *(none)* | `release` | production |

`Flutter` injects the selected flavor as `--dart-define=FLAVOR=<flavorId>`;
`AppConfig` maps the alias (`dev`/`prod`) to the semantic `AppFlavor`
(`debug`/`release`) via `AppFlavor.fromName`.

> **`--flavor` is mandatory** — never run `flutter run` / `flutter build apk`
> without it. In a multi-flavor project, an unflavored `assembleDebug`
> aggregates **all three** variants (`app-dev-debug.apk`,
> `app-beta-debug.apk`, `app-prod-debug.apk`), while the Flutter tool then
> looks for a nonexistent `app-debug.apk` and fails with
> *"Gradle build failed to produce an .apk file"*.

## Builds

```bash
# Debug tier
flutter run --flavor dev
flutter build apk --debug --flavor dev

# Beta
flutter build apk --release --flavor beta

# Production
flutter build apk --release --flavor prod
flutter build appbundle --release --flavor prod
```

## Compile-time knobs (`--dart-define`)

- `FLAVOR` — set by `--flavor`.
- `ENVIRONMENT` — optional override of the flavor's default environment
  (`development` / `staging` / `production`).
- `APP_VERSION` / `APP_BUILD_NUMBER` — optional version overrides (CI).

## Android specifics

- `android/app/build.gradle.kts` — ternative: flavor dimensions `tier`,
  per-flavor `applicationIdSuffix` + `versionNameSuffix` + manifest label
  (`OneBit`, `OneBit Beta`, `OneBit Dev`).
- Manifest uses `${onBitFlavorLabel}`; BLE permissions are intentionally
  **not** declared in Phase 1 (they arrive with the Bluetooth phase).
- Release build types currently sign with the debug keystore; CI must swap
  the store keystore before distribution.

## CI

`.github/workflows/ci.yml` runs, per pushed commit:
1. `flutter analyze`
2. `flutter test`
3. build matrix: `dev` (debug), `beta` (debug), `prod` (release APK).
Artifacts are uploaded only on the configured branches.