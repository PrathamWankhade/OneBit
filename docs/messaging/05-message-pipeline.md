# Message Pipeline — States and Transitions

## Producer view (node A)

```
compose → VALIDATE ──> (draft) ──> CREATED ──> QUEUED ──> WAITING (envelope queued)
   ──> ROUTING (transmit underway) ──> RELAYED (hop-by-hop) ──> DELIVERED (receipt)
   ──> VERIFIED (receipt verified) ──> READ (read receipt)
```

Failure edges (all persisted):

| From | To | Trigger |
| --- | --- | --- |
| any live state | FAILED | permanent DTN rejection / validation failure / cancel policy |
| any live state | EXPIRED | message TTL passed while undelivered |
| any state | DELETED | local user or system delete (soft; body erased, tombstone row) |

## Consumer view (node B)

```
inbound raw packet
  → parse wire envelope (codec)  → unparseable → drop+log (never crash)
  → duplicate check (messageId exists) → update only if a terminal state exists
  → insert message row (status delivered) → unread++ → lastActivity++
  → DeliveryReceipt → back to A
  → NotificationEvent(MessageReceived)
```

## Persistence boundaries

- `Message.status` column is the single source of truth; the engine writes
  it before returning from any transition.
- `MessageMetadata` records clientId/packetId/attemptCount so retries reuse
  the same packet id (idempotent DTN store).
- `Messages.timestamp + sequence + packet_order + status` encode the ordering
  key; `packetOrder` is written only on first arrival at each node.
- Drafts, receipts, reactions, pins, notifications are separate tables; every
  envelope that carries app data has a matching persisted row before any
  side effect (stream event, notification) fires.

## Envelope formats (wire codec)

| Envelope | Kind | Payload JSON |
| --- | --- | --- |
| message | `M` | `{v, kind:"M", mid, cid, sender, receiver?, type, body, seq, ts, replyTo?, edited, forwarded, starred?}` |
| delivery receipt | `R` | `{v, kind:"R", mid, node, at, meta?}` |
| read receipt | `R` | `{v, kind:"R", mid, node, at, read}` |
| typing | `T` | `{v, kind:"T", cid, node, state, ts}` |

Receipt envelopes, once processed, never mutate the recipient's timeline —
they only update receipt/status tables (dedup by receipt id).

## Throttles

- Typing: 1 envelope per transition + min interval (default 1s).
- Read receipts: 1 envelope per channel-mark-read batch.
- Delivery receipts: 1 per inbound message (no repeat on duplicate packets).