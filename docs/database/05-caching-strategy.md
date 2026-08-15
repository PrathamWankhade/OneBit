# Caching Strategy

## Principle

**Read-through, never write-through.** SQLite is the only source of truth.
Caches are a performance layer over hot reads; every write path invalidates
the affected entries explicitly. Caches must never serve stale data after a
write — invalidation is synchronous with the write.

## Design

A single generic `MemoryCache<K, V>` (LRU, bounded capacity, optional TTL,
manual invalidation) backs typed wrappers:

| Cache | Key | Value | TTL | Invalidated by |
|---|---|---|---|---|
| `IdentityCache` | node id | `IdentityRow` | none (single row, tiny) | identity writes |
| `TrustCache` | node id | `TrustedNodeRow` | 30 s | trust writes |
| `ChannelCache` | channel id | `ChannelRow` | 30 s | channel writes |
| `NeighborCache` | node id | `NeighborRow` | 10 s (volatile) | neighbor writes |
| `RouteCache` | destination | `RouteRow` | 30 s | route writes |
| `SettingsCache` | key | value string | none | settings writes |

- Channel lists and message timelines are **not cached** — they are
  streamed (`watch`) directly from SQLite; caching streams would fight
  invalidation and double memory.
- Misses: single-flight per key (a concurrent miss awaits the in-flight
  load) to avoid stampede on cache-warm boot.
- Capacity: bounded (default 128 entries) so mesh-scale caches stay small.

## Invalidation

Repositories own cache policy:

```
insertMessage()  → cache.invalidateChannels(channelId)   // unread counts, last message
deleteChannel()  → cache.invalidateChannel(channelId)    // + cascade clears in DB
setSettings()    → cache.invalidateSettings(key)
```

Drift's change tracking could auto-invalidate, but explicit invalidation is
deterministic, testable, and independent of watch subscriptions.

## Why not cache the watch streams

`watch` queries already give near-real-time updates with zero invalidation
code. Doubling them through a cache adds staleness risk. Caches serve only the
hot, frequently-read single-row paths (identity banner, channel row, route
next-hop, neighbor presence) that would otherwise hit disk per frame/scan.
