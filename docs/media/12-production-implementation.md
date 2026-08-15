# 12 — Production Implementation

## 12.1 Performance

| Concern | Strategy |
| --- | --- |
| Large files | Never load whole files: `RandomAccessFile` windows of `chunkSize`; O(1) memory growth |
| Single read pass | File SHA-256 + per-chunk hashes computed in one streaming pass during staging |
| Disk I/O | Atomic writes via temp-file + rename; sequential chunk writes; flush boundaries instead of fsync per chunk |
| Compression | Pure-Dart zlib for documents/archives; image/video compressors are pluggable interfaces (native FFI later) |
| Cache | LRU eviction in memory (bounded `maxBytes`); disk cache keyed by content hash with access-count decay |
| Chunk size | 32 KiB default, validated against the 64 KiB envelope budget |
| Background transfer | Scheduler is pure Dart timers (no UI); sessions persist so a killed process resumes after restart |

## 12.2 Memory

- Chunk window buffers are reused (single `Uint8List` allocated per session).
- Waveform buckets are capped (default 128 buckets) regardless of sample count.
- Inline payloads (≤ 8 KiB) may live in the DB; larger files never touch
  memory as a whole.
- `MediaMetadataParser` reads only the header window it needs (e.g. first
  64 KiB for MP4 `moov`/`mvhd` scan, capped search).

## 12.3 Battery

- Token-bucket pacing: `minSendInterval` (default 120 ms) between chunk
  envelope stores; bursts limited to `maxConcurrentInFlight` (default 1).
- Idle sweep every `progressInterval` (default 30 s) — no hot loops.
- Cache cleaner runs on schedule + on app-start, bounded per run
  (`cleanBatch`).

## 12.4 Reliability

- Every session transition is a SQLite transaction (bitmap + counters).
- Integrity: SHA-256 per chunk and per file; `AK` nacks requeue chunks.
- Resume: both peers persist the bitmap; `AR` requests fill gaps.
- Offline-first: the DTN layer already parks envelopes; the media layer
  treats `DtnFailure` as "try later", never as failure of the transfer.
- Storage availability is checked before staging and before finalize; a
  `storage` failure is recorded in `lastError` and retried on resume.

## 12.5 Security posture

- No secrets in the media subsystem; paths + hashes only.
- Payload columns are named/typed for ciphertext ("Encrypted Storage Ready"):
  wire envelopes carry plaintext today, exactly like messaging, and the
  future crypto layer seals envelopes before they reach DTN — no media-layer
  redesign needed.
- Paths never trust user input: file names are sanitized (`[^a-zA-Z0-9._-]`
  → `_`), and every resolved path is validated to stay under the media root.