# Backup Strategy

## File format (version 1)

```
ONEBITDB  (8-byte magic)
[1 byte: format version = 1]
[header: JSON]
[payload: table JSON, zlib-compressed]
[header.integrity = sha256(payload JSON bytes) hex]
```

`header` fields: magic, format version, schema version, exported at (ISO-8601
UTC), node id, app version, table count, row count, compression mode
(`none` | `zlib`), integrity (sha256 hex of the uncompressed payload bytes).

`payload`: `{ "<table>": [ { column: value, ... }, ... ], ... }` — every row
of every table, keyed by drift column names.

## Export pipeline

1. Read all 25 tables (ordered, no join) inside a read transaction so the
   snapshot is consistent.
2. Serialize to JSON bytes; compute sha256 (integrity).
3. Compress with `zlib` (dart:io, no new dependency).
4. Optional: wrap payload with the existing `BackupCipher` — AES-256-GCM,
   HKDF-SHA256(passphrase), AAD binds the header — producing a
   `BackupEnvelope` in place of plaintext payload.
5. Emit `Uint8List` document.

## Import pipeline

1. Parse magic + version; reject anything else with a typed `BackupFailure`.
2. Verify schema version `<=` current (never import a newer schema).
3. Verify sha256 after decompression — tampered/corrupt files fail loudly.
4. Decrypt (if envelope) with passphrase — wrong passphrase fails GCM auth.
5. Rebuild inside **one transaction**: delete existing rows (replace mode) and
   insert in FK-safe order (identity → channels → messages → attachments →
   packets → fragments → …). `insertOnConflictUpdate` tolerates duplicates.
6. Apply application metadata (`last_import_at`), log the outcome.

## Properties

- **Versioned**: format byte + schema version gate forward imports.
- **Compressed**: zlib by default; typical JSON message stores shrink ~80%.
- **Integrity**: sha256 binds payload to header; no silent truncation.
- **Encryption ready AND working**: passphrase → GCM envelope; no passphrase →
  plaintext (documented trade-off for user-initiated transfers).
- **Testable**: roundtrip, tamper, bad magic, future version, wrong schema,
  wrong passphrase are all covered in `backup_test.dart`.

## Seams for later

- Incremental backups: exporter already streams table-by-table; a `since`
  filter on `updated_at` columns is a later phase.
- Cloud/transfer transport is out of scope — this module emits/consumes bytes.
