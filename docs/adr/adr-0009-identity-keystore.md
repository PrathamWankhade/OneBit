# ADR-0009 — Android Keystore wraps identity seeds; crypto runs in Dart

Status: Accepted

## Context

OneBit's identity is a pair of key pairs: an Ed25519 signing key and an
X25519 key-agreement key, both derived from 32-byte random seeds. The seeds
are the only secret material on the device, so they must never rest in
plaintext and must never travel through domain models or `Result` payloads.

Two candidate approaches existed:

1. Store the actual key pairs inside the Android Keystore (`KeyGenParameterSpec`
   with `KeyProperties.KEY_ALGORITHM_ED25519` / X25519 support) and let the
   Keystore sign / derive secrets.
2. Store only *wrapped seed blobs* in the Keystore (AES-256-GCM key inside the
   hardware-backed Keystore), and perform the actual cryptography in Dart with
   the `cryptography` package, unwrapping the seed only for the lifetime of a
   single operation.

## Decision

Adopt option 2: **the Keystore is a seed vault, not a key engine.**

- Kotlin (`IdentityKeystore.kt`) holds a single AES-256-GCM key
  (`onebit_seed_wrap`, generated in the `AndroidKeyStore`) and exposes four
  channel methods: `storeSeed`, `loadSeed`, `hasIdentity`, `deleteIdentity`.
- Each identity seed is wrapped with a fresh IV and persisted (base64) in
  Android `SharedPreferences` under `"onebit_identity"`, keyed by alias
  (`onebit.identity.v1`, `onebit.identity.v1.exchange`).
- All Ed25519 and X25519 math runs in Dart (`lib/core/crypto/identity/`)
  on the transiently unwrapped seed. Seeds are materialized inside
  `IdentityRepositoryImpl` only, per operation, and are never stored on
  identity models.

## Why

- **X25519 gating**: Android Keystore X25519/Ed25519 support is only reliable
  on API 31+; minSdk is 24. AES-GCM wrapping works everywhere.
- **Pure-Dart crypto is testable**: `flutter test` runs the full key/QR/backup
  suite on the CI VM with the same code paths as devices.
- **One trust boundary**: the Dart layer keeps a single contract
  (`KeystoreKeyBridge`) that tests can fake; Kotlin stays a thin wrapper.
- **Phase 3 acceleration**: replacing the Dart Ed25519/X25519 primitives with
  the C++ core later only touches `IdentityCrypto`/`ExchangeCrypto`, not the
  vault contract.

## Consequences

- A device that loses the Keystore wrapper (factory reset of the Keystore
  namespace, reinstall with cleared data) cannot unwrap seeds; `loadIdentity`
  distinguishes `vault_missing` (metadata present, vault empty) from
  `metadata_corrupt`.
- The seed exists in Dart memory briefly per operation; native memory hygiene
  (zeroing buffers) is deferred to the Phase 3 C++ core.
- The channel contract is stable: `storeSeed(alias, seed)` /
  `loadSeed(alias)` / `hasIdentity(alias)` / `deleteIdentity(alias)`, with
  error code `KEY_NOT_FOUND` mapping to `IdentityFailure(code:
  'key_not_found')` in Dart.

## Related

- `docs/identity/architecture.md`, `docs/platform/native-bridge-contract.md`,
  `android/app/src/main/kotlin/dev/onebit/onebit/IdentityKeystore.kt`,
  `lib/core/crypto/keystore/keystore_key_bridge.dart`.
