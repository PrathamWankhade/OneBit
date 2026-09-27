<div align="center">

  <img src="assets/icons/OneBitLogo.png" alt="OneBit Logo" width="100" />

  # OneBit

  **Decentralized mesh messenger**

  No internet · No cloud · No servers · No accounts

  [![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.13+-0175C4?logo=dart)](https://dart.dev)
  [![CI](https://github.com/PrathamWankhade/OneBit/actions/workflows/ci.yml/badge.svg)](https://github.com/PrathamWankhade/OneBit/actions/workflows/ci.yml)
  [![License: MIT](https://img.shields.io/badge/License-MIT-00AAAA.svg)](LICENSE)

  ---

</div>

## What is OneBit?

OneBit is a peer-to-peer communication platform that lets nearby devices talk directly over **Bluetooth Low Energy (BLE)**. Every device is simultaneously a node, router, and secure endpoint. No infrastructure. No single point of failure.

Messages hop between devices using a custom mesh routing protocol. If two people aren't in range, the network finds a path through other OneBit users nearby. The mesh self-heals, routes adapt, and your data never touches a server.

## Key Features

| Feature | Description |
|---------|-------------|
| **Mesh Networking** | Multi-hop BLE routing with automatic topology discovery and route recovery |
| **End-to-End Encryption** | AES-256-GCM session encryption, with X25519 key agreement derived from your Ed25519 identity key |
| **Zero Infrastructure** | No servers, no accounts, no phone number required |
| **Terminal Aesthetic** | IBM 5153 palette on a Material 3 layout, with Consolas for hashes and identifiers |
| **Media Sharing** | Send images, files, and voice messages over the mesh |
| **QR Code Exchange** | Share and scan identity QR codes for in-person verification |
| **Relay Participation** | Optionally help route messages for other peers |
| **Update Checks** | Settings → App update checks GitHub for a newer build and offers to install it |

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter 3.47 · Dart 3.13 |
| State Management | Riverpod 2.6 |
| Navigation | GoRouter 14.8 |
| Database | Drift 2.22 · SQLite |
| Preferences | shared_preferences |
| Security | cryptography · flutter_secure_storage |
| QR Codes | qr · mobile_scanner |
| Media | image_picker · flutter_svg · shimmer |
| Design System | Material 3 · IBM 5153 terminal palette |
| Typography | Platform system font, with bundled Consolas for code |

## Getting Started

### Prerequisites

- Flutter SDK 3.47+
- Dart SDK 3.13+
- Android Studio / Xcode
- A physical device (BLE does not work on emulators)

### Setup

```bash
# Clone the repository
git clone https://github.com/PrathamWankhade/OneBit.git
cd OneBit

# Install dependencies
flutter pub get

# Generate Drift code (after schema changes)
dart run build_runner build --delete-conflicting-outputs

# Run on a connected device
flutter run -d <device>
```

### Commands

| Command | Description |
|---------|-------------|
| `flutter run -d <device>` | Run the app on a connected device |
| `flutter test` | Run the full test suite |
| `flutter analyze` | Static analysis (CI requires zero issues) |
| `dart run build_runner build --delete-conflicting-outputs` | Regenerate Drift/database code |
| `flutter build apk --debug` | Build a debug APK |
| `flutter build apk --release` | Build a release APK |

### Install a build

Every push to `main` runs CI and uploads versioned APKs to that run:

1. Open the [Actions tab](https://github.com/PrathamWankhade/OneBit/actions)
2. Open the latest green **ci** run
3. Download `onebit-release-<version>` and install `OneBit-<version>-release.apk`

The file name carries the version and build number from `pubspec.yaml`, so it always matches what the app reports in Settings → App update.

## Architecture

```
+-------------------+     +------------------+     +-------------------+
|   Data Layer      |     |   State Layer    |     |  Presentation     |
|                   |     |                  |     |                   |
|  Drift (SQLite)   | --> |  Riverpod        | --> |  Flutter Widgets  |
|  SharedPreferences|     |  (Reactive)      |     |  (Material 3)     |
+-------------------+     +------------------+     +-------------------+
```

- **Data Layer**: Drift provides type-safe SQL with reactive streams. SharedPreferences for settings persistence.
- **State Layer**: Riverpod providers expose database data to the UI with automatic reactivity.
- **Presentation Layer**: Flutter widgets consume providers reactively. IBM 5153 terminal design system.

## Project Structure

```
lib/
├── main.dart                     Entry point + global ProviderContainer
├── app/
│   ├── app.dart                  OneBitApp + dark-only theme
│   ├── router.dart               GoRouter with slide/fade transitions
│   └── router_notifier.dart      Onboarding redirect logic
├── core/
│   ├── logging/app_logger.dart   Centralized logger
│   ├── theme/app_motion.dart     Shared motion tokens + transitions
│   ├── theme/app_theme.dart      IBM 5153 terminal color scheme
│   └── version/app_version.dart  Version the update check compares against
├── data/
│   ├── database/app_database.dart             Drift database (schema v11)
│   └── preferences/onboarding_repository.dart Onboarding completion flag
└── features/
    ├── ble/              BLE service + state management
    ├── conversations/    Chat UI + message bubbles
    ├── crypto/           AEAD cipher + key derivation
    ├── identity/         Profile, QR, fingerprint, trust
    ├── message/          Message relay + delivery
    ├── navigation/       3-tab floating nav bar
    ├── nearby/           BLE discovery + peer cards
    ├── onboarding/       Terminal boot sequence
    ├── peer_registry/    Connection + peer management
    ├── protocol/         Packet codec + transport
    ├── reliable/         Reliable transfer manager
    ├── routing/          Mesh routing + topology
    ├── settings/         All settings screens + toggles
    ├── trust/            Trust + verification logic
    └── ui/               Shared components library
```

Generated sources such as `app_database.g.dart` and the Mockito mocks are gitignored — `dart run build_runner build` recreates them, and CI runs it before analyzing.

## Design System

### IBM 5153 Terminal Theme

| Token | Color | Usage |
|-------|-------|-------|
| `bgBase` | `#000000` | Pure black background |
| `bgSurface` | `#0A0A0A` | Elevated surfaces |
| `accent` | `#00AAAA` | Primary actions, links |
| `trust` | `#00AA00` | Success, online, verified |
| `danger` | `#FF5555` | Errors, danger, blocked |
| `warning` | `#AA5500` | Warnings, caution |
| `mesh` | `#00AA00` | Mesh network indicators |
| `textPrimary` | `#AAAAAA` | Primary text |
| `textSecondary` | `#555555` | Secondary text |
| `textTertiary` | `#444444` | Disabled, placeholder |

### Typography

Headings and body text use the platform system font — SF Pro on iOS, Roboto on Android. The `technical` style is the one that uses the bundled **Consolas** face, reserved for hashes, keys and identifiers.

| Style | Size | Font | Usage |
|-------|------|------|-------|
| `titleLarge` | 18px | System | Screen titles |
| `titleMedium` | 16px | System | Section headers |
| `bodyMedium` | 14px | System | Body text |
| `bodySmall` | 13px | System | Secondary text |
| `technical` | 13px | Consolas | Hashes, keys, identifiers |
| `caption` | 11px | System | Labels, hints |

## Testing

```bash
# Run the full test suite
flutter test

# Run a specific test file
flutter test test/features/nearby/nearby_screen_test.dart

# Run with coverage
flutter test --coverage
```

**Current status**: the suite is green on every push, and CI fails the build if `flutter analyze` reports a single issue. Live results are on the [Actions page](https://github.com/PrathamWankhade/OneBit/actions).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to OneBit.

## Security

If you discover a security vulnerability, please report it responsibly. Do not open a public GitHub issue. Instead, [contact the maintainer](https://github.com/PrathamWankhade) directly.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

<div align="center">

  Built with Flutter · Designed for the mesh

</div>
