# State Management Architecture

## Stack

[flutter_riverpod 3](https://pub.dev/packages/flutter_riverpod) — no codegen.
Dependency injection and state management are the same mechanism: every
repository, bridge, use case and controller is a provider.

## Provider taxonomy

| Kind | Used for | Examples |
| --- | --- | --- |
| `Provider` | singletons / composition root | `appConfigProvider`, `goRouterProvider`, `appLoggerProvider`, `loadHomeStatusProvider` |
| `NotifierProvider` | mutable local state | `appThemeProvider` (theme type), `appLocaleProvider` (locale) |
| `AsyncNotifierProvider` | async feature state | `homeControllerProvider` |
| `StreamProvider` | (later) BLE scan, presence, mesh broadcasts | `nearbyPeersProvider` |

## Controller contract

Controllers extend `BaseStateController<T>` (`shared/base/base_controller.dart`)
— an `AsyncNotifier<T>` that additionally routes failures through the logger
with the failure framework. Controllers:

- hold exactly one feature slice;
- never touch widgets or repositories directly — they call use cases;
- expose `build()` returning the initial state.

## Data flow

```
Widget (ConsumerWidget)
  └─ ref.watch(xxxProvider) → AsyncValue<T>
        └─ AppAsyncView → loading / error(retry=ref.invalidate) / data
Use cases → repositories (abstract) → data impls → platform bridges → native
```

## Rules

1. No `setState` outside a feature controller; no `ValueNotifier` globals.
2. Repositories are abstract interfaces behind providers; tests override the
   provider, never the widget tree.
3. Controllers return `Future<Result<T>>`-shaped work through use cases;
   `Err` states are mapped to `AsyncError` for the UI.
4. Cross-feature state only via core providers (theme, locale, logger) —
   never by importing another feature's presentation.
