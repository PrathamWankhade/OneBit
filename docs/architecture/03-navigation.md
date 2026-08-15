# Navigation Architecture

## Model

Single declarative router ([go_router 17](https://pub.dev/packages/go_router))
created once in `core/navigation/app_router.dart` (`AppRouter.create`) and
exposed as the `goRouterProvider`. `MaterialApp.router` consumes it in
`app/app_shell.dart`.

```
OneBitApp (MaterialApp.router)
  └── routerConfig: GoRouter (initialLocation: /splash, redirect guards)
        ├── GoRoute /splash                     → SplashScreen
        ├── GoRoute /onboarding                 → OnboardingScreen
        └── StatefulShellRoute.indexedStack     → AppShell (chrome)
              ├── branch 0  /channels  (+ nested + flat routes)
              ├── branch 1  /nodes     (+ nested + flat routes)
              ├── branch 2  /nearby
              ├── branch 3  /mesh      (+ nested route)
              └── branch 4  /settings  (+ nested + flat routes)
```

* **Shell chrome** (`AppShell`) owns tab chrome; features own content. Screens
  never push `MaterialPageRoute` — navigation goes through `context.go` /
  `context.push` (go_router extensions) or `goRouterProvider`.
* **Branch stacks**: each tab is a `StatefulShellBranch` with its own
  navigator, kept alive by `StatefulShellRoute.indexedStack` — switching tabs
  preserves every branch's stack and scroll state.
* **Nested routes** (children of a tab root) are declared with relative child
  paths derived from the absolute constants (`_childPath`); **flat routes**
  (e.g. `/search`, `/about`, `/transfers/:sessionId`) are top-level `GoRoute`s
  inside a branch and share its navigator.
* **Router-level failures** render `_RouterErrorView` ("Something went wrong",
  `l10n.commonError`) — never a raw exception surface.

## Route registry

`core/navigation/app_route_paths.dart` is the single source of truth: every
area owns absolute path constants, `AppRouteParameters` names the parameter
segments (`channelId`, `messageId`, `nodeId`, `sessionId`), and the builders
(`channelOf`, `messageOf`, `composeOf`, `nodeOf`, `transferOf`) produce
concrete deep-link locations. The registry test asserts every constant is
registered in the router tree (`GoRouter.configuration.locationForRoute`).

| Path | Screen | Notes |
| --- | --- | --- |
| `/splash` | SplashScreen | boot landing; left once identity + restored tab resolve |
| `/onboarding` | OnboardingScreen | first-run identity creation |
| `/channels` | ChannelsScreen | tab 0 root |
| `/channels/:channelId` | ChannelDetailsScreen | deep-linkable |
| `/channels/:channelId/message/:messageId` | ChannelDetailsScreen | message anchor |
| `/channels/:channelId/compose` | ComposeMessageScreen | |
| `/search` | SearchScreen | flat, channels branch |
| `/transfers/:sessionId` | TransferProgressScreen | deep-linkable, flat |
| `/media` | MediaGalleryScreen | flat |
| `/nodes` | NodesScreen | tab 1 root |
| `/nodes/:nodeId` | NodeDetailsScreen | deep-linkable |
| `/qr-identity` | QrIdentityScreen | flat, nodes branch |
| `/qr-scan` | QrScannerScreen | flat |
| `/nearby` | NearbyScreen | tab 2 root |
| `/mesh` | MeshScreen | tab 3 root |
| `/mesh/routes` | RouteInspectorScreen | |
| `/settings` | SettingsScreen | tab 4 root |
| `/settings/appearance` … `/settings/bluetooth` | settings sections | nested |
| `/developer` | HomeScreen (console) | gated, flat |
| `/developer/diagnostics`, `/developer/logs` | tools shells | gated, flat |
| `/bluetooth-debug` `/mesh-debug` `/packet-debug` `/dtn-debug` | transport workbenches | gated, flat |
| `/about` | AboutScreen | flat (licenses child) |
| `/about/licenses` | LicensesScreen | flat |
| `/` | — | legacy home; **redirect** to `/channels`, not a route |

## Guards

The router's `redirect` re-evaluates on every navigation and whenever a gated
provider changes (`ref.listen` + `router.refresh()`):

1. **Identity gate** — while the identity is loading the router stays put; with
   no identity every location resolves to `/onboarding`; with one, splash and
   onboarding resolve to the restored tab.
2. **Developer gate** — paths in `developerGatedPaths` resolve to `/settings`
   until developer mode is unlocked (7 taps on the About version row within a
   3 s window; `DeveloperModeController`, persisted in `SharedPreferences`).
3. **Boot landing** — splash/onboarding wait for `restoredTabPathProvider`
   (the tab persisted at `onebit.navigation.lastTabPath`, default `/channels`).

Deep links carry domain-model identifiers only; the parameterized GoRoutes
resolve them into screen constructor arguments (surfaced via
`RoutePlaceholder`'s technical card until the feature lands).

## State restoration

* In-process: `StatefulShellRoute.indexedStack` + `restorationScopeId`
  (`onebit-shell`, per-branch) preserve stacks and scroll positions.
* Across launches: the active tab is persisted on every branch switch
  (`persistLastTabPath`, fire-and-forget) and restored by the boot guard.

## Responsive chrome

`AppShell` derives the layout from the viewport width (`OneBitBreakpoint`):
compact (<600dp) renders `OneBitNavigationBar`; medium (600–839dp) and
expanded (≥840dp) render `OneBitNavigationRail` (extended on expanded). Both
consume the same `shellTabs` destinations list — navigation logic is never
duplicated across layouts. Tab switches call `goBranch` and persist the tab.

## Rules

1. Screens never push `MaterialPageRoute`; navigation goes through `context.go`
   / `context.push` or `goRouterProvider`.
2. Route parameters are declared on the constants so deep links stay stable;
   identifiers mirror the domain models.
3. The shell owns chrome; features own content. Tab lists live in
   `app/shell_tabs.dart`; the shell owns no destination logic.
4. Router-level failures render `_RouterErrorView` with the localized
   "Something went wrong" message.
5. No business data in route placeholders: parameterized screens render only
   the resolved identifiers until their feature phase lands.

## Tests

* `test/core/navigation/app_route_paths_test.dart` — registry invariants.
* `test/core/navigation/app_router_test.dart` — boot flows, registration
  walker, per-route navigation, deep-link resolution, nested push/pop,
  guards, error view, tab restoration across restarts.
* `test/app/app_shell_test.dart` — responsive layouts, tab switching,
  persistence.
* `test/features/about/about_screen_test.dart` — version-tap unlock.
* Harness: `test/app/support/app_navigation_support.dart` (in-memory prefs
  + fake identity repository; `package:clock` fakes the tap window).
