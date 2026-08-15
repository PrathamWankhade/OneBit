# Models — Vocabulary of the Messaging Domain

All domain models are immutable (`final class`, const constructors where
possible), implement `==`/`hashCode` on identity fields, and never import
packages beyond `flutter/foundation` (metadata hints only).

| Model | Fields | Notes |
| --- | --- | --- |
| `Channel` | id, type (ChannelType), title, settings, summary | Settings + summary embedded; one row ↔ one object |
| `ChannelType` | private, group, broadcast, emergency, developer | `isSupported` flag: only private first-class today |
| `ChannelSettings` | muted, mutedUntil, pinned, notificationFilter, retentionNote | Mutable via repository mutations only |
| `Message` | id, channelId, sender, receiver, type, status, body, timestamp, sequence, packetOrder, replyTo, forwarded, edited, deleted, starred, readAt, version, ttl, metadata | Wire `type` is the app content kind |
| `MessageStatus` | created, queued, waiting, routing, relayed, delivered, verified, read, expired, failed, deleted | Persisted as stable name |
| `MessageType` | text, markdown, system, notification, identity, handshake, receipt, developer, media*, voice*, file* | `*` declared future kinds |
| `MessagePriority` | low, normal, high, urgent | Mapped to DTN dtnPriority |
| `MessageMetadata` | clientId, packetId, attemptCount, lastError, deliveredAt?, verifiedAt? | Transient across rows |
| `Draft` | channelId, body, editingMessageId?, createdAt, updatedAt | One per channel |
| `TypingState` | node, channelId, state, since | started/stopped/timeout/idle |
| `DeliveryReceipt` | messageId, node, deliveredAt, metadata, state | State: queued→sent→relayed→delivered→read / failed / duplicate |
| `ReadReceipt` | messageId, node, device, version, readAt | Multi-device ready |
| `MessageReaction` | messageId, node, reaction | Emoji string |
| `ConversationSummary` | channelId, title, unreadCount, lastMessageId, lastMessageAt, lastActivityAt | Streamed to the conversation list |
| `PinnedMessage` | channelId, messageId, pinnedBy, pinnedAt | Snap to channel heading |
| `MessageSearchResult` | messageId, channelId, sender, snippet, type, timestamp, rank | Rank from FTS |
| `MessageWireEnvelope` | v, kind, mid, cid, sender, receiver, type, body, seq, ts, replyTo, edited, forwarded | Wire codec object |
| `ReceiptEnvelope` | v, kind(delivery|read), mid, node, at, device?, version? | Wire codec object |
| `TypingEnvelope` | v, cid, node, state, ts | Wire codec object |

## Persistence mapping

| Domain | Drift row | Converter |
| --- | --- | --- |
| Channel | ChannelRow (extended) | ChannelMapper |
| Message | MessageRow (extended) | MessageMapper |
| Draft | MessageDraftRow | DraftMapper |
| DeliveryReceipt | DeliveryReceiptRow (existing) | — |
| ReadReceipt | ReadReceiptRow (existing) | — |
| Reaction | MessageReactionRow | — |
| Pinned | PinnedMessageRow | — |
| Metadata | MessageMetadataRow | — |
| Search | message_search (FTS) | SearchIndexer |
| Notification row | NotificationRow | — |