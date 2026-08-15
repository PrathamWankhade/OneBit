# ER Diagram & Relationships

Mermaid ER diagram of the 25-table schema.

```mermaid
erDiagram
    IDENTITY ||--o| TRUSTED_NODES : "is source of"
    TRUSTED_NODES {
        text node_id PK
        blob public_key
        text fingerprint
        text trust_status
        text verification_method
        int last_seen
        int rssi
        text nickname
        text metadata
    }
    NODE_PROFILES {
        text node_id PK
        blob public_key
        text fingerprint
        text display_name
        int first_seen
        int last_seen
        text metadata
    }
    CHANNELS ||--o{ MESSAGES : "contains"
    CHANNELS {
        text channel_id PK
        text type
        int unread_count
        int last_message_at
        int archived
        int pinned
        int muted
    }
    MESSAGES {
        text message_id PK
        text channel_id FK
        text sender
        text receiver
        int timestamp
        blob encrypted_payload
        text message_type
        text status
        text reply_to
        int edited
        int deleted
        int ttl
        text priority
        int version
    }
    MESSAGES ||--o{ ATTACHMENTS : "has"
    MESSAGES ||--o{ VOICE_NOTES : "has"
    MESSAGES ||--o{ DELIVERY_RECEIPTS : "tracked by"
    MESSAGES ||--o{ READ_RECEIPTS : "tracked by"
    PACKETS ||--o{ PACKET_FRAGMENTS : "split into"
    PACKETS {
        text packet_id PK
        text packet_type
        text source
        text destination
        int ttl
        int hop_count
        int fragment_count
        int crc
        int expires_at
        blob encrypted_payload
        text status
    }
    NEIGHBORS ||--o{ ROUTES : "is next hop for"
    ROUTES {
        text destination PK
        text next_hop FK
        int hop_count
        real quality
        int last_updated
        int expiration
    }
    SESSIONS ||--o{ SESSION_KEYS : "ratchets"
    SESSIONS {
        text session_id PK
        text node
        int expiration
        blob ratchet_state
        text state
    }
    CHANNELS ||--o{ TYPING_EVENTS : "emits"
    PACKETS ||--o{ RELAY_QUEUE : "queued for relay"
    PENDING_QUEUE { int queue_id PK, text entity_type, text entity_id, int priority, int attempts }
    RETRY_QUEUE { int retry_id PK, text entity_type, text entity_id, int attempts, int backoff_ms }
    SETTINGS { text key PK, text value }
    LOGS { int log_id PK, int timestamp, int level, text tag, text message }
    DIAGNOSTICS { int diagnostic_id PK, text category, text name, text value }
    DEVELOPER_EVENTS { int event_id PK, text name, text payload }
    STATISTICS { text name PK, text kind, real value, text string_value }
    APPLICATION_METADATA { text key PK, text value }
```

## Relationship rules

| Parent | Child | FK / delete rule |
|---|---|---|
| `channels` | `messages` | `message.channel_id` → `channels` **CASCADE** |
| `channels` | `typing_events` | `typing_events.channel_id` → `channels` **CASCADE** |
| `messages` | `attachments`, `voice_notes`, `delivery_receipts`, `read_receipts` | `*.message_id` → `messages` **CASCADE** |
| `packets` | `packet_fragments` | `packet_fragments.packet_id` → `packets` **CASCADE** |
| `packets` | `relay_queue` | `relay_queue.packet_id` → `packets` **CASCADE** |
| `sessions` | `session_keys` | `session_keys.session_id` → `sessions` **CASCADE** |
| `neighbors` | `routes` | `routes.next_hop` → `neighbors` (logical; enforced by app layer because routes may outlive pruned neighbors) |

Cascades keep orphan cleanup automatic — deleting a channel removes its
message tree; deleting a packet removes its fragments and relay entries.

## Self-references

- `messages.reply_to` → `messages.message_id` (logical, no FK — reply targets
  can be purged independently).
- `messages.sender` / `receiver`, `packets.source` / `destination`,
  `trusted_nodes.node_id`, `node_profiles.node_id` all reference the logical
  **node id** namespace (`NODE-XXXX-XXXX`), not a table — a node id is a
  global identifier, so no FK is declared.

## Indexes

See `02b-indexes.md`-equivalent section in each table file (`@TableIndex`).
Hot paths covered:

- `messages(channel_id, timestamp DESC)` — channel timelines (the hottest read).
- `messages(sender)`, `messages(status)` — search + queue processing.
- `packets(destination)`, `packets(source)`, `packets(expires_at)` — routing + expiry sweeps.
- `packet_fragments(packet_id, sequence)` — reassembly order.
- `routes(next_hop)`, `routes(quality DESC)` — best-next-hop selection.
- `neighbors(last_seen DESC)`, `neighbors(status)` — presence sweeps.
- `sessions(node)`, `session_keys(session_id, ratchet_step)` — ratchet walk.
- `logs(timestamp DESC)`, `logs(tag, level)` — log tails.
- `retry_queue(next_attempt_at)`, `relay_queue(state, enqueued_at)`, `pending_queue(priority, next_attempt_at)` — queue drains.
- `statistics(name, recorded_at)`.
