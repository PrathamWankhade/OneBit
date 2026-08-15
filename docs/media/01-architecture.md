# 01 — Media Architecture

## 1. Position in the application

The Media Engine occupies the same architectural slot as the Messaging
Engine: it is a domain-side façade over the local database, the file system
and the DTN delivery layer. It has **no import of Flutter UI**, no widgets,
no animation, no theme knowledge, and no direct Bluetooth / mesh / packet
code. Its only contact with the network is `DTNRepository`.

```
┌─────────────────────────────────────────────────────────────┐
│ Flutter UI (Phase 10+ controllers & widgets)                │
└──────────────┬──────────────────────────────────────────────┘
               │ use cases / providers
┌──────────────▼──────────────────────────────────────────────┐
│ MediaRepository (aggregate contract)                        │
│   MediaEngine (façade)                                      │
│   Use cases                                                 │
├─────────────────────────────────────────────────────────────┤
│ AttachmentRepository  TransferRepository  ThumbnailRepository│
│ VoiceRepository       CacheRepository    PreviewRepository   │
├─────────────────────────────────────────────────────────────┤
│ Validation │ Storage │ Compression │ Probe │ Thumbnail │     │
│ Cache (mem/disk)  │  TransferEngine (chunks)               │
│ AttachmentManager (wire codec)                             │
├─────────────────────────────────────────────────────────────┤
│ DTNRepository (envelopes)  │  OneBitDatabase (Drift)       │
│ SQLite                    │  AttachmentStore (files)       │
├─────────────────────────────────────────────────────────────┤
│ Packet Protocol → Mesh → Bluetooth (opaque, never imported) │
└─────────────────────────────────────────────────────────────┘
```

## 2. Layer rules

| Rule | Enforced by |
| --- | --- |
| Domain never imports Flutter UI | `flutter_lints` + code review |
| Data layer implements domain contracts only | `implements` on every SQLite repo |
| Transfer touches the network only via `DTNRepository` | constructor injection |
| All cross-boundary calls return `Result<T>` | `Result` / `Ok` / `Err` |
| Models are immutable; `copyWith` is explicit | `final` fields, sealed unions |
| Exceptions are converted to `Failure` exactly once at edges | `ExceptionMapper` / `ResultGuards` |
| Media never reads/writes Bluetooth classes | import lint in CI |

The file system boundary is the `AttachmentStore`; the wire boundary is the
`AttachmentWireCodec` + `AttachmentManager`. Everything above those two
boundaries is pure domain code that is unit-testable without a device.

## 3. Subsystem responsibilities

- **Attachments** — the catalog model, identity, lifecycle.
- **Transfer** — chunked, resumable, integrity-checked movement of bytes
  between two nodes over DTN.
- **Storage** — physical organization of media, temp, cache and download
  directories; atomic writes.
- **Validation** — size/type/checksum/extension/corruption/duplicate/space.
- **Compression** — pluggable compressors, quality profiles, thresholds.
- **Preview/Probe** — pure-Dart metadata extraction (dimensions, duration,
  pages) for images, videos, audio and documents.
- **Thumbnails** — lazy, cached thumbnail generation.
- **Voice** — recorder/player seams, waveform metadata, recording storage.
- **Cache** — memory LRU + disk cache with cleanup and statistics.
- **DTN bridge** — the `AttachmentManager` maps media envelopes to DTN
  envelopes and back. This is the "Packet Protocol" position in the
  subsystem: media envelopes are the packet payloads.

## 4. Dependency graph

```
engine → repository contracts → sqlite repos → dao → database
engine → attachment manager → wire codec → DTNRepository
engine → compression / validation / storage / cache / probes (plugins)
```

No cycle exists between layers; the engine composes plugins that all depend
only on interfaces, so tests inject fakes for every seam.

## 5. Envelope kind partition

The DTN layer delivers opaque payloads. The media subsystem marks its
envelopes with a `kind` discriminator so it can coexist with messaging
envelopes on the same delivery seam:

| Kind | Meaning | Direction |
| --- | --- | --- |
| `AM` | announce (session manifest) | sender → receiver |
| `AC` | chunk payload | sender → receiver |
| `AK` | chunk ack / nack | receiver → sender |
| `AR` | chunk request (resume) | receiver → sender |
| `AP` | pause signal | either |
| `AD` | complete + file hash | sender → receiver |
| `AX` | cancel | either |

Messaging's pump forwards payloads it does not recognize to the media
engine through a small observer hook (see `10-riverpod-providers.md`), so
both subsystems share the single `observeDelivered()` seam without coupling
their domain code.

## 6. Reliability posture

The mesh is intermittent: connectivity appears and disappears, relays drop
packets, TTLs expire. The engine therefore:

- persists every transfer session and chunk bitmap in SQLite (crash-safe),
- verifies every chunk with SHA-256 before acking,
- verifies the reassembled file SHA-256 before completing,
- resumes from the bitmap instead of restarting a transfer,
- never marks a transfer failed because of temporary connectivity — the DTN
  layer already parks and retries envelopes; the media layer only reacts to
  terminal or time-bounded states.