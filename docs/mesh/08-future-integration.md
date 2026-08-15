# Future Integration

This phase is deliberately a closed networking surface. Later phases plug
in *without architectural changes*:

## Packet Protocol (Phase 6)

- `MeshPacket` already carries the wire-relevant header: `packetId`
  (`source:sequence`), source, destination, TTL, hop count, path, control
  kind, opaque `payload`.
- A codec adds `MeshPacket.encode()/decode()` in `data/`; the engine only
  ever sees decoded objects. GATT constants (`mesh_gatt_constants.dart`)
  define the service/characteristic UUIDs the adapter writes to; the
  packet phase replaces the placeholder payload framing.
- Node ids migrate from device addresses to identity-derived ids by
  swapping the id mapping in `BluetoothMeshTransportAdapter` — no engine
  change.

## Store-and-Forward (Phase 7)

- `RelayQueue` is the extension point: today `flush()` drains immediately;
  later a persistent queue drains when `NeighborTable` re-observes the
  destination. `RelayEngine.ingest` API is unchanged.

## Messaging (Phase 8+)

- `MeshEngine.send(destination, payload)` and `DeliverUp` events are the
  whole contract the messaging layer needs. It produces/consumes opaque
  payload bytes; routing, relaying, dedup and TTL stay where they are.
- `MeshCapability.storeForward` and `MeshTrustStatus` fields exist now so
  the app layer can gate participation later without schema changes.

## Encryption

- Encryption is a payload transformation between the messaging layer and
  `send()`/`DeliverUp`; the engine never inspects payload contents.

## Battery / lifecycle

- The engine is started lazily by `MeshService` (provider-scoped) and
  reacts to radio state; an eager always-on start is a one-line provider
  change if product decisions require background mesh presence.
