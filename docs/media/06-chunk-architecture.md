# 06 — Chunk Architecture

## 6.1 Why chunks

The mesh moves small packets (BLE MTU-constrained, fragmented by the packet
layer). Whole-file delivery is impossible; per-envelope TTLs, retries and
acks are only meaningful on bounded payloads. Chunking gives us:

- **Granular retry** — one bad chunk never invalidates the other 999.
- **Resume** — after an interruption, only missing chunks travel again.
- **Integrity** — per-chunk SHA-256 + whole-file SHA-256.
- **Progress** — exact byte counts for UI and statistics.

## 6.2 Chunk geometry

```
file (N bytes)
├── chunk 0   [0,        chunkSize)
├── chunk 1   [chunkSize, 2*chunkSize)
│   …
└── chunk K-1 [(K-1)*chunkSize, N)     (tail may be short)
```

- `chunkSize` default **32 KiB**, allowed range 8–48 KiB.
- Constraint: a chunk must fit a DTN envelope payload budget (64 KiB) after
  wire encoding (base64 inflates 4/3; JSON framing adds overhead).
- `totalChunks = ceil(sizeBytes / chunkSize)`, K ≥ 1.

## 6.3 Chunk envelope (`AC`)

| Field | Type | Notes |
| --- | --- | --- |
| `v` | int | wire version = 1 |
| `kind` | string | `AC` |
| `sid` | string | transfer session id |
| `idx` | int | chunk index |
| `off` | int | byte offset in the file (defense in depth) |
| `sha` | string | hex SHA-256 of the chunk payload |
| `data` | string | base64 of the chunk bytes |

The receiver recomputes `sha` over the decoded `data` before writing; a
mismatch is answered with `AK ok=false` and the chunk is never written.

## 6.4 Chunk bitmap

The authoritative "what did we get" record is a **bitmap**:

- bit *i* set ⇔ chunk *i* acknowledged (sender) / received+verified
  (receiver),
- persisted as `chunksBitmap` BLOB in `TransferSessions` after **every**
  change (crash-safe resume),
- `TransferBitmap` (pure domain) converts between index sets and packed
  bytes and is fully unit-tested.

Bitmap ops: `acknowledged(i)`, `markAcknowledged(i)`, `missing()`,
`acknowledgedCount()`, `bytesToBytes()` / `fromBytes()`. A session whose
bitmap is all-ones is `completeable`.

## 6.5 Ordering and reassembly

- Chunks carry an absolute `off` + `idx`, so out-of-order arrival is safe:
  the receiver writes at `off` into the temp file (sparse-safe; each write
  is flush-bounded).
- Reassembly = concatenation by index; the temp file is `finalize()`d to
  the downloads directory only when every chunk is present and the file
  SHA-256 matches the announce.
- Duplicate chunk delivery is idempotent: bitmap check first, write once.

## 6.6 Ack / retry / resume flows

| Flow | Trigger | Action |
| --- | --- | --- |
| Ack | receiver verified chunk | `AK ok=true, idx` → sender clears in-flight, marks bitmap |
| Nack | receiver hash mismatch | `AK ok=false, idx` → sender requeues chunk (attempts+1) |
| Request | receiver missing chunk (after resume / gap) | `AR sid, idx` → sender sends that chunk next |
| Timeout | chunk in flight too long | sender requeues chunk (bounded attempts) |
| Resume | session `paused`/`failed` restart | bitmap read; only missing chunks scheduled |

## 6.7 Large file optimization

- **Never** load the whole file: the scheduler reads chunk windows via
  `RandomAccessFile` (32 KiB at a time) — peak memory is O(chunkSize).
- Streaming hash: the sender computes the file SHA-256 once while staging
  (linear pass); chunk hashes are computed during the same pass, so there
  is exactly **one** read of the source file in the whole pipeline.
- The receiver writes sequentially at offsets and verifies chunk hashes
  from the same bytes it wrote (no second read).
- Sessions older than the configurable `sessionRetention` are swept by the
  engine's periodic maintenance.

## 6.8 Wire budget math

`payload(AC) ≈ base64(32 KiB) + ~120 B framing ≈ 43.9 KiB < 64 KiB limit.`
If chunk size is raised to 48 KiB, `≈ 65.7 KiB` — rejected by validation,
which is why the validator enforces the 8–48 KiB window against the codec
budget at session creation time.