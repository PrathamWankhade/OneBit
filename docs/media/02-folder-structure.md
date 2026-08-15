# 02 — Folder Structure

```
lib/features/media/
├── attachments/                Attachment catalog (domain)
│   ├── attachment.dart         Attachment, AttachmentMetadata, MediaCategory,
│   │                           AttachmentStatus, sealed MediaDetail union
│   └── attachment_repository.dart
├── cache/                      Caching (domain + pluggable stores)
│   ├── cache_entry.dart        MediaCacheEntry model
│   ├── cache_repository.dart   CacheRepository contract
│   ├── media_cache.dart        MemoryCache (LRU) + CachePolicy
│   ├── disk_cache.dart         DiskCache (hash-keyed files, LRU eviction)
│   ├── thumbnail_cache.dart    ThumbnailCache facade over disk cache
│   └── cache_cleaner.dart      CacheCleaner (expiry + budget sweep)
├── compression/                Compression (domain)
│   ├── compression_profile.dart
│   ├── compression_statistics.dart
│   ├── compressor.dart         Compressor interface + NoopCompressor + ZlibCompressor
│   └── compression_engine.dart CompressionEngine (thresholds, dispatch, stats)
├── documents/                  Document metadata probing
│   └── document_metadata_parser.dart
├── domain/                     Subsystem façade + aggregate contract
│   ├── media_engine.dart       MediaEngine façade (start/stop, ops)
│   ├── media_repository.dart   MediaRepository aggregate contract
│   └── use_cases/              10 use cases (AttachFile, StartTransfer, …)
├── data/                       Data layer (the only layer that imports I/O)
│   ├── attachment_manager.dart AttachmentManager — DTN seam
│   ├── id/
│   │   └── attachment_id_generator.dart
│   ├── mappers/
│   │   └── media_row_mappers.dart
│   ├── repositories/
│   │   ├── sqlite_attachment_repository.dart
│   │   ├── sqlite_cache_repository.dart
│   │   ├── sqlite_media_repository.dart   (aggregate impl)
│   │   ├── sqlite_preview_repository.dart
│   │   ├── sqlite_thumbnail_repository.dart
│   │   ├── sqlite_transfer_repository.dart
│   │   └── sqlite_voice_repository.dart
│   └── wire/
│       └── attachment_wire_codec.dart      Media envelope codec (v1)
├── images/                     Image metadata probing (pure Dart)
│   └── image_metadata_parser.dart
├── presentation/
│   └── media_providers.dart    Riverpod provider graph (no widgets)
├── preview/                    Preview + probing (domain)
│   ├── media_metadata_parser.dart   dispatch + MediaProbeResult
│   ├── media_preview.dart
│   └── preview_repository.dart
├── storage/
│   ├── attachment_store.dart   File organization + atomic writes
│   └── storage_statistics.dart
├── thumbnail/
│   ├── thumbnail.dart
│   ├── thumbnail_generator.dart   ThumbnailGenerator interface + PNG generator
│   └── thumbnail_repository.dart
├── transfer/                   Transfer engine (domain)
│   ├── chunk_scheduler.dart    Chunk pacing, retry, throttle
│   ├── transfer_bitmap.dart    Chunk bitmap (acked-set, ops)
│   ├── transfer_chunk.dart
│   ├── transfer_engine.dart    Session lifecycle + inbound handling
│   ├── transfer_repository.dart
│   ├── transfer_session.dart
│   ├── transfer_state.dart
│   └── transfer_statistics.dart
├── validation/
│   ├── media_validator.dart   Validation rules engine
│   └── validation_result.dart
├── voice/                      Voice notes (domain)
│   ├── voice_player.dart       Playback seam (no implementation in phase 9)
│   ├── voice_recorder.dart     Recorder seam + RecordingSession
│   ├── voice_recording.dart
│   ├── voice_repository.dart
│   └── waveform.dart
└── videos/                     Video metadata probing
    └── video_metadata_parser.dart
```

## Conventions

- **Domain** folders (attachments, transfer, cache, compression, preview,
  thumbnail, validation, voice, images, videos, documents) contain zero I/O:
  no `dart:io`, no drift, no DTN imports.
- **Data** folders implement every repository contract and own all I/O
  (`dart:io`, Drift, DTN). Only mappers and wire codecs may convert between
  row / wire and domain shapes.
- **Presentation** holds only providers; providers wire domain + data and
  expose `Stream`/`Future` APIs for controllers that arrive in Phase 10.
- Tests mirror the tree under `test/features/media/`.