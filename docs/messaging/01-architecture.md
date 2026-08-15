# Messaging Architecture — OneBit Phase 8

Status: Phase 8 baseline. The messaging domain sits directly above the DTN
stack and below the (future) UI. It never touches Bluetooth, Mesh, Packet
Protocol or BLE APIs directly — it communicates only through repositories.

## 1. Problem statement

The stack below (Bluetooth transport → mesh routing → packet protocol → DTN)
is a *get, deliver, retry network*: it accepts envelopes addressed to node
ids and delivers them eventually. What it does not know is:

- What a *message* is (text vs system event vs receipt).
- How messages from two peers interleave into one conversation timeline.
- Which messages are still pending, delivered, read, or failed.
- How a half-typed draft survives app restarts.
- How the user finds an old message after weeks of history.
- How "someone is typing" is announced without flooding the mesh.

The Messaging Engine answers all of those questions. It is the only consumer
of the DTN repository, the only owner of message lifecycle, and the only
writer of message rows. Future UI code consumes providers and calls use
cases — it never sees packets or database rows.

## 2. Design goals

| Goal | Requirement | Mechanism |
|---|---|---|
| End-to-end delivery | Message survives disconnected hours | Every state persisted; DTN retries until ack or expiry |
| Offline-first sends | Send succeeds while the peer is unreachable | Envelope queued and parked; resumed when connectivity returns |
| Reliable ordering | Timeline is deterministic in sender order | Ordering engine + persisted ordering key |
| Private first | 1:1 channels now, groups later | Channel abstraction with per-channel recipient geometry |
| Receipts | Both ends see delivery/read state | Delivery + read receipt envelopes through the same DTN pipe |
| Drafts | Composing survives restarts | One persisted draft per channel |
| Search | Find one message in 100k+ | SQLite FTS index on local content |
| Lazy loading | No full-history scans | Cursor-based pagination (timestamp/sequence cursors) |
| UI-free | Zero Flutter imports in the domain | Pure-Dart contracts; Riverpod only at the provider seam |
| Scale | 100k+ messages, 10k+ channels | Indexed reads, capped pages, minimal memory residency |

## 3. Where the Messaging Engine sits

```
┌──────────────────────────────────────────────────────────────┐
│  UI (later phase)        consumes providers, calls use cases │
├──────────────────────────────────────────────────────────────┤
│  Messaging Engine (this phase)                               │
│  composer · outbox · inbound · ordering · receipts · typing  │
│  drafts · unread · notifications · search · history          │
├──────────────────────────────────────────────────────────────┤
│  DTN Engine (Phase 7)    store → schedule → deliver → ack    │
├──────────────────────────────────────────────────────────────┤
│  Packet Protocol (Phase 6)                                   │
├──────────────────────────────────────────────────────────────┤
│  Mesh Routing (Phase 5)                                      │
├──────────────────────────────────────────────────────────────┤
│  Bluetooth Transport (Phase 4)                               │
└──────────────────────────────────────────────────────────────┘
```

The engine holds **one seam** to the network — `DTNRepository`. Everything
outbound goes through `store()`, everything inbound arrives through
`observeDelivered()`. The messaging layer never references a Bluetooth API,
a mesh engine or a packet engine type.

## 4. Modules

| Module | Responsibility |
| --- | --- |
| `channels` | Channel model + settings, conversation listing, unread/last-activity, archive/mute/pin/rename/search/sort, pinned messages |
| `messages` | Message model, status/type vocabulary, timeline, edit/reply/forward/delete/star, ordering engine |
| `drafts` | Per-channel draft persistence + restore + deletion |
| `delivery` | Outbox: packet creation, DTN store, retry/resend/cancel, delivery status tracking |
| `receipts` | Delivery & read receipt generation, transport, storage, application |
| `history` | Cursor-based lazy pagination of a channel timeline |
| `composer` | Outgoing-message validation and preparation |
| `search` | FTS-backed keyword/date/type/unread/pinned search; node-name + channel search |
| `notifications` | Internal notification engine — no Android UI in this phase |
| `domain` | Models, repository contracts, use cases, failures |
| `data` | Sqlite/drift implementations, mappers, wire codec, DTN adapter |
| `presentation` | Riverpod providers (the future UI surface) |

## 5. Channel architecture

A **channel** groups messages around one conversation. One row in
`Channels`, one timeline in `Messages` per channel.

| ChannelType | Meaning | Supported now |
| --- | --- | --- |
| `private` | 1:1 between two node ids | Yes — first-class |
| `group` | Multi-recipient conversation | Declared; outbox fans out per recipient |
| `broadcast` | One-to-many announcement channel | Declared; restrictions enforced by future phase |
| `emergency` | Life-safety channel, high DTN priority | Declared; the delivery policy exists |
| `developer` | Diagnostics channel opened by developer tools | Declared |

Every channel has `ChannelSettings` (mute until, pin toggle, retention note,
notification filter) and a derived `ConversationSummary` (unread count, last
message id/time, last activity) built from the row, which is what the
conversation list streams — so listing 10k channels is a small indexed query.
Archiving hides the row from the active list; deletion hard-deletes the
cascade (messages, receipts, drafts, pins) in one transaction.

## 6. Message pipeline (persisted at every step)

```
user composes
   │
   ▼
composer: validate text/type/channel/target  ── ✗ → failure result
   │
   ▼
persist draft (when requested); clear draft once sent
   │
   ▼
create Message(created/queued)  ── inserted + channel summary advanced
   │
   ▼
serialize wire envelope →  build DtnPacket(source, destination, payload)
   │
   ▼
dtnRepository.store(packet)  ── state → waiting/routing (persisted)
   │
   ▼
DTN schedules, retries, relays … until the packet reaches the peer
   │
   ▼
peer node: parse envelope → dedupe (idempotent) → persist → unread++ → notify
   │
   ▼
peer sends delivery-receipt envelope   ── source marks status = delivered
   │
   ▼
peer reads the thread → read-receipt envelope ── source marks status = read
```

Every `MessageStatus` transition is written to SQLite before the next action
begins, so a process kill at any arrow loses nothing: on restart the engine
re-reads the outbox in `queued` and re-stores any envelope that doesn't exist.

## 7. Ordering

- **Timestamp** — sender-provided sort-celled instant (mesh clock).
- **Sequence** — per-channel monotonically increasing counter assigned by the
  local node; the receipt preserves the sender's sequence as tie-break.
- **Packet order** — arrival index at this node; only used when both
  timestamp and sequence are absent (very old/foreign envelopes).
- **Delivery state** — contributes nothing to the sort; it is a separate
  column that drives receipts/UI.
- **messageId** — the final deterministic tie-breaker (bytewise), so the
  total order is stable, reproducible and safe under pagination.

Delayed packets are not delayed: they arrive whenever the mesh delivers, are
inserted with their key-wired position, and the streamed timeline remains in
sender order. Conflict resolution = deterministic key: messages with equal
keys are ordered by the discriminator above; the engine never "decides"
history — it materializes it.

## 8. Delivery receipts

- **Generate** — when a message packet is received and stored, a
  `DeliveryReceipt` is created (Queued → Sent → Delivered) and a receipt
  envelope goes back over the DTN.
- **Apply** — the sender persists the receipt row and moves the message to
  `delivered`.
- **De-duplicate** — (messageId, node) is a unique key; duplicate envelopes
  are dropped.
- **Failed** — a permanent DTN rejection marks the message `failed`.
- **Read** — read receipts are modeled on the same receipt envelope format.

## 9. Read receipts

- Recorded per (messageId, reader node, device, version) so a later
  multi-device phase can render "read on phone and laptop".
- `MarkChannelRead` batches: one envelope positions the read cursor — never
  one envelope per message (a 500-message thread would otherwise send 500
  packets).
- Read time stored; the UI reads the latest read timestamp per peer.

## 10. Typing

- Local typing → bus state `started` → throttled envelope on first change.
- Remote typing envelope → bus state; a timer promotes stale state to
  `timeout` → `idle` (configurable window, default 5s).
- `stopped` on focus loss/final input.
- The bus never flushes: one envelope per `started`/`stopped` transition,
  hard throttle interval (default 1s) on repeats.
- `TypingEvents` rows persist only for developer diagnostics.

## 11. Search

- **Messages**: local `message_search` FTS index (body, sender, title of the
  string channel) refreshed at write time; keyword queries ranked by FTS
  relevance and paged. Date windows, message type, unread-only and
  pinned-only filters compose in SQL.
- **Channels/node names**: an indexed LIKE on the channels table (and node
  profiles for names). 10k rows are sub-millisecond.
- Search never goes on the wire: it is local-first by design (the payload
  envelope never contains ranking).

## 12. Draft system

- One draft per channel (keyed by channel id), updated whenever the composer
  changes and flushed on app kill/close.
- Restored when the thread is opened; deleted when the message is sent or
  the user clears it.
- Draft validates against the same limits as a real send (4-byte payload
  with the FTS budget).
- A draft may target an *edited* message id, so editing resumes where the
  user left off.

## 13. Repositories and use cases

Six repository contracts, each with a drift-backed implementation and a
memory fake for tests:

| Repository | Owns |
| --- | --- |
| `ChannelRepository` | channels + settings + summary + pins |
| `MessageRepository` | messages, timeline pagination, watch, mutations |
| `DraftRepository` | drafts |
| `ReceiptRepository` | delivery + read receipts |
| `SearchRepository` | FTS search, channel search |
| `NotificationRepository` | notification write/watch |

Use cases (see `08-use-cases.md`): CreateChannel, ArchiveChannel, SearchMessages,
SaveDraft, LoadDraft, SendMessage, ReceiveMessage, DeleteMessage, EditMessage,
ReplyMessage, RetryMessage, ForwardMessage, CancelMessage, GenerateReceipt,
GenerateReadReceipt + supporting EntryMessagePin, StarMessage, MarkChannelRead,
WatchTimeline, DeleteChannel.

## 14. Future group support

- The outbox cuts per *recipient node*; private = one, group = N.
- Receipts are per-reader; group read receipts aggregate naturally.
- `MessageStatus.routing` exists for fan-out progress.
- No engine type assumes "exactly one peer"; nothing in the design is
  private-channel-shaped at the model layer. Media/voice/file only require
  new payload types, all already declared in `MessageType`.

## Architecture rules

1. BLE/mesh/packet APIs never appear in this module.
2. All outbound: engine → `DTNRepository`.
3. All persistence via Drift; no direct file I/O except what Drift does.
4. Domain never imports Flutter (`flutter/foundation` only); data layer is
   the only importer of `drift`.
5. Every mutation can be replayed: writes go to the DB first.