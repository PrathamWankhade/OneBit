# 13 — Testing

All suites run under `flutter test`; tests are pure Dart/`dart:io` where
possible. Support lives in `test/features/media/support/media_test_support.dart`:
in-memory Drift database, temp-file `AttachmentStore`, fake DTN
(ack-immediate or delayed), and deterministic clock.

## Test matrix

| Suite | Covers |
| --- | --- |
| `transfer_test.dart` | start/announce, chunk pump, ack handling, completion, pause, cancel, retry, two-node flow |
| `chunk_test.dart` | geometry, bitmap ops, ordering, out-of-order reassembly, duplicate drop, nack requeue |
| `resume_test.dart` | pause→resume, process-restart restore from bitmap, receiver-driven `AR` refill, partial temp file reuse |
| `large_file_test.dart` | 8 MiB+ file over small chunk size, bounded peak memory, single-pass hashing |
| `stress_test.dart` | many concurrent sessions, packet drops, nacks, TTL expiry, crash mid-session |
| `compression_test.dart` | zlib compress/decompress round trip, threshold (no-op below gain), profiles, statistics |
| `thumbnail_test.dart` | lazy generation, single-flight, cache hits, regeneration |
| `voice_test.dart` | recording lifecycle (fake recorder), waveform bucketing, storage, transfer support |
| `cache_test.dart` | memory LRU eviction order, disk cache persist, thumbnail cache, cleaner budget, statistics |
| `validation_test.dart` | size/type/extension/checksum/corruption/duplicate/storage rules |
| `wire_codec_test.dart` | encode/decode round trips for all 7 envelope kinds, budget guard, malformed payloads |
| `probe_test.dart` | PNG/JPEG/GIF/WEBP dimensions, MP4/MKV/MOV duration, WAV/MP3 duration, PDF pages, unknown files |

## Fakes

- `FakeDtnRepository` — in-memory store + `observeDelivered` queue with
  configurable delay/failure; can simulate packet loss per envelope.
- `FakeMediaTransport` — loopback pair: two `AttachmentManager`s wired
  through an in-memory mesh with drop/pause knobs (used by two-node tests).
- `MemoryMediaDb` — `OneBitDatabase(NativeDatabase.memory())` plus
  `MediaDao`.

## CI expectations

- `dart analyze` clean (zero warnings).
- All suites green on `flutter test`.
- `schema_snapshot_test` green against regenerated `onebit_v5.sql`.