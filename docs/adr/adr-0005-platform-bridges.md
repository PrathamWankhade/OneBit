# ADR-0005 — Platform bridges behind interfaces (MethodChannel + FFI)

Status: Accepted

## Context

OneBit must talk to Android-only capabilities (BLE) and, in later phases, to a
native C++ core (COBS framing, cryptography). Tests must run on host VM where
those channels may not exist. Concretely hard-coding channel APIs into features
would break testability and phase gating.

## Decision

- All native access goes through two bridge interfaces in
  `core/platform`: `NativeChannelBridge` (async, request/response) and
  `FfiBridge` (sync C++ calls), both exposing only Dart types.
- Production instances wrap `MethodChannel`/`DynamicLibrary` specifically
  (`method_channel_bridge.dart`, `native_ffi_bridge.dart`); throws are mapped
  to `Failure` via `ExceptionMapper` before crossing into domain.
- Phase 1 ships `UnavailableFfiBridge`, which truthfully returns
  `UnsupportedOperationFailure` — UI reflects "native core not available"
  instead of pretending.
- Flutter side of Phase 1 defines the channel name table
  (`dev.onebit.onebit/native`) and a Kotlin handler in `MainActivity.kt`;
  channel contracts are documented in `docs/platform/native-bridge-contract.md`.

## Consequences

- Domain never imports `dart:ffi`/`dart:ui`/`MethodChannel`; it depends only on
  the interfaces, so all domain tests run on host.
- Swapping BLE or the C++ core later is a one-provider change; the same
  `FfiBridge` provider slot accepts the real load when Phase 3 lands.
- Cost: one mapping layer per native entry point; casual calls are annotated.

## Related

- ADR-0001 (Clean Architecture), ADR-0004 (Riverpod).