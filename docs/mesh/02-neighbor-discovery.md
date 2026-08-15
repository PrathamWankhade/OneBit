# Neighbor Discovery

## Source of truth

The neighbor table is the only view of *who is around us*. It is fed by the
Bluetooth transport through `MeshTransportEvent`s:

- `NeighborAdvertisementSeen` — a scan result (advertisement) from `nodeId`
  at `rssiDb`.
- `LinkStateChanged` — a connection to `nodeId` entered/left a state.
- `RssiObserved` — connected-link RSSI readings.
- `ScanStateChanged` / `RadioStateChanged` — engine awareness.

Node ids arrive from the transport; in Phase 5 the adapter projects the
BLE device address as the node id (identity-derived ids land with the
packet protocol phase).

## Discovery pipeline

`NeighborDiscoveryEngine` → `NeighborTable`:

1. **Upsert** — every advertisement/observation creates or refreshes the
   entry: RSSI goes through an EMA smoother, `lastSeen` updates, `firstSeen`
   is preserved.
2. **Connection tracking** — link events advance `connectionState`
   (`advertising → connecting → connected → disconnected`).
3. **Freshness** — entries older than `neighborTtl` without an observation
   are removed during the engine sweep; a removal is announced so routing
   and topology can react immediately (self healing).
4. **Distance estimation** — log-distance path loss model:

```
distance = 10^((txPowerDb - smoothedRssiDb) / (10 * pathLossExponent))
```

   with `txPowerDb = -59` (typical smartphone BLE), `pathLossExponent = 2.5`,
   clamped to `[0.5 m, 200 m]`. Distance is an estimate for diagnostics and
   topology, never an authority for routing decisions.

5. **Capabilities & trust** — capabilities (`relay`, `router`,
   `storeForward`) are per-entry sets; trust is a tri-state
   (`unknown / trusted / blocked`) reserved for the identity phase. The
   engine exposes `setTrust(nodeId, status)` so future layers can gate
   relaying.

## Table semantics

- `upsert` — idempotent; returns `true` when the entry changed.
- `touch` — RSSI update path (no identity change).
- `expire(now)` — removes stale entries, returns the removed ids.
- `byId`, `all` — constant-time reads.
- `setConnectionState` — link event path.
- `snapshot()` — immutable copy for streams/UI.

## Expiry policy

- `neighborTtl` default: 90 s (matches the transport's advertisement
  cadence).
- Sweep runs on the engine tick (default 5 s); fast enough to keep churn
  visible without waking the radio.
