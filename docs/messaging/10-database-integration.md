# Database Integration — Drift Schema

Schema version: **3** (was 2). One shared `OneBitDatabase`; no per-feature
databases. All new tables, columns and the FTS index ship in migration step
v3, additive only — existing tables are only extended, never reshaped.

## New tables (`messaging_tables.dart`)

| Table | PK | Purpose |
| --- | --- | --- |
| `MessageDrafts` | channelId | one draft per channel; `editedMessageId` optional |
| `PinnedMessages` | (channelId, messageId) | pinned message registry |
| `MessageReactions` | (messageId, node, reaction) | emoji reactions |
| `MessageMetadata` | messageId | clientId, packetId, attemptCount, lastError, verifiedAt |
| `Notifications` | notificationId (autoincrement) | internal notification log |

Plus the FTS5 virtual table `message_search` created via
`CREATE VIRTUAL TABLE ... USING fts5(...)` (raw SQL, not declared in
`@DriftDatabase` so drift codegen stays stable):

```
message_fts(message_id UNINDEXED, channel_id UNINDEXED, body,
            sender, node_name, type UNINDEXED, timestamp UNINDEXED,
            tokenize='porter unicode61')
```

The index is **write-through** in the DAO (never triggers — the engine is
the only writer and keeps repair/rebuild under its control).

## Column additions (migration v3)

`Messages`:

```sql
ALTER TABLE messages ADD COLUMN sequence INTEGER NOT NULL DEFAULT 0;
ALTER TABLE messages ADD COLUMN client_id TEXT;
ALTER TABLE messages ADD COLUMN packet_id TEXT;
ALTER TABLE messages ADD COLUMN body_text TEXT;
ALTER TABLE messages ADD COLUMN read_at INTEGER;
ALTER TABLE messages ADD COLUMN verified INTEGER NOT NULL DEFAULT 0;
ALTER TABLE messages ADD COLUMN starred INTEGER NOT NULL DEFAULT 0;
```

`Channels`:

```sql
ALTER TABLE channels ADD COLUMN last_sequence INTEGER NOT NULL DEFAULT 0;
```

Indexes added in v3 (declared on the tables so fresh installs and
migrations agree):

```
idx_messages_channel_ts  (exists)   -- timeline pagination
idx_messages_sender, idx_messages_status (exist)
+ idx_messages_channel_seq (channel_id, sequence DESC)
idx_message_drafts_channel   (channel_id)
idx_pinned_channel          (channel_id, pinned_at)
idx_notifications_created   (created_at)
```

## Migration mechanics

1. `MigrationRegistry.currentVersion = 3` + one `MigrationStep(v3)` using
   `Migrator.addColumn` / `migrator.createTable` for declarative tables.
2. The FTS table is created in **both** `onCreate` (fresh install) and the
   v3 step (`IF NOT EXISTS`), via a shared `MessagingSchema` helper.
3. Snapshot regenerated: `dart run tool/generate_schema_snapshot.dart` →
   `dev_build/schema/onebit_v3.sql`; `schema_snapshot_test` then verifies
   byte-for-byte equality with a live fresh install.
4. `test/core/database/migration_test.dart` expectations bumped to v3.

## Query performance notes

- Timeline: `WHERE channel_id=? ORDER BY timestamp DESC, sequence DESC,
  message_id DESC LIMIT ?` — index offers seek-per-channel, no table scan.
  100k messages stay comfortably inside single-digit ms at 200 rows/pages.
- Unread listing: the summary lives in `Channels`, `ORDER BY pinned DESC,
  updated_at DESC` — already indexed.
- Search: FTS `MATCH` + join `Messages` for hydration; page bounded.
- Drafts/reactions/pins are small tables keyed by FK — trivial.

## Retention & compaction

`purgeDeleted(olderThan)` hard-deletes tombstones and cascades
(receipts/reactions/metadata) by FK; `VACUUM` is out of scope for this phase
(SQLite handles it automatically on checkpoints).