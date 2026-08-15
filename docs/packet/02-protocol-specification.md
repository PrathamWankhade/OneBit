# Packet Protocol Specification — Phase 6

This document is the contract. Every rule below maps to a validation rule
code and a dedicated test. Byte encoding lives in `04-binary-format.md`;
the field inventory in `03-header-layout.md`.

## Versioning

Three version fields open every frame so a packet is never silently
misread:

| Field | Width | Meaning |
| --- | --- | --- |
| `transportVersion` | 4 bits | Wire format. A non-matching value means "unrecognisable bytes" — always dropped. |
| `versionMajor` | 1 byte | Protocol semantics. A mismatch means "understandable bytes, unknown meaning". |
| `versionRevision` | 1 byte | Backwards-compatible delta. Tolerated in both directions. |

Rules:

1. `transportVersion` must equal the decoder's. Any deviation is
   `UnsupportedPacketVersion`; no fallback guessing.
2. `versionMajor` mismatch: the frame is still parseable but its meaning is
   uncertain. Deliver only when `compatibleForwardCompatible` (which the
   sending node set — marked as `forwardCompatibleUnknown`), otherwise drop.
3. `versionRevision` newer than ours: accept and deliver with a
   `revisionNewer` marker. Older: accept (we are ahead) and deliver with
   `revisionOlder` marker.
4. A decoder never reads fields it does not know; trailing bytes after the
   declared payload length are rejected, never skipped.

### Compatibility flags (1 byte)

| Bit | Flag | Effect |
| --- | --- | --- |
| 0 | `compatibleForward` | Sender accepts our reply in an older version. |
| 1 | `compatibleDegrade` | Sender lets a receiver degrade the payload (e.g. strip compression). |
| 2 | `compatibleForwardUnknownFlags` | Sender forwards frames whose flags the sender does not know. |
| 3–7 | reserved | Must be 0, else route-through only: forwarded, rejected if `compat` unset. |

## Packet identity

- Global identity is `(source, packetId)`.
- `source` is the identity node id (or device address until the adapter
  mapping swap). Relayers never change it.
- `packetId` = `sequence` (u32) as in `MeshPacket.packetId` =
  `'$source:$sequence'` — identical to the existing mesh dedup id.
- A source increments `sequence` by 1 for every *logical* packet.
  All fragments of one packet share the same `sequence`.

## Packet types (1 byte)

| Code | Type | Use |
| --- | --- | --- |
| 0 | `message` | Application payload; what the UI produces. |
| 1 | `acknowledgement` | A visible acknowledgement of an earlier message. |
| 2 | `single` | Reserved for a future single-hop fast path. |
| 3 | `relay` | Store-and-forward relay frame (Phase 7); defined now for layout stability. |
| 4 | `control` | Protocol control. Never trimmed, never deferred. |
| 5 | `broadcast` | `destination` empty; every node is a target. |
| 6 | `discovery` | Route/server discovery, mirrors the mesh discovery control. |
| 7 | `error` | Error callback for an earlier packet. |

`message`, `control`, `relay`, `error` are actively used; the rest are
reserved semantic slots so future types do not rename the enum.

## Priorities (2 bits)

| Code | Priority | Use |
| --- | --- | --- |
| 0 | `critical` | System, route confirmation, emergency. |
| 1 | `high` | Messages, presence. |
| 2 | `normal` | Text/status traffic. |
| 3 | `low` | Background sync, media blobs. `background` is an alias. |

Priority orders queue entry and fragment scheduling; it does not change the
byte layout beyond 2 bits.

## Flags (1 byte) + reserved byte

| Bit | Flag | Meaning |
| --- | --- | --- |
| 0 | `encrypted` | Payload is ciphertext; parsed only for framing, never interpreted. |
| 1 | `compressed` | Payload is compressed. |
| 2 | `fragmented` | Fragment fields speak for this frame. |
| 3 | `ackRequested` | Sender wants an acknowledgement. |
| 4 | `relayAllowed` | Relays may forward beyond a known route / the sender grants it. |
| 5 | `broadcastFlag` | Present with `PacketType.broadcast`. |
| 6 | `retry` | This is a retransmission. |
| 7 | `duplicateFlag` | A relay detected a repeat of `(source, seq)`. |

The `reserved` payload byte is forwarded untouched; setting any reserved
bit marks the frame `compatibleForwardUnknownFlags` — forwarded rather
than interpreted.

## Fragmentation / reassembly

Fields: `sequence` (parent's), `fragmentId` (u16, per-run random seed),
`fragmentIndex` (u16), `fragmentCount` (u16).

- Group key is `(source, packetId, fragmentId)` — not seq alone — so two
  independent fragment runs with the same sequence never collide.
- A non-fragmented packet has `fragmentCount == fragmentIndex == 1`.
- Rules: `0 <= fragmentIndex < fragmentCount`, `fragmentCount >= 1`,
  `fragmentCount <= maxFragments` (256). Payload per fragment ≤ MTU-born
  `fragmentSize`.
- Reassembly: buffer until every index present, then emit exactly one
  ordered packet. Timeout (30 s) drops the partial set; overlaps are never
  double-written; duplicates never double-deliver.

## Compression

- `compressed == 1` means the payload bytes that follow are compressed;
  header, CRC and signature are not.
- Compressor is an injectable strategy. Ships `none`; `fast` optional and
  a `future` (streaming) reserved. A payload under
  `compressionThreshold` (64 B) is never compressed.
- Compression happens before validation/fragmentation; reassembly and
  validation operate on compressed bytes so the layers stay decoupled.

## Authentication and replay

- Header carries `signatureLength` + `signature`. Replay protection is
  composed from the header fields that already exist — `(source, sequence,
  createdAtEpochSeconds)` — which a real signer binds into the signature.
  No extra nonce byte is needed, and a replayed packet is rejected by the
  verifier, never delivered twice.
- `Authenticator` is an **interface** only this version ships a
  `NoopAuthenticator`. Signing and verification are pure header/payload
  transformations so a real signer can land later without a format change.
- The verifier rejects a `(source, sequence, createdAtEpochSeconds)` tuple
  it has already accepted (interface contract; enforcement by the future
  implementation).
- When `authenticated` flag is set, rule 12 requires `signatureLength > 0`.

## Payload

`PacketPayload` — `type` (`binary` | `utf8` | `json` | `encrypted` |
`compressed` | `attachmentMetadata`), `bytes`, optional
`uncompressedSize` when compressed. Payload length is a u32 in the header;
the decoder consumes exactly that many bytes and rejects trailing bytes.

## Acknowledgements

`PacketType.acknowledgement` embeds the acked `(source, sequence)` and a
status code. Produced when `ackRequested`; recorded by the engine as
attestations. Packet-layer acknowledgement is a suggestion, not BLE-level
reliability — mesh links remain unacknowledged.

## Error handling

Failures surface as `Result<Packet>` / `Err(Failure)` with typed failures
(`PacketValidationFailure`, `PacketReassemblyFailure`,
`PacketSerializationFailure`, `UnsupportedPacketVersion`). Never throws;
logs once at boundary creation.

## Validation rules

| # | Rule | Boundary |
| --- | --- | --- |
| 1 | `versionTransportSupported` | transport matches decoder. |
| 2 | `versionTransportRejected` | dropped as `Unsupported`. |
| 3 | `headerTrailingByte` | no bytes after declared payload. |
| 4 | `payloadLengthBounds` | payload ≤ `maxPayloadOnWire` and within frame budget. |
| 5 | `crc32Valid` | CRC over the whole frame equals the carried CRC. |
| 6 | `typeKnown` | in the known set. |
| 7 | `priorityInRange` | 0..3. |
| 8 | `flagsConsistent` | `encrypted`/`compressed` imply payload present. |
| 9 | `fragmentIndexCovered` | `0 <= index < count`. |
| 10 | `fragmentCountAllowed` | `1 <= count <= maxFragments`. |
| 11 | `sequenceSane` | a non-fragmented repeated `(source, seq)` is loop (drop). |
| 12 | `signaturePresent` | `authenticated ⇒ signatureLength > 0`. |
| 13 | `signatureValid` | verifier ok (no-op when not authenticated). |
| 14 | `destinationResolvable` | accepted by the resolver (reserved). |

## Configuration defaults

| Constant | Default |
| --- | --- |
| `transportVersion` | 1 |
| `versionMajor` | 1 |
| `versionRevision` | 0 |
| `crcWidthBits` | 32 |
| `headerFixedBytes` | 28 |
| `maxPayloadLength` | 65536 |
| `maxFragments` | 256 |
| `compressionThreshold` | 64 |
| `reassemblyTimeout` | 30 s |
| `maxConcurrentAssemblies` | 32 |
| `maxQueuedPackets` | 512 |