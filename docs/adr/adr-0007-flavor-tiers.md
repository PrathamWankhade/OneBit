# ADR-0007 — Android flavor IDs map to semantic Debug/Beta/Release tiers

Status: Accepted

## Context

The product requires three build tiers (debug / beta / release) with distinct
application IDs and version names. AGP forbids product flavor names that
collide with build-type names (`debug` and `release` are reserved), so the
tiers could not be named literally.

## Decision

- Android product flavors: `dev`, `beta`, `prod` (dimension `tier`).
- Each sets `applicationIdSuffix`, `versionNameSuffix` and the manifest label
  placeholder (`OneBit Dev` / `OneBit Beta` / `OneBit`).
- `Flutter` injects the flavor id via `--dart-define=FLAVOR`; the Dart layer
  maps aliases with `AppFlavor.fromName`: `dev → debug`, `beta → beta`,
  `prod → release`.
- The semantic trio (debug/beta/release) is the only vocabulary used in Dart.

## Consequences

- `flutter run --flavor dev` yields a debug-tier app with a separate
  applicationId (coexists with the store build on one device).
- Dart code never sees the raw flavor id; unknown defines fall back to
  debug-safe behavior.
- CI builds the matrix `dev` / `beta` / `prod` with explicit `--flavor`.

## Related

- `docs/architecture/07-build-and-flavors.md`
