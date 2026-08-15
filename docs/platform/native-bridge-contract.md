# Platform Bridge Contract

## Seams

Two interfaces in `lib/core/platform/` are the **only** ways Dart touches
native code:

### 1. NativeChannelBridge (MethodChannel → Kotlin/Java)

```dart
abstract interface class NativeChannelBridge {
  String get channelName;
  Future<Result<Object?>> invoke(String method, [Object? arguments]);
}
```

- Impl: `MethodChannelNativeBridge` (`MethodChannelNativeBridge` in
  `core/platform/method_channel_native_bridge.dart`).
- Channel names: `core/platform/channel_names.dart`
  (`dev.onebit.onebit/native` live; `/identity` live; `/ble`, `/storage`
  declared).
- Host side: `android/.../MainActivity.kt` registers handlers per channel.
- Method names: `core/platform/channel_names.dart` (`PlatformMethods`,
  `IdentityKeystoreMethods`).
- Errors: `PlatformException`/`MissingPluginException` → `PlatformFailure`.

### Identity channel (`dev.onebit.onebit/identity`)

Contract between `KeystoreChannelBridge`
(`lib/core/crypto/keystore/keystore_channel_bridge.dart`) and
`IdentityKeystore.kt` (ADR-0009):

| Method | Arguments | Returns | Errors |
| --- | --- | --- | --- |
| `storeSeed` | `alias` (String), `seed` (String, base64url unpadded, 32 B) | `null` | `BAD_ARGS`, `STORE_FAILED` |
| `loadSeed` | `alias` | `String` base64url seed, or `null` | `KEY_NOT_FOUND` |
| `hasIdentity` | `alias` | `bool` | — |
| `deleteIdentity` | `alias` | `null` (idempotent) | — |

- Seeds arrive and leave the channel base64url-encoded (padding stripped);
  Dart restores padding on decode.
- `KEY_NOT_FOUND` maps to `IdentityFailure(code: 'key_not_found')` so callers
  can distinguish "cold start" from corruption.
- Aliases: `onebit.identity.v1` (Ed25519 seed), `onebit.identity.v1.exchange`
  (X25519 seed). Kotlin wraps each seed with a hardware-backed AES-256-GCM
  key (`onebit_seed_wrap`) and persists the wrapped blob in
  `SharedPreferences` (`"onebit_identity"`).

### 2. FfiBridge (FFI → C++ core)

```dart
abstract interface class FfiBridge {
  bool get isAvailable;
  String get libraryName;
  Future<Result<Uint8List>> invoke(String symbol, Uint8List payload);
}
```

- Phase 1 ships `UnavailableFfiBridge` (truthful: core not linked) returning
  `UnsupportedOperationFailure(feature: 'ffi-core')`.
- Phase 3 replaces the provider body only: load
  `libonebit_native.so` via `dart:ffi`, pin `extern` symbols, keep the
  interface unchanged.

## Rules

1. Native exceptions are converted to `Failure` **inside the bridge**; callers
   never see platform types.
2. Bridges are synchronous-safe and idempotent; long-running BLE operations
   use the event stream side of MethodChannel (Phase 4) — same bridge
   interface, extended via new methods.
3. Capability probes are explicit: `PlatformCapabilities` (used by the home
   console) is derived from the bridges' real state, never hardcoded.
4. New native capabilities = new methods on existing channels; new channels =
   add constant in `channel_names.dart` + handler registration in
   `MainActivity.kt`.
