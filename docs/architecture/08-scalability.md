# Scalability Roadmap

The Phase 1 foundation is shaped so the following phases land **without
restructuring**:

## Phase 2 — Identity & Persistence

- Drift schema per feature under `features/<x>/data/`; repositories already
  declare the contracts (`NodeRegistryRepository`, `AppSettingsRepository`…).
- Identity module feeds `nodeId` into `MeshNode`/`NearbyPeer` — fields are
  already on the domain models.
- Settings feature wires `appThemeProvider` + `appLocaleProvider` to the new
  `AppSettingsRepository`; controllers are already provider-based.

## Phase 3 — Native Core (C++)

- `FfiBridge` is the declared seam; `UnavailableFfiBridge` is replaced by the
  real loader **inside the same provider**, nothing else changes.
- `cpp/` already exists with `include/` + `src/`; CMake wiring lands in
  `android/app/build.gradle.kts` `externalNativeBuild` without touching Dart.

## Phase 4 — Bluetooth LE

- Scan/advertise service registers on `PlatformChannels.bluetooth` (already
  declared) in `MainActivity.kt` (shape unchanged).
- `NearbyPeerRepository.observeNearbyPeers()` — contract already in domain —
  gets its BLE-backed implementation in `features/nearby/data/`.
- BLE permissions enter the manifest behind the existing flavor structure.

## Phase 5+ — Mesh, Routing, Messaging, E2EE

- `MeshSessionRepository` owns the radio session; routing/DTN lives behind it.
- Channels feature (`ChannelRepository`) hosts the messaging protocol.
- Cryptography sits behind `FfiBridge` symbol calls; the failure hierarchy
  already has `UnsupportedOperationFailure` for honest degradation.
- Store-and-forward packet cache = one more Drift-backed repository.

## What would require restructuring (and is therefore banned)

| Anti-pattern | Why it breaks |
| --- | --- |
| Presentation importing data impls | transport swap impossible |
| Business logic importing Flutter | no unit tests, no headless CI |
| Raw exceptions across features | no Result-driven control flow |
| Hardcoded colors/strings in widgets | theming + l10n become rework |
| Global singletons instead of providers | no test overrides |
| Flavors named `debug`/`release` | collides with AGP build types |

None of these exist in the Phase 1 tree (verified by `flutter analyze` and
the test suite).
