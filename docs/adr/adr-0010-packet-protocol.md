# ADR-0010 — Versioned, self-describing, end-to-end packet framing

Status: Accepted

## Context

Phase 6 must carry application messages over an arbitrary BLE mesh: routes
change, fragments interleave, nodes run different app versions, and a packet
may live on a device for years. Without an explicit wire contract the mesh
layer cannot distinguish a malformed frame, an old protocol, or a future
one. The phase also must stay replaceable-by-FFI later (see Phase 5's C++
migration note), so the layout must be pure Dart, deterministic, and
documented byte-by-byte.

## Decision

- A single `Packet` value object serializes to a big-endian, version-prefixed
  frame: fixed 28-byte header + two UTF-8 node ids + payload + optional
  signature + CRC-32/IEEE trailer.
- Versioning is tri-part and surfaced: transport (wire), major (semantics),
  revision (additive); plus compatibility flags on the sender side.
- Fragmentation is **end-to-end on the destination**: the packet layer
  fragments frames when serialization exceeds the negotiated MTU, and the
  receiving node reassembles by `(source, sequence, fragmentId)` with
  timeout/limits; the mesh engine keeps seeing opaque `MeshPacket.payload`.
- Compression and (future) signing are injectable strategy/interface
  boundaries around the same immutable header — no new wire version to
  enable them.
- Everything is `Result`-based, typed failures, no throws; malformed bytes
  are never half-parsed.

## Trade-offs

- A fixed 28-byte header costs bytes on tiny BLE frames; accepted because
  maintainability and cross-version safety outrank a few bytes.
- Reassembly adds O(fragments) memory per active session, capped (32) with a
  30 s timeout; accepted in exchange for MTU-independent messaging.
- Sending many tiny messages pays +32 bytes/frame (20 bytes ident field)
  vs an ad-hoc encoding; mitigated by compression threshold and ack batching.

## Consequences

- The mesh `data` layer can drop its placeholder codec and adopt the packet
  serializer as the payload framing implementation (`lib/features/packet`),
  without mesh engine changes (per `docs/mesh/08-future-integration.md`).
- Old phones forward unknown-flag packets rather than drop them (see header
  layout "reserved-slot behaviour"), giving forward compatibility.
- A later encryption phase slots behind `encrypted` + `Authenticator`
  without reformatting the header.
- The 30s reassembly timeout is a protocol constant: receivers that want a
  different value must agree via compat negotiation, never silently.