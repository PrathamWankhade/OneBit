# ADR-0004 — Riverpod (no codegen) for DI and state

Status: Accepted

## Context

The app needs dependency injection with test-time overrides, asynchronous
state with lifecycle-safe updates, and no code-generation step that would slow
dev iterations. A state/DI library that ties domain singletons to the widget
tree or requires build phases was rejected.

## Decision

- flutter_riverpod (v3) is used everywhere; no codegen (`riverpod_generator`
  deliberately excluded — providers are hand-written and typed).
- A single composition root lives in `lib/bootstrap.dart`: a
  `ProviderContainer` is built there, boot logging is initialized eagerly, and
  the tree is wrapped in `UncontrolledProviderScope` (no `Container` leak).
- Domain singletons (config, logger, repositories, theming, locale) are
  provider-defined; data implementations are swapped via `overrideWithValue`
  in tests.
- Controllers extend `BaseStateController` (`Riverpod`:
  `StateNotifier`/`AsyncNotifier`-free plain controller) and expose typed state
  + result-bearing `load`/`refresh` methods.

## Consequences

- Widget tests override repositories trivially; `test/features/home`
  demonstrates fake repos without device access.
- No build_runner step keeps `flutter analyze`/`flutter test` cold-start fast.
- Cost: hand-written providers carry a little boilerplate; mitigated by small
  `*Provider` helper constructors in `core`.

## Related

- ADR-0001 (Clean Architecture), ADR-0002 (Result/Failure).