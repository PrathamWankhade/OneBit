<div align="center">

  <img src="assets/icons/OneBitLogo.png" alt="OneBit Logo" width="100" />

  # OneBit

  **Decentralized mesh messenger**

  No internet \u00b7 No cloud \u00b7 No servers \u00b7 No accounts

  [![Flutter](https://img.shields.io/badge/Flutter-3.13+-02569B?logo=flutter)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.13+-0175C4?logo=dart)](https://dart.dev)
  [![License: MIT](https://img.shields.io/badge/License-MIT-00AAAA.svg)](LICENSE)
  [![Tests](https://img.shields.io/badge/tests-2085%20passing-brightgreen)]()

  ---

</div>

## What is OneBit?

OneBit is a peer-to-peer communication platform that lets nearby devices talk directly over **Bluetooth Low Energy (BLE)**. Every device is simultaneously a node, router, and secure endpoint. No infrastructure. No single point of failure.

Messages hop between devices using a custom mesh routing protocol. If two people aren't in range, the network finds a path through other OneBit users nearby. The mesh self-heals, routes adapt, and your data never touches a server.

## Key Features

| Feature | Description |
|---------|-------------|
| **Mesh Networking** | Multi-hop BLE routing with automatic topology discovery and route recovery |
| **End-to-End Encryption** | AES-256-GCM with Ed25519 key exchange. Only you and your contacts can read messages |
| **Zero Infrastructure** | No servers, no accounts, no phone number required |
| **Terminal Aesthetic** | IBM 5153-inspired UI with Consolas monospace typography |
| **Media Sharing** | Send images, files, and voice messages over the mesh |
| **QR Code Exchange** | Share identity via QR codes for in-person verification |
| **Biometric Lock** | Fingerprint or face recognition to secure the app |
| **Relay Participation** | Optionally help route messages for other peers |

## Screenshots

<div align="center">

| Chats | Nearby | Identity | Settings |
|-------|--------|----------|----------|
| *Conversation list with E2E indicators* | *BLE peer discovery with signal bars* | *Profile with QR code and fingerprint* | *Terminal-style settings panels* |

</div>

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter 3.13+ \u00b7 Dart 3.13+ |
| State Management | Riverpod 2.6.1 |
| Navigation | GoRouter 14.8 |
| Database | Drift 2.22 \u00b7 SQLite |
| Preferences | shared\_preferences |
| Security | cryptography \u00b7 flutter\_secure\_storage |
| QR Codes | qr \u00b7 mobile\_scanner |
| Design System | Material 3 \u00b7 IBM 5153 terminal theme |
| Typography | Consolas monospace |

## Getting Started

### Prerequisites

- Flutter SDK 3.13+
- Dart SDK 3.13+
- Android Studio / Xcode
- A physical device (BLE does not work on emulators)

### Setup

```bash
# Clone the repository
git clone https://github.com/PrathamWankhade/onebit.git
cd onebit

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
| `flutter test` | Run all tests (2085 passing) |
| `flutter analyze` | Static analysis (0 errors) |
| `dart run build_runner build` | Regenerate Drift/database code |
| `flutter build apk --release` | Build release APK |

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
\u251c\u2500\u2500 main.dart                          Entry point + global ProviderContainer
\u251c\u2500\u2500 app/
\u2502   \u251c\u2500\u2500 app.dart                       OneBitApp + dark-only theme
\u2502   \u251c\u2500\u2500 router.dart                    GoRouter with slide/fade transitions
\u2502   \u2514\u2500\u2500 router_notifier.dart           Onboarding redirect logic
\u251c\u2500\u2500 core/
\u2502   \u251c\u2500\u2500 logging/app_logger.dart        Centralized logger
\u2502   \u2514\u2500\u2500 theme/app_theme.dart           IBM 5153 terminal color scheme
\u251c\u2500\u2500 data/
\u2502   \u2514\u2500\u2500 database/
\u2502       \u251c\u2500\u2500 app_database.dart          Drift database (schema v11)
\u2502       \u2514\u2500\u2500 app_database.g.dart        Generated Drift code
\u2514\u2500\u2500 features/
    \u251c\u2500\u2500 ble/                         BLE service + state management
    \u251c\u2500\u2500 conversations/              Chat UI + message bubbles
    \u251c\u2500\u2500 crypto/                      AEAD cipher + key derivation
    \u251c\u2500\u2500 identity/                   Profile, QR, fingerprint, trust
    \u251c\u2500\u2500 message/                    Message relay + delivery
    \u251c\u2500\u2500 navigation/                 3-tab floating nav bar
    \u251c\u2500\u2500 nearby/                     BLE discovery + peer cards
    \u251c\u2500\u2500 onboarding/                 Terminal boot sequence
    \u251c\u2500\u2500 peer_registry/              Connection + peer management
    \u251c\u2500\u2500 protocol/                   Packet codec + transport
    \u251c\u2500\u2500 reliable/                   Reliable transfer manager
    \u251c\u2500\u2500 routing/                    Mesh routing + topology
    \u251c\u2500\u2500 settings/                   All settings screens + toggles
    \u251c\u2500\u2500 trust/                      Trust + verification logic
    \u2514\u2500\u2500 ui/                          Shared components library
```

## Design System

### IBM 5153 Terminal Theme

| Token | Color | Usage |
|-------|-------|-------|
| `bgBase` | `#000000` | Pure black background |
| `bgSurface` | `#0A0A0A` | Elevated surfaces |
| `accent` | `#00AAAA` | Primary actions, links |
| `trust` | `#00AA00` | Success, online, verified |
| `danger` | `#FF5555` | Errors, danger, blocked |
| `warning` | `#FFFF55` | Warnings, caution |
| `mesh` | `#00AA00` | Mesh network indicators |
| `textPrimary` | `#AAAAAA` | Primary text |
| `textSecondary` | `#555555` | Secondary text |
| `textTertiary` | `#444444` | Disabled, placeholder |

### Typography

All UI text uses **Consolas** monospace for a consistent terminal aesthetic.

| Style | Size | Usage |
|-------|------|-------|
| `titleLarge` | 22px | Screen titles |
| `titleMedium` | 16px | Section headers |
| `bodyMedium` | 14px | Body text |
| `bodySmall` | 12px | Secondary text |
| `technical` | 13px | Code, hashes, IDs |
| `caption` | 12px | Labels, hints |

## Testing

```bash
# Run the full test suite
flutter test

# Run a specific test file
flutter test test/features/nearby/nearby_screen_test.dart

# Run with coverage
flutter test --coverage
```

**Current status**: 2085 tests passing, 0 analysis errors.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to OneBit.

## Security

If you discover a security vulnerability, please report it responsibly. Do not open a public GitHub issue. Instead, contact the maintainer directly.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

<div align="center">

  Built with Flutter \u00b7 Designed for the mesh

</div>
