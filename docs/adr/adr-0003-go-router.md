# ADR-0003 — go_router as the single routing model

Status: Accepted

## Context

The app needs deep-linkable, declarative navigation across feature slices,
with a shell scaffold shared by most screens. Mixed side-stacks or two
routing libraries would fracture capability gating (features are not all live
in Phase 1) and make animated route transitions inconsistent.

## Decision

- go_router is the only routing model; every route path is a string constant
  in `core/navigation/app_route_paths.dart`, no literals inline.
- The app mounts a single `ShellRoute` (`core/navigation/app_router.dart`)
  whose child is `AppShell`; feature screens sit under it.
- Router plus build/transition configuration is provided via
  `appRouterProvider` (Riverpod) so tests can override routes.
- Screen locators are `const` typed functions so `context.go` calls are
  compile-checked; redirects live in one place only.

## Consequences

- Declarative deep links and browser/Android intent paths work without extra code.
- Adding a route updates exactly two files: `app_route_paths.dart` and the
  router table — screens stay ignorant of paths.
- Widget tests can pump `OneBitApp` directly; no router mocking needed.
- Cost: go_router's `StatefulShellRoute` is deferred until tabs exist, to keep
  the tree flat in Phase 1.

## Related

- ADR-0001 (Clean Architecture), ADR-0004 (Riverpod).