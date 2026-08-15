# OneBit Packet — Phase 6: Packet Protocol Engine

## Scope

This phase builds the **universal framing layer** between an application
message and the mesh wire:

- Versioned, self-describing, big-endian wire format
- Immutable `Packet` domain model + full field inventory
- Validation with named, tested rules
- Fragmentation and out-of-order reassembly (end-to-end, MTU-aware)
- Payload compression as an injectable strategy (threshold-ruled)
- A signer/verify **interface** + replay metadata (no crypto this phase)
- CRC-32 frame integrity
- Developer engineering screens and a CLI protocol simulator
- Vendor/headless tests mirroring `lib/` 1:1

## Out of scope

Messaging/chat UI, voice, media transfer, store-and-forward (Phase 7),
encryption/Double Ratchet, any mesh-engine change. This feature wraps a
message into bytes and hands them to the existing
`MeshRepository.send(destination, payload)`; on the return trip it parses
`DeliverUp` payload bytes and yields back the message.

## Documents

| Doc | Content |
| --- | --- |
| `01-architecture.md` | Position in the stack, principles, layering, performance goals |
| `02-protocol-specification.md` | The contract: versioning, types, priorities, flags, rules, constants |
| `03-header-layout.md` | Field-by-field header, budget, reserved behaviour |
| `04-binary-format.md` | Byte-level encoding, endianness, strictness, worked example |
| `05-diagrams.md` | Component/sequence/state diagrams |
| `06-folder-structure.md` | Folder tree, class map, purity rules |

## Dependencies

- `core/result` (Result/Failure — no throwing across boundaries)
- `core/errors` (typed failures)
- `core/logger` (AppLogger, LogTags)
- `features/mesh/domain` (MeshRepository contract, DeliverUp)
- `features/identity/domain` (NodeId for source/destination once the
  adapter mapping swap lands)

## Verify

```
dart format .
flutter analyze --no-fatal-infos     # must be zero issues
flutter test test/features/packet    # unit + integration
dart run tool/packet_simulation.dart # CLI scenario runner (exit 0)
```