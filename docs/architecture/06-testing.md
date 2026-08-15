# Testing Architecture

## Layers and their tests

| Layer | Test | Location |
| --- | --- | --- |
| Result wrapper | `Ok/Err`, fold, map, capture, `Future.toResult` | `test/core/result/result_test.dart` |
| Failure hierarchy | code stability, `ExceptionMapper` mapping, subclass coverage | `test/core/errors/failure_test.dart` |
| Logger | ring buffer, filtering, res and throwing-sink tolerance | `test/core/logger/app_logger_test.dart` |
| Config | `AppFlavor.fromName` aliases, environment defaults | `test/core/config/app_flavor_test.dart` |
| Design tokens | spacing/radius values, `ThemeData` per identity | `test/shared/design/app_theme_test.dart` |
| Home controller | provider resolves config + capabilities without platform | `test/features/home/home_controller_test.dart` |
| App widget | shell renders after bootstrap (no exceptions) | `test/widget_test.dart`, `test/features/home/home_screen_test.dart` |
| On-device | boot + render on a real device | `integration_test/app_test.dart` |

## Isolating the platform

- Bridges are interfaces (`NativeChannelBridge`, `FfiBridge`) behind
  providers; tests override them with fakes — no MethodChannel in unit tests.
- Phase 1 truthfully ships `UnavailableFfiBridge`, so controller tests assert
  `nativeCoreAvailable == false` and the UI shows "Unavailable" honestly.
- `ProviderContainer` + `addTearDown(container.dispose)` is the standard
  harness for provider tests (see `home_controller_test.dart`).

## Commands

```bash
flutter analyze                       # static gates (strict)
flutter test                         # all unit + widget tests
flutter test integration_test -d <device>   # on-device boot
flutter build apk --debug --flavor dev   # fastest build sanity
```