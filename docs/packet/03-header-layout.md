# Header Layout — Phase 6

The header is a fixed 28-byte prefix followed by two variable-length UTF-8
node ids, then the payload section and the CRC trailer. All multi-byte
integers are **big-endian**. This is the authoritative field inventory;
wire-level worked examples are in `04-binary-format.md`.

```
┌─ fixed header (28 bytes) ──────────────────────────────────────────────────┐
│ 0    transportVersion (4) | reservedNibble (4)                              │
│ 1    versionMajor                                                           │
│ 2    versionRevision                                                        │
│ 3    compatibilityFlags                                                     │
│ 4    packetType                                                            │
│ 5    priority (2) | reservedBits (6)                                        │
│ 6    flags                                                                 │
│ 7    reservedFlags                                                         │
│ 8    ttl                                                                   │
│ 9    hopCount                                                              │
│ 10–13 sequence (u32)                                                       │
│ 14–17 createdAtEpochSeconds (u32)                                          │
│ 18–19 fragmentId (u16)                                                     │
│ 20–21 fragmentIndex (u16)                                                  │
│ 22–23 fragmentCount (u16)                                                  │
│ 24–25 sourceLength (u16)                                                   │
│ 26–27 destinationLength (u16)                                              │
├─ variable ─────────────────────────────────────────────────────────────────┤
│ sourceNode: UTF-8, exactly sourceLength bytes                              │
│ destinationNode: UTF-8, exactly destinationLength bytes (empty = broadcast)│
│ payloadLength (u32)                                                        │
│ payload (payloadLength bytes)                                              │
│ signatureLength (u16)                                                      │
│ signature (signatureLength bytes)                                          │
│ crc32 (u32) — CRC-32/IEEE over bytes [0 .. signature end)                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Field-by-field

| Field | Size | Meaning |
| --- | --- | --- |
| `transportVersion` | 4 bits | Wire format. Fixed by the decoder; mismatches are dropped, never guessed. |
| `reservedNibble` | 4 bits | 0 in v1. Set → treated as forward-compatible unknown. |
| `versionMajor` | 1 B | Protocol semantics; see compat rules in the spec. |
| `versionRevision` | 1 B | Backwards-compatible delta; tolerated both ways. |
| `compatibilityFlags` | 1 B | The compat nibbles from spec §versioning. |
| `packetType` | 1 B | `PacketType` code (message/ack/…/error). |
| `priority` | 2 bits | Queue ordering hint. |
| `reservedPriorityBits` | 6 bits | 0 in v1. |
| `flags` | 1 B | The 8 flags (encrypted … duplicateFlag). |
| `reservedFlags` | 1 B | 0 in v1; set bits mark frame as future-compat. |
| `ttl` | 1 B | Remaining relay hops; 0 → not forwardable. |
| `hopCount` | 1 B | Relays applied so far. |
| `sequence` | u32 | Source-local id. The mesh dedup id `source:id` uses this. |
| `createdAtEpochSeconds` | u32 | Unix seconds at creation; informational (survives till 2106). |
| `fragmentId` | u16 | Per-run random seed; disambiguates re-runs of the same sequence. |
| `fragmentIndex` | u16 | This fragment's index. |
| `fragmentCount` | u16 | Total fragments; group size. |
| `payloadLength` | u32 | Exact payload byte count; decoder consumes exactly this many. |
| `signatureLength` | u16 | Signature length; 0 = unsigned. |
| `crc32` | u32 | Frame integrity. |

The node id strings use **UTF-8** length-prefixed by u16 byte counts — this
is deliberately different from the mesh placeholder codec (which used
u16-length + UTF-16 codeunits); UTF-8 halves the overhead for ASCII ids
and matches how the future `NodeId` is rendered.

## Rules enforced by the decoder

1. Reading the fixed header requires at most 28 bytes; every field is
   bounds-checked before the next read (mirrors the placeholder's
   guard-and-`RangeError` strategy, surfaced as
   `PacketValidationFailure.malformed`).
2. `destinationLength == 0` ⇒ broadcast (`PacketType.broadcast`).
3. `fragmentIndex`/`fragmentCount`: `0 <= index < count` and
   `count >= 1`. A non-fragmented packet carries `count == index == 1`.
4. `payloadLength <= maxPayloadOnWire` (64 KiB); the decoder rejects any
   remaining bytes after consuming exactly `payloadLength` + signature
   (+ trailing CRC check).
5. When `fragmented` is clear but `fragmentCount > 1`, rule
   `fragmentCountAllowed` rejects the frame.
6. CRC-32 covers every byte from index 0 through the end of the signature,
   **before** the 4-byte CRC itself. Verification is the *first* semantic
   check (spec rule 5).

## Reserved-slot behaviour

Any field documented as "0 in v1" that arrives set is treated as
*forward-compatible unknown*: the frame is forwarded verbatim, its flags
block preserved, and never interpreted by this version. This is what makes
the header additive-safe: a 2-year-old phone forwards a packet it does not
fully understand.

## Header budget

For an ASCII node id of 8 bytes and empty signature and a fragment header:

| Component | Bytes |
| --- | --- |
| fixed header | 28 |
| source + destination (8+8) | 16 |
| payloadLength | 4 |
| signatureLength | 2 |
| crc32 | 4 |
| **minimal full frame (no payload)** | **54** |