# Use Cases

Every use case extends the shared `UseCase<Params, Result<T>>` base, returns
`Result` (never throws), is pure domain (no Flutter imports), and is fully
unit-testable with in-memory fakes.

## Message actions

| Use case | Parameters | Behavior |
| --- | --- | --- |
| `SendMessage` | channelId, body, type, priority, replyTo? | validate → draft clear → create → persist → outbox.send → returns Message |
| `ReceiveMessage` | wire envelope bytes | parse → dedupe → persist → unread++ → notify → generate delivery receipt |
| `DeleteMessage` | messageId | soft delete tombstone; purge draft if editing it |
| `EditMessage` | messageId, newBody | validate ownership → update body + edited flag → update index → outbox re-send edit envelope |
| `ReplyMessage` | replyToId, text | creates a reply (replyTo set) and sends |
| `ForwardMessage` | messageId, targetChannelId | clones text into target channel (forwarded=true) |
| `RetryMessage` | messageId | re-arm outbox: re-store envelope with new TTL, reset attemptCount |
| `CancelMessage` | messageId | cancels envelope in DTN; status=queued→canceled fails terminal |
| `StarMessage` | messageId, bool | starred toggle |
| `PinMessage` | channelId, messageId | pinned row + channel banner |

## Channel actions

| Use case | Parameters | Behavior |
| --- | --- | --- |
| `CreateChannel` | peer, title, type | creates private channel if absent (idempotent) |
| `ArchiveChannel` | channelId, archived=true | hides from active list |
| `RenameChannel` | channelId, newTitle | local rename |
| `MuteChannel` | channelId, until? | persists mute window |
| `UnmuteChannel` | channelId | clears window |
| `DeleteChannel` | channelId | hard delete cascade (messages, drafts, pins, receipts) |

## Drafts

| `SaveDraft` | channelId, body, editingMessageId? | upsert + updatedAt |
| `LoadDraft` | channelId | draft or null |

## Search

| `SearchMessages` | query terms, filters (channel,sender,type,date window,unread,pinned), page | FTS query |
| `SearchChannels` | terms | LIKE over listing |

## Receipts

| `GenerateReceipt` | inbound message | DeliveryReceipt row + envelope back to sender |
| `GenerateReadReceipt` | channelId | per-reader batch receipt envelope |

## Results

Results returned by use cases are typed value objects:

- `SendResult { messageId, status, packetId?, channelId }`
- `ReceiveResult { message: Message?, duplicate: bool }`
- `RetryResult { messageId, attempt, nextAttemptAt }`
- `ChannelResult { channel }` …