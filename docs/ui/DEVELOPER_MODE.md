# Developer Mode

## Overview

Developer mode unlocks additional diagnostic and debugging tools that are
hidden by default. When disabled, developer-area routes redirect to Settings.

## How to unlock

1. Navigate to **Settings → About**.
2. Tap the **version row** 7 times within 3 seconds.
3. A confirmation toast appears when developer mode is enabled.

The unlock sequence is implemented in
`lib/app/developer_mode_controller.dart` (`DeveloperModeController`):

```dart
static const int versionTapsRequired = 7;
static const Duration versionTapWindow = Duration(seconds: 3);
```

If the gap between taps exceeds 3 seconds, the counter resets.

## Persistence

The flag is stored in `SharedPreferences` under
`onebit.navigation.developerMode`. It persists across app restarts but is
a non-sensitive UI preference — not encrypted.

## Disabling

Developer mode can be disabled from the Developer screen. This hides the
developer-area routes and redirects to Settings.

## Developer tools

When unlocked, the following screens become accessible from Settings →
Developer (and via direct deep links):

| Screen | Path | Purpose |
| --- | --- | --- |
| `DeveloperScreen` | `/developer` | Developer dashboard / landing |
| `DiagnosticsScreen` | `/developer/diagnostics` | Device and system diagnostics |
| `LogsScreen` | `/developer/logs` | Application log viewer |
| `DatabaseViewerScreen` | `/developer/database` | Inspect local database |
| `StatisticsScreen` | `/developer/statistics` | Usage statistics |
| `PerformanceScreen` | `/developer/performance` | Performance monitoring |
| `BluetoothDevScreen` | `/bluetooth-debug` | Bluetooth transport workbench |
| `MeshDevScreen` | `/mesh-debug` | Mesh engine dashboard |
| `PacketDevScreen` | `/packet-debug` | Packet protocol engine workbench |
| `DtnDevScreen` | `/dtn-debug` | DTN store-and-forward workbench |

## Navigation guard

The router checks `developerModeProvider` on every navigation. If the
target path is in `AppRoutePaths.developerGatedPaths` and developer mode
is disabled, the user is redirected to `/settings`.

```dart
if (!(ref.read(developerModeProvider).value ?? false) &&
    AppRoutePaths.developerGatedPaths.contains(location)) {
  return AppRoutePaths.settings;
}
```

The guard re-evaluates when `developerModeProvider` changes, so toggling
developer mode immediately shows or hides the routes.

## Provider

```dart
final AsyncNotifierProvider<DeveloperModeController, bool>
    developerModeProvider = ...;
```

The provider is an `AsyncNotifier<bool>` that loads the persisted value on
build. Methods:

- `registerVersionTap()` — called on each version-row tap; returns `true`
  when the sequence completes
- `enable()` — persists and sets the flag to `true`
- `disable()` — persists and sets the flag to `false`

## Rules

1. Developer screens are never reachable as shell tabs — always through
   Settings.
2. The gated paths list is the single source of truth for which routes are
   protected.
3. Developer mode is a UI-only flag; it does not affect transport,
   protocol, or security behavior.
