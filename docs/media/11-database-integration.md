# 11 — Database Integration

## 11.1 Tables (new in v5 — `tables/media_tables.dart`)

| Table | Row class | Purpose |
| --- | --- | --- |
| `MediaAttachments` | `MediaAttachmentRow` | catalog: id, message id, category, file name, mime, size, sha256, media-detail JSON, local path, status, timestamps |
| `TransferSessions` | `TransferSessionRow` | session: id, attachment id, peer, direction, state, chunk size, total chunks, chunk bitmap (BLOB), bytes transferred, timestamps, last error |
| `TransferChunks` | `TransferChunkRow` | chunk ledger: (session id, index) PK, offset, size, sha256, state, attempts, sent/acked timestamps |
| `MediaThumbnails` | `MediaThumbnailRow` | id, attachment id, kind, width, height, path, size, generated at |
| `MediaPreviews` | `MediaPreviewRow` | id, attachment id, kind, metadata JSON, thumbnail id, created at |
| `VoiceRecordings` | `VoiceRecordingRow` | voice note id, message id, file name, mime, size, duration ms, sample rate, waveform JSON, path, created at |
| `CacheEntries` | `CacheEntryRow` | key, kind, size, access count, last access, created at, path |
| `MediaStatistics` | `MediaStatisticRow` | (kind, key) PK, value, recorded at — the durable mirror of `TransferStatistics` counters |

Indexes: `idx_media_attachments_message` (message id), `idx_transfer_sessions_attachment` (attachment id), `idx_transfer_chunks_session` (session id, index), `idx_media_thumbnails_attachment`, `idx_cache_entries_kind`.

## 11.2 Registering

- Add the eight tables to `@DriftDatabase(tables: [...])` in
  `database.dart`.
- `MigrationRegistry.currentVersion = 5` and a new `MigrationStep`
  `_createMediaSchema` (creates the tables + indexes via `migrator`).
- Regenerate the committed snapshot: `dart run tool/generate_schema_snapshot.dart`
  → `dev_build/schema/onebit_v5.sql`; `schema_snapshot_test` then compares
  the live schema to it.
- `migration_test.dart` asserts the step list; update `[2,3,4]` → `[2,3,4,5]`.

## 11.3 DAO — `media_dao.dart`

One `@DriftAccessor(tables: [...])` exposing typed ops; all repository I/O
runs through it:

- `insertAttachment / attachmentRow / attachmentsForMessage / deleteAttachment / updateAttachmentStatus / purgeAttachmentsBefore`
- `insertSession / sessionRow / updateSession / activeSessions / sessionsForAttachment / purgeSessionsBefore`
- `chunkRow / insertChunk / updateChunk / chunksForSession / markChunkState`
- `thumbnail ops`, `preview ops`, `voice ops`, `cache ops`, `statistics upsert/read`
- `summary()` — per-category counts + bytes (drives `MediaSummary`)

Chunk bitmap transitions happen inside `transaction()` so
`bytesTransferred` and the bitmap can never disagree.

## 11.4 Conventions followed

- Enums stored as stable `textEnum` names (never ordinals).
- `DateTime` via `dateTimeMsConverter` (ms INTEGER).
- Every repository method wrapped in `ResultGuards.guard` → `Err(StorageFailure)`
  on exception; watch streams use `ResultGuards.guardWatch`.
- Row → domain conversion only in `media_row_mappers.dart`.
- Plaintext file bytes stay on disk, not in the DB; the DB stores paths +
  hashes + the small `isInline` payload escape hatch for tiny files
  ("Encrypted Storage Ready" is honored by keeping payload columns named
  `encryptedData`-style and never assuming plaintext).