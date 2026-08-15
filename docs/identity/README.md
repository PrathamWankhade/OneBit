# Identity (Phase 2)

The decentralized identity layer: key management, QR-based exchange, and
encrypted backup — all fully offline.

## Scope

- **Identity model**: a node owns an Ed25519 signing key and an X25519
  key-agreement key, derived from two 32-byte random seeds. The public keys
  fingerprint (`SHA-256(ed25519 public key)`) is the node's stable identity;
  a `NODE-XXXX-XXXX` short code is derived from its first eight hex digits.
- **Seed vault**: seeds never rest in plaintext. The Android Keystore wraps
  them with a hardware-backed AES-256-GCM key (ADR-0009); Dart unwraps them
  per operation.
- **QR exchange**: an identity *card* (public material, Ed25519-signed) and an
  identity *transfer* (seeds, ECDH-sealed to the recipient) travel as
  `OB1:<base64url json>` payloads (see `qr-protocol.md`).
- **Encrypted backup**: the full identity (seeds, profile, contacts) is
  exported as a passphrase-protected document (see `backup-format.md`).
- **Trust contacts**: peers discovered via QR cards; verification via
  out-of-band 6-digit codes (`onebit/verify-contact/v1`).

## File map

```
lib/core/crypto/
├── identity/
│   ├── node_id.dart            NODE-XXXX-XXXX identifier
│   ├── fingerprint.dart        SHA-256 fingerprint of the identity key
│   ├── identity_crypto.dart    Ed25519 sign/verify (Dart)
│   ├── exchange_crypto.dart    X25519 + HKDF-SHA256 + AES-256-GCM
│   ├── qr_domain.dart          QrIdentityCard / QrTransferContent models
│   └── qr_payload.dart         OB1: wire codec (canonical JSON + signature)
├── verification/verification_code.dart   6-digit mutual verification codes
├── backup/
│   ├── backup_format.dart      ONEBITBC document layout
│   └── backup_cipher.dart      passphrase → HKDF → AES-256-GCM (AAD bound)
└── keystore/
    ├── keystore_key_bridge.dart        vault contract
    ├── keystore_channel_bridge.dart    MethodChannel implementation
    └── keystore_providers.dart         IdentityVault aliases + provider

lib/features/identity/
├── domain/
│   ├── node_identity.dart      public identity material (no secrets)
│   ├── identity_seeds.dart     transient seed holder (never persisted)
│   ├── user_profile.dart       display name / avatar / tagline
│   ├── trust_contact.dart      public peer record
│   ├── trust_level.dart        known / verified / blocked
│   ├── identity_repository.dart
│   ├── trust_contact_repository.dart
│   └── use_cases/              17 use cases (see architecture.md)
├── data/
│   ├── identity_repository_impl.dart       vault + SharedPreferences
│   └── in_memory_trust_contact_repository.dart
└── presentation/
    ├── identity_providers.dart            composition root
    ├── identity_controller.dart           AsyncNotifier<NodeIdentity?>
    ├── trust_contacts_controller.dart
    ├── backup_controller.dart
    └── verification_controller.dart

android/.../IdentityKeystore.kt      AES-GCM wrapping vault
android/.../MainActivity.kt         channel dev.onebit.onebit/identity
```

## Status

- Crypto primitives, QR codec, backup format, repositories, use cases,
  Riverpod controllers, Kotlin vault bridge: **implemented and tested**
  (`flutter analyze` clean, `flutter test` green).
- Not yet built: identity screens/UI (onboarding, profile, QR scanner),
  persistent trust-contact storage, and the Phase 3 C++ acceleration.
