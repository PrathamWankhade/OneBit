# Packet Architecture — Phase 6

## Position in the stack

The packet protocol is the **universal framing layer** between application
logic and the mesh network. It answers one question: *how does a mesh node
turn a high-level message into bytes that survive a BLE multi-hop relay and
come back out complete, ordered, validated and forward-compatible?*

```
app layers            PacketEngine (features/packet)          mesh layer
message ───────────►  PacketFactory → serialize ──────────►  MeshRepository.send
   ▲                      │  ▲       │   ▲                        │   ▲
   │                      │  │       ▼   │                        │   │
   └────────────────── parsed Packet  worker                    bytes out/in
                                                                MeshTransport
```

The mesh layer already handles routing, relaying, TTL and duplicate
prevention on the `MeshPacket` value object. The packet phase provides the
wire codec the mesh `data/` layer was always going to receive
(`docs/mesh/08-future-integration.md`): it replaces the placeholder
payload framing in `lib/features/mesh/data/mesh_packet_codec.dart` without
any mesh architectural change. `MeshPacket.payload` stops being opaque
application bytes and becomes the serialized `Packet` this feature builds.

## Non-goals

- **No messaging UI.** No chat, voice, media, or file-picker components.
- **No store-and-forward.** Phase 7 owns that via `RelayQueue`.
- **No encryption implementation.** Phase 6 defines the `signature` header
  field, the `Authenticator` interface, and replay-protection metadata —
  not Double Ratchet or any cipher. Encryption remains a payload
  transformation between the messaging layer and `send()`/`DeliverUp`.
- **No mesh changes.** The engine consumes `MeshPacket`+opaque payload; the
  packet codec is the only thing that changes on the mesh side.

## Design principles

1. **Bounded on-air.** BLE MTUs are small and radios are battery-bound. The
   mandatory header is fixed-format and big-endian; optional fields appear
   only when a forward-compatibility flag asks for them.
2. **Versioned and self-describing.** Every wire packet opens with a
   version nibble and version/revision bytes, so a decoder can always tell
   which format produced it — the number one requirement for a protocol
   that lives on phones for years.
3. **Authenticated-by-design.** The header always reserves the `signature`
   field (variable length), so a future signer fits without a format bump.
   An `Authenticator` interface defines the verification contract; replay
   protection is carried as header metadata so a replayed packet is
   rejected, never double-delivered.
4. **Immutable value types.** `Packet` and all components are immutable.
   Mutation is a deliberate restructure that happens only at the factory
   boundaries (fragment, reassemble, sign, compress).
5. **Fragment-reassembly is end-to-end.** The engine fragments a *message*
   packet into *wire* packets whenever serialized size exceeds the
   negotiated MTU, and reassembles out-of-order arrivals on a complete.
   The mesh layer never sees fragmentation metadata.
6. **Compression is a transformer.** A flag turns payload compression on;
   the compressor is an injectable strategy (`none`, `fast`, `future`
   algorithms reserved). Only payloads above a threshold are compressed,
   and validation/reassembly operate on compressed bytes so layers stay
   decoupled.
7. **Every rule is named and tested.** Each validation rule maps to a
   named constant and a dedicated test at its exact boundary (see
   `02-protocol-specification.md`).

## Layering inside the feature

```
presentation/   packet_providers · packet_controllers · packet_dev_screen
                     │  depends on contracts
domain/         Packet · PacketHeader · PacketPayload · PacketType ·
                PacketPriority · PacketFlag · PacketVersion · PacketId ·
                fragment/reassembly models · packet_repository (contract)
                     │
data/            serialize · deserialize · crc · compression strategies ·
                packet_engine · packet_repository_impl
```

Everything under `domain/` and `data/` (except the repository) is pure
Dart with zero Flutter imports — matching the mesh layer's rule that the
entire networking core is headless-testable. Only `presentation/`
touches Riverpod/Flutter.

## Lifecycles and state

- `PacketEngine` is an **injectable service** owned by the mesh repository's
  provider graph. It holds no wire state beyond the bounded reassembly
  cache; it never calls the mesh layer recursively.
- Reassembly buffers expire after `reassemblyTimeout` (default 30s) and are
  capped by `maxConcurrentAssemblies` (default 32). A partial set that
  times out is dropped entirely — never delivered, never merged, and its
  slot freed.
- The engine is stateless w.r.t. mesh topology: it feeds bytes in, emits
  packets out; routing clarity never depends on packet-layer state.

## Integration with the mesh layer

`MeshRepository.send(destination, payload)` (mesh_repository.dart:55) takes
opaque payload bytes today. With the packet layer: an application message
→ `PacketFactory.create` → `PacketSerializer.toBytes` → those bytes become
the mesh `send()` payload. On arrival, the mesh `DeliverUp` event yields
the payload bytes; the packet layer parses them back into a `Packet`, runs
validation, reassembly and authentication, and hands the logical message to
the higher layer. Fragmentation and compression markers live *inside* the
wire packet, so the mesh engine never interprets them.

Identity migration happens as documented: node ids move from BLE device
addresses to identity-derived `NodeId`s by swapping the id mapping in
`BluetoothMeshTransportAdapter` — no engine change.

## Scalability

| Property | Bound |
| --- | --- |
| Header parsing | O(fields), each field O(1) |
| Serialization | O(payload + header) |
| Bounded memory | reassembly cache ≤ 32 partial sets, each ≤ MTU×count |
| Dedup/bookkeeping | idempotent; reassembly keys are (source, packetId) |

## Performance goals (verify in `tool/packet_benchmark.dart`)

| Case | Goal |
| --- | --- |
| Serialize 1 KiB payload | < 1 ms |
| Validate + parse 1 KiB payload | < 1 ms |
| Fragment 100 KiB into MTU 100 | < 2 ms |
| Reassemble 64 fragment (in order) | < 2 ms |
| CRC32 over 1 KiB | < 0.2 ms |
| Wire overhead for a typical send | ≤ 54 bytes frame (28 fixed + ids + trailer) |