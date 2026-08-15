# Navigation

## Router

Navigation is managed by `go_router` via `AppRouter` in
`lib/core/navigation/app_router.dart`. The router is created once and bound
to a Riverpod `ProviderScope`.

```dart
final GoRouterProvider = Provider<GoRouter>((ref) => AppRouter.create(ref));
```

## Route paths

All canonical paths live in `lib/core/navigation/app_route_paths.dart`
(`AppRoutePaths`). Never hardcode path strings — reference the constants.

### Launch / onboarding flow

| Path | Screen | Notes |
| --- | --- | --- |
| `/launch` | `OpeningScreen` | Brand animation; first screen |
| `/intro` | `IntroScreen` | First-run intro |
| `/setup/display-name` | `DisplayNameSetupScreen` | Name setup |
| `/setup/initializing` | `InitializingScreen` | Initialization |
| `/splash` | `SplashScreen` | Legacy; kept for compat |
| `/onboarding` | `OnboardingScreen` | Legacy; superseded by intro + display-name |

### Primary tabs (StatefulShellRoute.indexedStack)

| Branch | Path | Screen |
| --- | --- | --- |
| 0 (Channels) | `/channels` | `ChannelsScreen` |
| 1 (Nodes) | `/nodes` | `NodesScreen` |
| 2 (Nearby) | `/nearby` | `NearbyScreen` |
| 3 (Mesh) | `/mesh` | `MeshScreen` |
| 4 (Settings) | `/settings` | `SettingsScreen` |

### Deep-linkable routes

| Path | Screen | Parameters |
| --- | --- | --- |
| `/channels/:channelId` | `ChannelDetailsScreen` | `channelId` |
| `/channels/:channelId/message/:messageId` | `ChannelDetailsScreen` | `channelId`, `messageId` |
| `/channels/:channelId/compose` | `ComposeMessageScreen` | `channelId` |
| `/nodes/:nodeId` | `NodeDetailsScreen` | `nodeId` |
| `/transfers/:sessionId` | `TransferProgressScreen` | `sessionId` |
| `/search` | `SearchScreen` | — |
| `/media` | `MediaGalleryScreen` | — |
| `/identity` | `IdentityOverviewScreen` | — |
| `/qr` | `QrHubScreen` | — |
| `/qr-identity` | `QrIdentityScreen` | — |
| `/qr-scan` | `QrScannerScreen` | — |
| `/mesh/routes` | `RouteInspectorScreen` | — |

### Settings sub-routes

| Path | Screen |
| --- | --- |
| `/settings/appearance` | `AppearanceSettingsScreen` |
| `/settings/privacy` | `PrivacySettingsScreen` |
| `/settings/storage` | `StorageSettingsScreen` |
| `/settings/notifications` | `NotificationsSettingsScreen` |
| `/settings/bluetooth` | `BluetoothSettingsScreen` |
| `/about` | `AboutScreen` |
| `/about/licenses` | `LicensesScreen` |

### Developer routes (gated)

| Path | Screen |
| --- | --- |
| `/developer` | `DeveloperScreen` |
| `/developer/diagnostics` | `DiagnosticsScreen` |
| `/developer/logs` | `LogsScreen` |
| `/developer/database` | `DatabaseViewerScreen` |
| `/developer/statistics` | `StatisticsScreen` |
| `/developer/performance` | `PerformanceScreen` |
| `/bluetooth-debug` | `BluetoothDevScreen` |
| `/mesh-debug` | `MeshDevScreen` |
| `/packet-debug` | `PacketDevScreen` |
| `/dtn-debug` | `DtnDevScreen` |

## Deep-link builders

`AppRoutePaths` provides typed builders for parameterized deep links:

```dart
AppRoutePaths.channelOf(channelId)   // '/channels/$channelId'
AppRoutePaths.messageOf(channelId, messageId)
AppRoutePaths.composeOf(channelId)
AppRoutePaths.nodeOf(nodeId)
AppRoutePaths.transferOf(sessionId)
```

## Route parameters

Parameter names are defined in `AppRouteParameters`:

```dart
AppRouteParameters.channelId   // 'channelId'
AppRouteParameters.messageId   // 'messageId'
AppRouteParameters.nodeId      // 'nodeId'
AppRouteParameters.sessionId   // 'sessionId'
```

## Shell and tabs

The `StatefulShellRoute.indexedStack` wraps the five primary tabs in an
`AppShell` that provides:

- **Bottom navigation bar** (`OneBitNavigationBar`) on compact layouts
- **Navigation rail** (`OneBitNavigationRail`) on medium/expanded layouts
- Persistent shell chrome (app bar, responsive scaffold)

Tab order is defined in `lib/app/shell_tabs.dart` (`shellTabs()`):

| Index | ID | Path |
| --- | --- | --- |
| 0 | `channels` | `/channels` |
| 1 | `nodes` | `/nodes` |
| 2 | `nearby` | `/nearby` |
| 3 | `mesh` | `/mesh` |
| 4 | `settings` | `/settings` |

Developer is intentionally absent from the tab list — it is reached from
Settings, never as a tab.

## Redirect guards

The router has two redirect guards evaluated on every navigation:

### Identity gate

Without an identity, every location resolves to `/launch` (the onboarding
flow). The launch area handles its own state machine transitions and is
never redirected away from while active.

### Developer gate

Developer-area paths redirect to `/settings` until developer mode is
unlocked (see [DEVELOPER_MODE.md]). The gated paths are:

```dart
AppRoutePaths.developerGatedPaths = [
  developer, diagnostics, logs, databaseViewer,
  statistics, performance, bluetoothDebug, meshDebug,
  packetDebug, dtnDebug,
]
```

### Redirect re-evaluation

Redirects are re-evaluated when any of these providers change:

- `identityControllerProvider` — identity created/loaded
- `developerModeProvider` — developer mode toggled
- `restoredTabPathProvider` — tab restored from persistence
- `launchFlowProvider` — launch flow state machine transitions

## Navigation patterns

1. **Tab navigation** — uses `context.go(path)` for the primary tabs; the
   shell controller manages the active index.
2. **Push navigation** — uses `context.push(path)` for detail screens
   within a branch (e.g. channel details, node details).
3. **Deep links** — constructed via `AppRoutePaths.*Of()` builders; the
   router resolves them to the correct screen.
4. **Legacy paths** — `/` resolves to `/channels`; `/splash` and
   `/onboarding` resolve to the restored tab or channels.

## Restoration

The `StatefulShellRoute` uses `restorationScopeId: 'onebit-shell'` and each
branch has its own `restorationScopeId` for state restoration across app
restarts.
