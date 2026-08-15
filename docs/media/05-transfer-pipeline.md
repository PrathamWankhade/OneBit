# 05 — Transfer Pipeline

## 5.1 The pipeline at a glance

```
attach → stage → probe → compress(optional) → persist catalog
     ↓
startTransfer → announce → [chunk loop] → verify → complete
     ↑                                        ↑
     └── pause/resume/cancel/retry ────────────┘
```

## 5.2 Transfer state machine

```
                  ┌──────────┐
        start ───▶│  queued  │
                  └────┬─────┘
                       │ announce stored
                  ┌────▼─────┐
                  │transferring│◀──────────────┐
                  └────┬─────┘                │ resume
                       │ pause                │
                  ┌────▼─────┐   resume   ┌───┴────┐
                  │  paused  │───────────▶│ resuming│
                  └────┬─────┘            └───┬────┘
                       │ resume              │ chunks re-queued
                       │                     │
                       ▼                     ▼
                  ┌─────────────────────────────────┐
                  │           transferring          │
                  └───────────────┬─────────────────┘
                                  │ all chunks acked
                          ┌───────▼────────┐
                          │  verifying     │──(file hash ok)──▶ completed
                          └───────┬────────┘
                                  │ (hash mismatch)
                                  ▼
                             failed ──retry──▶ queued
                 cancelled (user)   expired (TTL)   failed(permanent)
```

Transitions are persisted in `TransferSessions.state`; only the
`TransferEngine` writes them. `TransferState` values (never renamed once
released): `queued, transferring, paused, resuming, verifying, completed,
failed, cancelled, expired`.

## 5.3 Pipeline stages

| Stage | Owner | Work |
| --- | --- | --- |
| 1. Stage | `AttachmentStore.stage` | copy source into `attachments/<category>/` with atomic rename; reject if source disappears mid-copy |
| 2. Probe | `MediaMetadataParser.parse` | extract dimensions/duration/pages; fill `MediaDetail` |
| 3. Compress | `CompressionEngine.compress` | optional; replaces staged file when gain ≥ threshold |
| 4. Persist | `AttachmentRepository.save` | catalog row + metadata + sha256 |
| 5. Announce | `TransferEngine` → `AttachmentManager` | `AM` envelope with manifest |
| 6. Chunk loop | `ChunkScheduler` | paced dispatch of `AC` envelopes; retries with backoff |
| 7. Ack handling | `TransferEngine` | `AK` → bitmap update; nack → requeue chunk |
| 8. Verify | `TransferEngine` | whole-file SHA-256 on receiver; session complete |
| 9. Cleanup | `TransferEngine` / `CacheCleaner` | temp purge, stats update |

## 5.4 Chunk pacing (battery + congestion)

The `ChunkScheduler` implements a token-bucket pace:

- `maxConcurrentInFlight` chunks in flight at once (default 1 — BLE links
  are narrow; the DTN layer already queues).
- `minSendInterval` between chunk stores (default 120 ms; configurable in
  `DtnEngineConfig`-style `MediaEngineConfig`).
- Per-chunk retry budget before the scheduler parks the session
  (`deferred` semantics are inherited from DTN — the media layer simply
  stops pushing and waits for the connectivity event).
- Resume re-uses the bitmap: only missing chunks are re-sent, nothing else.

## 5.5 Failure classification

| Failure | Media layer action |
| --- | --- |
| DTN `DtnFailure` on store | session stays `transferring`; scheduler backs off |
| Chunk nack (`AK` ok=false) | chunk requeued (attempts+1); after max attempts → session `failed` |
| File hash mismatch at receiver | session `failed(integrity)`; retry allowed |
| User cancel / TTL expiry | `cancelled` / `expired`; temp files purged |
| Receiver never acks (timeout) | chunk requeued; if repeated → `failed` |
| Storage full at receiver | `failed(storage)` with lastError; retry allowed |

## 5.6 Concurrency

- One scheduler loop per active outbound session.
- Inbound envelopes are processed sequentially on the engine's dispatch
  stream (chunk order preserved per session).
- All state transitions are serialized through the repository (SQLite
  transactions), so concurrent pause/resume/cancel calls cannot corrupt the
  bitmap.