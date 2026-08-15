# Performance Strategy

Goals: sub-millisecond single-row reads, low-single-digit-ms paginated reads on
million-row tables, and fast bulk ingestion during mesh bursts. All measures
are present in the schema and code; none require a redesign later.

## 1. Indexes (hottest paths)

- `messages(channel_id, timestamp)` — primary timeline scan; covering index for
  `WHERE channel_id=? ORDER BY timestamp DESC LIMIT n`.
- `messages(sender)`, `messages(status)` — outbox / status sweeps.
- `packets(destination)`, `packets(source)`, `packets(expires_at)` — routing and
  expiry GC.
- `packet_fragments(packet_id, sequence)` — reassembly order.
- `routes(next_hop, quality)`, `neighbors(last_seen)`, `neighbors(status)`.
- `sessions(node)`, `session_keys(session_id, ratchet_step)`.
- `retry_queue(next_attempt_at)`, `relay_queue(state, enqueued_at)`,
  `pending_queue(priority, next_attempt_at)`.
- `logs(timestamp)`, `statistics(name, recorded_at)`.

SQLite needs one index per hot `WHERE` + `ORDER BY`; compound indexes avoid
filesort entirely.

## 2. Prepared statements

Drift compiles each query once (object identity) and prepares it lazily on
first execution — no SQL re-parsing per call. DAO queries are class fields, so
they are inherently reused (prepared statement requirement).

## 3. Transactions

- Multi-table writes (message + attachments, packet + fragments, session +
  keys, backup import) run in a single `transaction()` — one WAL commit, one
  fsync.
- Queue drains batch `UPDATE`s inside a transaction, never per-item commits.

## 4. Batch operations

- Ingest uses `db.batch(...)` → `insertAll` with array binding (one prepared
  statement, many rows). Message / attachment / packet DAOs expose `insertAll`.
- `insertOnConflictUpdate` makes re-delivered packets and messages idempotent.

## 5. Pagination

- `PageRequest(offset, limit)` → `LIMIT ? OFFSET ?` with an ORDER BY matching
  the covering index (no sort). A page of 200 rows on a million-row channel is
  one range scan + 200-row materialization.
- Aggregates (unread counts, totals) use `selectOnly` with `COUNT` / `MAX` and
  never materialize rows.

## 6. Lazy loading

- Payload blobs load per row; large binary attachments/voice notes live on
  disk (`local_path`) with metadata in SQLite, so the DB file stays small.
- `watch` streams are scoped to visible windows (one channel at a time), never
  whole tables.

## 7. Write tuning

- WAL journaling + `synchronous=NORMAL` + `busy_timeout=5000` — concurrent
  readers/writers with far fewer fsyncs than FULL, no lost commits.
- `statistics` counters answer dashboard questions without scanning big tables.

## 8. Retention / GC

- `packets` sweeps expired rows (`expires_at < now`) in bounded batches.
- Soft-deleted messages are purged by a retention sweep (count-limited),
  keeping the file size stable over months offline.
