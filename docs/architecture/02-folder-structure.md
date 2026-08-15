# Folder Structure

```
onebit/
├── android/                     Android host (Kotlin), flavors, manifest
│   └── app/src/main/kotlin/dev/onebit/onebit/
│       ├── MainActivity.kt      registers root + identity platform channels
│       └── IdentityKeystore.kt  AES-256-GCM seed vault (Android Keystore)
├── cpp/                         C++ core (Phase 3: COBS, codec, hashing)
│   ├── include/
│   └── src/
├── assets/
│   ├── fonts/                   typeface binaries (drop-in phase)
│   ├── icons/                   custom vector icon set (drop-in phase)
│   └── images/                  raster artwork (drop-in phase)
├── docs/
│   ├── architecture/            this architecture series
│   ├── adr/                     architecture decision records
│   ├── identity/                identity phase: crypto, QR, backup specs
│   ├── guidelines/              coding standards & contributing
│   └── platform/                native bridge contract (Kotlin/JNI/FFI)
├── test/                        mirrors lib/ one-to-one
│   ├── core/ result·errors·logger·config·crypto·utils
│   ├── shared/ design tokens & themes
│   └── features/ home·identity
├── integration_test/            on-device boot smoke tests
├── .github/workflows/           CI pipeline (analyze → test → build matrix)
└── lib/
    ├── main.dart                entry point (delegates to bootstrap)
    ├── bootstrap.dart           composition root
    ├── app/
    │   ├── app_shell.dart       OneBitApp + AppShell (router shell)
    │   └── (future: shell navigation bar mounts here)
    ├── core/                    framework (no business logic)
    │   ├── config/              app_flavor · app_environment · app_config
    │   ├── constants/           app_constants · app_error_codes
    │   ├── crypto/              identity & key-management primitives
    │   │   ├── identity/        node_id · fingerprint · ed25519 · x25519 ·
    │   │   │                    qr_domain · qr_payload (OB1: codec)
    │   │   ├── verification/    verification_code (6-digit mutual codes)
    │   │   ├── backup/          backup_format · backup_cipher
    │   │   └── keystore/        keystore bridges + IdentityVault aliases
    │   ├── errors/              failure.dart · exception_mapper.dart
    │   ├── extensions/          BuildContext · String · num
    │   ├── logger/              app_logger · log_level · log_output · filters
    │   ├── navigation/          app_router · app_route_paths · provider
    │   ├── platform/            channel/FFI bridge interfaces + providers
    │   ├── result/              result.dart (Ok/Err)
    │   ├── theme/               app_theme · app_theme_provider
    │   ├── utils/               debouncer · secure_random_util
    │   └── widgets/             app_scaffold · app_async_view · states
    ├── l10n/                    ARB sources + generated AppLocalizations
    ├── shared/
    │   ├── base/                base_controller · use_case
    │   ├── design_system/
    │   │   ├── animations/      app_motion (durations + curves)
    │   │   ├── colors/          app_palette · app_color_schemes (+ ThemeExtension)
    │   │   ├── components/      app_button · app_card · app_text_field
    │   │   │                    app_navigation_bar · app_empty_state
    │   │   ├── icons/           app_icons (product iconography)
    │   │   ├── spacing/         app_spacing · app_radius · app_elevation
    │   │   ├── themes/          app_theme_data (tokens → ThemeData)
    │   │   ├── tokens/          app_component_tokens (button/input/card/nav/icon)
    │   │   └── typography/      app_typography (scale + TextTheme builder)
    │   └── localization/        app_locales · locale_controller
    └── features/
        ├── home/            presentation: home_screen · home_controller
        │                    domain:      home_status · load_home_status
        │                    data:        (empty)
        ├── identity/        presentation: identity/trust-contacts/backup/
        │                    verification controllers + providers
        │                    domain:      node_identity · user_profile ·
        │                    trust_contact · repositories · 17 use cases
        │                    data:        identity_repository_impl ·
        │                    in_memory_trust_contact_repository
        ├── nearby/          domain: nearby_peer · nearby_peer_repository
        ├── mesh/            domain: mesh_session_repository
        ├── nodes/           domain: mesh_node · node_registry_repository
        ├── channels/        domain: mesh_channel · channel_repository
        ├── settings/        domain: app_settings · app_settings_repository
        ├── developer/       domain: developer_tools_repository
        └── about/           domain: about_info · about_repository
```

## Naming conventions

| Concept | Convention | Example |
| --- | --- | --- |
| Feature | lowercase, singular | `features/mesh/` |
| Layer | `presentation` / `domain` / `data` | |
| Widget | `AppXxx` / screen suffix | `AppButton`, `HomeScreen` |
| Controller | `XxxController` (AsyncNotifier) | `HomeController` |
| Use case | verb-first | `LoadHomeStatus` |
| Repository contract | `XxxRepository` (interface) | `NodeRegistryRepository` |
| Token class | `AppXxx` | `AppSpacing`, `AppRadius` |
| Provider | `xxxProvider` | `appConfigProvider` |
