# Folder Structure — Phase 6

```
lib/features/packet/
├── domain/                      # pure Dart models + contracts
│   ├── packet.dart              # Packet (logical message carrier)
│   ├── packet_header.dart       # PacketHeader value
│   ├── packet_payload.dart      # PacketPayload (type, bytes, size)
│   ├── packet_type.dart         # PacketType enum
│   ├── packet_priority.dart     # PacketPriority enum
│   ├── packet_flag.dart         # PacketFlag enum (wire bits)
│   ├── packet_version.dart      # PacketVersion value
│   ├── packet_id.dart           # (source, sequence) identity
│   ├── packet_compressor.dart   # Compressor contract (none/future)
│   ├── packet_reassembly_state.dart  # ReassemblyState + outcome
│   ├── packet_reassembly_result.dart # complete vs partial vs dropped
│   ├── packet_exception.dart    # typed packet failures (Failure)
│   └── packet_repository.dart   # PacketRepository contract
├── serialization/
│   ├── packet_serializer.dart   # Packet ↔ bytes (writer/reader)
│   └── packet_byte_writer.dart  # reusable big-endian writer
├── fragmentation/
│   ├── packet_fragmenter.dart   # split messages into wire frames
│   └── packet_reassembler.dart  # merge frames back into a Packet
├── compression/
│   └── packet_compression_strategies.dart  # none / fast / future
├── validation/
│   └── packet_validator.dart    # rule checks (1..14)
├── authentication/
│   └── packet_authenticator.dart  # sign/verify interface + Noop
├── reassembly/                  # engine-owned assembly cache
│   └── reassembly_engine.dart
├── header/
│   └── wire_header_codec.dart   # layout-aware header encoder/decoder
├── payload/
│   └── payload_codec.dart       # payload type tagging + compression hook
├── crc/
│   └── crc32.dart               # CRC-32/IEEE
├── version/
│   └── packet_version_manager.dart # compat policy + version tokens
├── engine/
│   └── packet_engine.dart       # composition root: send/parse pipeline
├── data/
│   └── packet_repository_impl.dart
└── presentation/
    ├── packet_providers.dart
    ├── packet_controllers.dart
    └── packet_dev_screen.dart   # /packet-debug engineering panels
```

`tool/packet_simulation.dart` — CLI protocol runner (single/100 packets,
fragmented, corrupted, loss, duplicate, version mismatch, timeout),
mirroring the mesh scenario runner style. `tool/packet_benchmark.dart` —
the performance table in `01-architecture.md` checked end-to-end.

## Class map

```
PacketRepository (contract) ← PacketRepositoryImpl → PacketEngine
PacketEngine ── owns → PacketFactory, PacketValidator, PacketSerializer,
                       PacketFragmenter, ReassemblyEngine,
                       PacketCompressor (strategy), PacketAuthenticator
PacketFactory ── uses → PacketSerializer, PacketFragmenter, PacketChecksum
PacketSerializer ── uses → WirePacketCodec, Crc32
ReassemblyEngine ── key on → PacketId + fragmentId
PacketAuthenticator (interface) ← NoopAuthenticator
```

## Domain purity

Everything under `domain/`, `serialization/`, `fragmentation/`,
`compression/`, `validation/`, `authentication/`, `reassembly/`,
`header/`, `payload/`, `crc/`, `version/`, `engine/` is pure Dart with
zero Flutter imports — matching the mesh layer's rule, so the whole packet
core is headless-testable and carries into the C++/FFI migration. Only
`data/packet_repository_impl.dart` and `presentation/` bridge to
Flutter/Riverpod.

## Module responsibilities

| Module | Responsibility |
| --- | --- |
| `domain/packet_id.dart` | Identity = `(source, sequence)`; `==`/`hash`, group key helper for reassembly |
| `domain/packet_header.dart` | Immutable header value (all fields from the spec) |
| `header/wire_packet_codec.dart` | Field-accurate header encode/decode with bounds checks |
| `payload/payload_codec.dart` | Payload type tagging, utf8/json hints, attachment metadata stub |
| `crc/crc32.dart` | Lookup-table CRC-32/IEEE, single function, no state |
| `serialization/` | Whole-frame encode/decode; never throws — `Result<Packet>` |
| `validation/` | Named rules 1–14; first failure returned with rule id |
| `fragmentation/` | Split by `fragmentSize`, header per fragment, invariant checks |
| `compression/` | Strategy `none` (+ `fast`/`future` reserved), threshold rule |
| `authentication/` | Sign/verify contract; `NoopAuthenticator` for headless tests |
| `version/` | Transport/match policy, compatibility matrix (spec §2) |
| `engine/` | Pipeline wiring: parse → validate → reassemble → verify → emit |