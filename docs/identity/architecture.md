# Identity Architecture

## Components

```
┌──────────────────────── Presentation ────────────────────────┐
│ IdentityController · TrustContactsController                  │
│ BackupController · VerificationController                     │
│ identity_providers (composition root)                         │
└────────────────────────────┬──────────────────────────────────┘
                             │ use cases
┌────────────────────────────▼──────────────────────────────────┐
│ Domain                                                         │
│ NodeIdentity · UserProfile · TrustContact · TrustLevel        │
│ IdentityRepository · TrustContactRepository                   │
│ Use cases: create/load/update/delete identity, sign/verify,   │
│   shared-secret, load-seeds, build/decode card,               │
│   encode/decode transfer, derive verification code,           │
│   load/add/update/remove contact, export/import backup        │
│ → returns Result<T>, never throws, never imports Flutter      │
└────────────────────────────▲──────────────────────────────────┘
                             │
┌────────────────────────────▼──────────────────────────────────┐
│ Data                                                        │
│ IdentityRepositoryImpl (KeystoreKeyBridge + SharedPreferences)│
│ InMemoryTrustContactRepository (volatile by design)          │
└────────────────────────────▲──────────────────────────────────┘
                             │
┌────────────────────────────▼──────────────────────────────────┐
│ Core crypto (pure Dart) + Platform                          │
│ IdentityCrypto (Ed25519) · ExchangeCrypto (X25519+HKDF+AES)   │
│ QrPayloadCodec (OB1:) · BackupCipher/Format               │
│ KeystoreChannelBridge → MethodChannel dev.onebit.onebit/identity│
└────────────────────────────▲──────────────────────────────────┘
                             │
┌────────────────────────────▼──────────────────────────────────┐
│ Native                                                   │
│ IdentityKeystore.kt (AES-256-GCM in AndroidKeystore)          │
└───────────────────────────────────────────────────────────────┘
```

## The seed lifecycle

1. `createIdentity(displayName, avatarColor)` draws two 32-byte seeds with
   `SecureRandomUtil.randomBytes`, derives public keys, computes the
   fingerprint, writes both seeds to the vault (`storeSeed` × 2), and persists
   only *public* metadata JSON under `onebit.identity.v1.metadata`.
2. `NodeIdentity` (the value shown to the UI) carries **no** secret bytes.
3. Every signing / ECDH call re-loads the seeds from the vault for the
   duration of the operation (`sign`, `sharedSecret`, `loadSeeds`), then
   discards them.

## Stored metadata

```
onebit.identity.v1.metadata (SharedPreferences, JSON):
  v          metadata schema version (1)
  uuid       RFC-4122 version-4 id (stable for life)
  nodeId     NODE-XXXX-XXXX
  fp         64-char fingerprint hex
  createdAt  ISO-8601 UTC
  ed, x      base64url public keys (32 B each)
  profile    UserProfile { displayName, avatarColor, tagline? }
```

Load failure modes (distinct `IdentityFailure` codes):

| Condition | Code |
| --- | --- |
| No metadata (fresh install) | `Ok(null)` |
| Metadata present, vault empty | `vault_missing` |
| Metadata JSON corrupt | `metadata_corrupt` |
| Vault missing a seed on `sign` | `key_not_found` |
| createCall when identity exists | `already_exists` |
| Operation without identity | `not_created` |
| Update of missing trust contact | `contact_not_found` |

## Use cases

`BuildIdentityCard` / `DecodeIdentityCard` wrap `QrPayloadCodec` (signing
delegates to the repository; verification is static `IdentityCrypto.verify`).
`EncodeIdentityTransfer` loads seeds and seals to a recipient public key; the
codec owns a fresh ephemeral X25519 key, so the sender needs no private
material beyond the payload itself. `DecodeIdentityTransfer` derives the ECDH
secret against the embedded ephemeral key using the device's exchange seed.

`RepositoryBridgeFailure` adapts repository `Result`s into exceptions only for
crypto library callbacks (`signer`/`verifier`/`sharedSecret`) whose return
types cannot carry `Result`.

## Key derivation (domain separation)

Every mixing step binds a protocol context so keys never cross flows:

| Flow | HKDF info | Notes |
| --- | --- | --- |
| QR transfer | `onebit/qr/transfer/v1` | salt = sender ephemeral public |
| Backup | `onebit/backup/v1` | salt = random 16 B per export |
| Verification code | `onebit/verify-contact/v1` | no HKDF; plain SHA-256 |

## Out of scope here

- UI / onboarding / QR scanner screens.
- Persistent trust-contact store (volatile `InMemoryTrustContactRepository`).
- Phase 3: move Ed25519/X25519/backup into the C++ core.

## Related

- `docs/identity/README.md`, `docs/identity/qr-protocol.md`,
  `docs/identity/backup-format.md`, ADR-0009.
- Tests: `test/core/crypto/**`, `test/features/identity/**`.