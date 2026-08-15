# Future Expansion

The schema and layering are designed so later phases add logic, never redesign.

## 1. SQLCipher (encrypted database)

- `sqlcipher_flutter_libs` is already a transitive dependency of `drift_flutter`.
- Switching = replacing `ConnectionFactory` with a SQLCipher opener
  (`sqlite3.open` + `cipherOptions`), one seam. PRAGMAs, migrations, DAOs and
  repositories are untouched. All private material already stays out of SQLite
  (payloads are app-layer ciphertext), so SQLCipher is defense-in-depth.

## 2. Bluetooth / Mesh / Relay phases

Schema already reserves every construct:

- `neighbors` + `node_profiles` → discovery, presence sweeps (`last_seen`).
- `routes` → next-hop selection (`quality`, `hop_count`, `expiration`).
- `packets` / `packet_fragments` → BLE transmit/receive + reassembly.
- `pending_queue` / `retry_queue` / `relay_queue` → outbound pipeline with
  backoff (`next_attempt_at`, `backoff_ms`) exactly as transports need.
- `delivery_receipts` / `read_receipts` / `typing_events` → messaging signals.
- `sessions` / `session_keys` → ratchet state with `ratchet_step` ordering.

## 3. Synchronization & multi-device

- Tables carry timestamps; `routes`/`neighbors` have explicit `expiration`.
- `application_metadata.schema_version` + row-level IDs give reconciliable
  keysets; `insertOnConflictUpdate` makes merges idempotent.
- The backup module already exposes versioned, integrity-checked export bytes.

## 4. Growth to millions of rows

- All hot paths are indexed and paginated; payload blobs are lazily loaded and
  heavy binaries live on disk, not in the file.
- Retention sweeps keep the file bounded. Counters (`statistics`) avoid table
  scans for dashboards.
- If ever needed, drift table partitioning or per-channel shard files slot in
  behind the `ConnectionFactory` seam — repositories/DAOs do not change.

## 5. Offline-first architecture

- SQLite is the source of truth; there is no remote write path. When internet
  connectivity is considered later (explicitly out of scope now), the
  repository boundary is the single synchronous seam — imports and exports
  already move whole-table snapshots atomically.

## Boundaries honored this phase

- **No** Bluetooth/BLE, mesh routing, relay logic, messaging UI, or
  cryptographic sessions — only their persistence seams, DAO CRUD, and tests.