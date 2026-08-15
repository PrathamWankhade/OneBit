# OneBit Architecture

OneBit is a **fully decentralized, offline-first Bluetooth Low Energy mesh
communication platform**. Every device is simultaneously:

- a user device,
- a mesh node,
- a router,
- a relay,
- a packet cache,
- a secure endpoint.

It must **never** depend on the internet, Firebase, cloud services, servers,
phone numbers, e-mail, or authentication providers.

This document describes the Phase 1 foundation plus the Phase 2 identity
layer. **No Bluetooth, messaging, routing or database schemas are implemented
yet** — the foundation declares the seams where those subsystems land, while
the pure-Dart identity crypto (Ed25519, X25519, QR codec, backup cipher) and
its Keystore seed vault are implemented and tested.

## Layered model

```
┌─────────────────────────── Presentation ─────────────────────────────┐
│  Flutter widgets · Riverpod controllers · GoRouter shell              │
│  · never touches repositories directly, never imports data impls      │
└───────────────────────────────────▲──────────────────────────────────┘
                                    │ depends on (interfaces)
┌─────────────────────────── Domain ────────────────────────────────────┐
│  Pure Dart: entities, repository contracts, use cases, Result/Failure │
│  · zero Flutter · zero platform · 100 % unit-testable                 │
└───────────────────────────────────▲──────────────────────────────────┘
                                    │ depends on
┌─────────────────────────── Data ──────────────────────────────────────┐
│  Repository implementations, Drift tables, source adapters            │
│  · maps domain models ↔ platform payloads                             │
└───────────────────────────────────▲──────────────────────────────────┘
                                    │ depends on
┌─────────────────────────── Platform ──────────────────────────────────┐
│  NativeChannelBridge (MethodChannel→Kotlin) · FfiBridge (FFI→C++)     │
└───────────────────────────────────▲──────────────────────────────────┘
                                    │ JNI / FFI
┌─────────────────────────── Native ────────────────────────────────────┐
│  android/ Kotlin & Java  ·  cpp/ C++                                  │
│  BLE stack · Keystore · packet codec (later phases)                   │
└───────────────────────────────────────────────────────────────────────┘
```

**The dependency rule:** all dependencies point inward. Domain never imports
Flutter or platform; data never imports widgets; presentation only sees
domain contracts and the DI container.

## Dependency graph (as implemented)

```
lib/
├── core/            framework — no business meaning
│   ├── result/      Result<T> (Ok/Err) — the domain communication carrier
│   ├── errors/      Failure sealed hierarchy + ExceptionMapper
│   ├── logger/      AppLogger, LogFilter, LogOutput, ring buffer
│   ├── config/      AppConfig ← --dart-define (flavor/environment/version)
│   ├── crypto/      identity primitives: node_id, fingerprint, Ed25519,
│   │                X25519/HKDF/AES-256-GCM, OB1: QR codec, backup cipher,
│   │                verification codes, Keystore seed vault bridges
│   ├── platform/    NativeChannelBridge + FfiBridge (boundaries)
│   ├── theme/       AppThemeType + AppThemeController
│   ├── navigation/  AppRouter (GoRouter) + AppRoutePaths
│   └── widgets/     AppScaffold, AppAsyncView, loading/error states
│
├── shared/          reusable, depends on core only
│   ├── base/        BaseStateController, UseCase, NoParams
│   ├── design_system/  tokens → ColorSchemes → ThemeData → components
│   └── localization/   AppLocales + LocaleController
│
└── features/        feature-first slices: presentation / domain / data
    ├── home/        (phase 1 presents only this console)
    ├── identity/    implemented: models, repositories, 17 use cases,
    │                Riverpod controllers, vault-backed data layer
    ├── nearby/      domain contract only (BLE phase)
    ├── mesh/        domain contract only
    ├── nodes/       domain contract only
    ├── channels/    domain contract only
    ├── settings/    domain contract only
    ├── developer/   domain contract only
    └── about/       domain contract only
```

Feature `data/` and `presentation/` folders exist for every feature (kept in
git via `.gitkeep`); their contents arrive with their phases.

## Module responsibilities

| Module | Responsibility |
| --- | --- |
| `core/result` | `Result<T>` (sealed `Ok`/`Err`), `Future.toResult()` — no throwing across boundaries |
| `core/errors` | Failure value hierarchy (Unexpected/Storage/Platform/Serialization/Configuration/Unsupported/Cancelled), exception→failure conversion at the boundaries |
| `core/logger` | Leveled, tagged, filtered logging with a bounded ring buffer for the developer panel |
| `core/config` | Build-time `AppConfig` from compile-time defines; `AppFlavor` with Gradle alias mapping |
| `core/platform` | The two native seams: method-channel bridge (Kotlin) and FFI bridge (C++); truthful `UnavailableFfiBridge` until the core lands |
| `core/theme` | Theme identity selection (`light`/`dark`/`terminal`) |
| `core/navigation` | Single `GoRouter` instance, route-path registry |
| `shared/design_system` | Design tokens (colors, typography, spacing, radius, elevation, motion, icons, component tokens) → theme builder → tokenized components |
| `features/<x>/domain` | Entities + repository contracts + use cases (the future system's stable vocabulary) |
| `features/<x>/data` | (later) repository impls, Drift, BLE adapters |
| `features/<x>/presentation` | (home in Phase 1; others later) screens + controllers |

## Design rules enforced in code

1. Business logic never imports Flutter — CI analyzes a per-layer rule set.
2. Widgets never reach for `AppPalette` or literal `Color`/`Duration`/`double`
   — only tokens and `ThemeData` extensions.
3. No raw exceptions cross feature boundaries — `Result<T>` or `Failure`
   only.
4. Every failure is logged once, at the boundary where it is created.
5. Compile-time identity: flavor/environment are `const String.fromEnvironment`,
   never runtime probes.
6. No screens outside `features/`; the app shell is the only global widget.
