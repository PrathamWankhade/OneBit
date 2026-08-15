# OneBit Media Engine — Design Documents

The Media Engine is the Phase 9 attachment and media subsystem of OneBit: a
production-grade, offline-first pipeline that attaches, stores, compresses,
probes, thumbnails, and reliably transfers large files across the
intermittent Bluetooth mesh network.

## Reading order

| Doc | Topic |
| --- | --- |
| [01-architecture.md](01-architecture.md) | Layer model, boundaries, design rules |
| [02-folder-structure.md](02-folder-structure.md) | Module tree and responsibilities |
| [03-sequence-diagram.md](03-sequence-diagram.md) | End-to-end send/receive sequences |
| [04-class-diagram.md](04-class-diagram.md) | Class model of the whole subsystem |
| [05-transfer-pipeline.md](05-transfer-pipeline.md) | Transfer state machine and pipeline |
| [06-chunk-architecture.md](06-chunk-architecture.md) | Chunking, bitmap, ordering, ack, resume |
| [07-models.md](07-models.md) | All immutable domain models |
| [08-repositories.md](08-repositories.md) | Repository contracts |
| [09-use-cases.md](09-use-cases.md) | The ten public use cases |
| [10-riverpod-providers.md](10-riverpod-providers.md) | Provider graph |
| [11-database-integration.md](11-database-integration.md) | Drift schema v5 and DAOs |
| [12-production-implementation.md](12-production-implementation.md) | Performance, battery, I/O strategy |
| [13-testing.md](13-testing.md) | Test matrix |
| [14-future-streaming.md](14-future-streaming.md) | Streaming, encryption, native codecs |

## Design summary

```
Flutter UI
    ↓
Media Repository ──┐
    ↓              │
Media Engine       │  domain layer: models, contracts, use cases
    ↓              │
Attachment Manager ┘
    ↓
Packet Protocol (DTN envelopes — the only wire seam)
    ↓
DTN → Mesh → Bluetooth  (opaque; the media engine never touches them)
```

The Media Engine is fully independent of Flutter UI. It communicates only
through repositories and use cases, and its only transport seam is the
existing `DTNRepository` — the same seam the Messaging Engine uses. It
supports images, video, audio, voice notes, documents and archives, large
files, interrupted transfers, resume, integrity verification and pure
offline operation.