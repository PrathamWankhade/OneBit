<div align="center">

# OneBit

**Decentralized mesh messenger**

*No internet · No cloud · No servers · No accounts*

---

</div>

## About

OneBit is a decentralized communication platform that lets nearby devices communicate directly over **Bluetooth Low Energy (BLE)**. Every device acts as a node, router, and secure endpoint — no infrastructure required.

> This repository contains **Increment 1**: a stable, local-only messaging
> application that persists conversations and messages in SQLite. BLE mesh
> networking will be introduced in Increment 2.

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Framework** | Flutter 3.47+ · Dart 3.13+ |
| **State** | Riverpod 2.6 |
| **Navigation** | GoRouter 14.8 |
| **Database** | Drift 2.22 · SQLite |
| **Preferences** | shared_preferences |
| **Design** | Material 3 |

## Quick Start

```bash
# Clone
git clone https://github.com/your-username/onebit.git
cd onebit

# Install dependencies
flutter pub get

# Generate Drift code (after schema changes)
dart run build_runner build --delete-conflicting-outputs

# Analyze
flutter analyze

# Test
flutter test

# Run
flutter run
```

## Project Structure

```
lib/
├── main.dart                          Entry point
├── app/
│   ├── app.dart                       OneBitApp + providers
│   ├── router.dart                    GoRouter configuration
│   └── router_notifier.dart           Onboarding redirect logic
├── core/
│   ├── logging/app_logger.dart        Centralized logger
│   └── theme/app_theme.dart           Material 3 light/dark themes
├── data/
│   ├── database/
│   │   ├── app_database.dart          Drift database (Settings, Conversations, Messages)
│   │   └── app_database.g.dart        Generated Drift code
│   └── preferences/
│       └── onboarding_repository.dart  SharedPreferences wrapper
└── features/
    ├── conversations/
    │   ├── presentation/
    │   │   ├── conversation_list_screen.dart   Home screen
    │   │   ├── conversation_screen.dart        Chat screen
    │   │   ├── message_bubble.dart             Message widget
    │   │   └── new_conversation_dialog.dart    Create dialog
    │   └── providers/
    │       └── conversation_providers.dart     Riverpod providers
    ├── onboarding/
    │   └── presentation/onboarding_screen.dart
    └── settings/
        └── presentation/
            ├── settings_screen.dart
            └── theme_provider.dart
```

## Architecture

```
SQLite (Drift)
      ↓
   Database (CRUD)
      ↓
  Riverpod (Reactive)
      ↓
  Material 3 UI
```

- **Data layer**: Drift provides type-safe SQL with reactive streams
- **State layer**: Riverpod providers expose database data to the UI
- **Presentation layer**: Flutter widgets consume providers reactively

## Features (Increment 1)

- First-launch onboarding flow
- Conversation creation and management
- Local message sending and display
- SQLite persistence (data survives restart)
- Reactive UI (changes appear immediately)
- System / Light / Dark theme switching
- Empty state handling
- Graceful error states
- 32 passing tests

## Testing

```bash
flutter test          # Run all tests
flutter analyze       # Static analysis
```

## License

MIT
# OneBit
