# Backup document format

The identity (seeds, profile, contacts) can be exported to a
passphrase-protected document and restored on any device. Format version 1,
`BackupFormat` / `BackupCipher` (`lib/core/crypto/backup/`).

## Layout

```
[8-byte magic "ONEBITBC"][1-byte version][UTF-8 JSON envelope]
→ whole document base64url-encoded (padding stripped) for transport
```

The envelope JSON:

```json
{
  "kdf": { "alg": "HKDF-SHA256", "salt": "<b64url 16 bytes>", "iterations": 1 },
  "aad": { "id": "NODE-XXXX-XXXX", "created": "<ISO-8601 UTC>" },
  "nonce": "<b64url 12 bytes>",
  "ct": "<b64url ciphertext>",
  "mac": "<b64url 16 bytes>"
}
```

## Key schedule and authentication

```
key = HKDF-SHA256(passphrase, salt, info = "onebit/backup/v1")
AAD = utf8(json({"id": nodeId, "created": createdAt}))
box = AES-256-GCM(key, nonce, plaintext, aad)
```

- A fresh random 16-byte salt and 12-byte nonce are generated per export, so
  identical inputs never produce identical documents.
- The header (`BackupAad`) is authenticated as AAD: swapping the header of one
  backup onto another fails authentication.
- Wrong passphrase or any byte-level tampering yields a
  `BackupFailure(operation: 'decrypt')`, never a raw exception.

## Plaintext

```json
{
  "v": 1,
  "uuid": "<version-4 uuid>",
  "nodeId": "NODE-XXXX-XXXX",
  "fp": "<64-char fingerprint hex>",
  "createdAt": "<ISO-8601 UTC>",
  "profile": { "displayName": "...", "avatarColor": 3, "tagline": "..." },
  "seed": "<b64url 32-byte ed25519 seed>",
  "xseed": "<b64url 32-byte x25519 seed>",
  "contacts": [ TrustContact.toJson(), ... ]
}
```

## Import validation (`IdentityRepositoryImpl.importBackup`)

1. `BackupFormat.decodeDocument` (magic/version/JSON) — parse errors →
   `BackupFailure(operation: 'parse')`.
2. `BackupCipher.decrypt` — wrong passphrase / tamper → `BackupFailure`.
3. The imported seeds are re-derived: `SHA-256(ed25519(seed))` must equal
   `fp` and `NodeId.fromFingerprintHex(fp)` must equal `nodeId` — a backup
   whose identity does not match its own fingerprint is rejected
   (`BackupFailure(operation: 'import')`).
4. Seeds are re-wrapped into the Keystore vault, metadata is persisted, and
   contacts are re-created through `TrustContactRepository`.

## Related

- `docs/identity/architecture.md`, `lib/core/crypto/backup/*.dart`,
  `test/core/crypto/backup/*_test.dart`.