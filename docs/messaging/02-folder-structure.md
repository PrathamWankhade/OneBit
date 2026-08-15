# Folder Structure — Messaging Domain

```
lib/features/messaging/
├── presentation/                      # Riverpod providers (UI contract only)
│   └── messaging_providers.dart
│
├── domain/
│   ├── channels/
│   │   ├── channel.dart               # Channel model + ConversationSummary
│   │   ├── channel_settings.dart      # ChannelSettings (+ mute window)
│   │   ├── channel_type.dart          # private | group | broadcast | emergency | developer
│   │   ├── channel_repository.dart    # contract (list, create, archive, mute, pin, rename, ...)
│   │   ├── pinned_message.dart
│   │   └── channel_sort.dart          # sort keys (lastActivity, title, unread, pin)
│   ├── messages/
│   │   ├── message.dart               # Message (immutable)
│   │   ├── message_status.dart        # created→queued→…→read / failed / expired / deleted
│   │   ├── message_type.dart          # text | markdown | system | notification | …
│   │   ├── message_priority.dart      # low | normal | high | urgent
│   │   ├── message_reaction.dart
│   │   ├── message_metadata.dart      # per-message machine metadata
│   │   ├── message_repository.dart    # contract
│   │   ├── message_ordering.dart      # ordering engine (timestamp/sequence/packet/conflict)
│   │   ├── message_search_result.dart
│   │   └── message_failure.dart       # messaging-specific Failure subclasses
│   ├── drafts/
│   │   ├── draft.dart
│   │   └── draft_repository.dart      # contract
│   ├── delivery/
│   │   ├── delivery_receipt.dart      # DeliveryReceipt + receipt state
│   │   ├── delivery_repository.dart   # contract (receipts)
│   │   └── receipt_engine.dart        # generate/apply/transport receipts
│   ├── receipts/
│   │   ├── read_receipt.dart
│   │   └── receipt_repository.dart   # read receipts persist + apply
│   ├── search/
│   │   └── search_repository.dart    # contract
│   ├── notifications/
│   │   ├── notification.dart          # NotificationEvent model
│   │   └── notification_repository.dart
│   ├── history/
│   │   └── conversation_history.dart  # cursor pagination contract
│   ├── use_cases/                     # one file per action
│   │   ├── send_message.dart
│   │   ├── receive_message.dart
│   │   ├── delete_message.dart
│   │   ├── edit_message.dart
│   │   ├── reply_message.dart
│   │   ├── retry_message.dart
│   │   ├── cancel_message.dart
│   │   ├── forward_message.dart
│   │   ├── create_message_draft.dart
│   │   ├── create_channel.dart
│   │   ├── archive_channel.dart
│   │   ├── search_messages.dart
│   │   ├── save_draft.dart
│   │   ├── load_draft.dart
│   │   ├── generate_receipt.dart
│   │   ├── generate_read_receipt.dart
│   │   └── use_case_results.dart     # typed result objects
│   └── engine/
│       ├── messaging_engine.dart     # façade: start/stop, wiring, streams
│       ├── inbound_pump.dart         # observeDelivered() loop + dispatch
│       ├── outbox.dart               # send/retry/resend/cancel state machine
│       ├── composer_service.dart     # validate + prepare outgoing messages
│       ├── ordering_entry.dart       # per-channel sequence + ordering keys
│       ├── unread_tracker.dart       # unread counters (single writer)
│       ├── typing_engine.dart        # typing bus + throttle + timeouts
│       ├── notification_engine.dart  # internal notification bus
│       └── search_indexer.dart       # keeps FTS mirror of the messages table
│
├── data/
│   ├── wire/
│   │   ├── message_wire_codec.dart        # envelope JSON ⇄ bytes
│   │   ├── receipt_wire_codec.dart
│   │   └── typing_wire_codec.dart
│   ├── adapters/
│   │   └── dtn_transport.dart         # DTNRepository adapter (allowed seam)
│   ├── mappers/
│   │   ├── message_mapper.dart        # domain ⇄ MessageRow
│   │   ├── channel_mapper.dart
│   │   └── draft_mapper.dart
│   └── repositories/
│       ├── sqlite_channel_repository.dart
│       ├── sqlite_message_repository.dart
│       ├── sqlite_draft_repository.dart
│       ├── sqlite_receipt_repository.dart
│       ├── sqlite_search_repository.dart
│       └── sqlite_notification_repository.dart
│
core/database/
├── tables/messaging_tables.dart      # drafts, pins, reactions, metadata, notifications
├── tables/channel_tables.dart        # (+ lastSequence column)
├── tables/message_tables.dart        # (+ sequence, bodyText, packetId, clientId, readAt, starred, verified)
├── tables/enums.dart                 # expanded persisted vocabulary
├── dao/messaging_dao.dart            # new DAO for messaging tables + FTS
└── migration/…  (v3 step)

lib/features/messaging/providers.dart  # all Riverpod providers
```

## Test layout

```
test/features/messaging/
├── support/                       # harness: two-node in-memory mesh + db
│   ├── two_node_harness.dart
│   └── store_fakes.dart           # InMemory repositories + fakes
├── message_model_test.dart
├── message_ordering_test.dart
├── channel_model_test.dart
├── channel_repository_test.dart
├── message_repository_test.dart
├── draft_test.dart
├── delivery_receipt_test.dart
├── read_receipt_test.dart
├── search_test.dart
├── retry_test.dart
├── typing_test.dart
├── notification_test.dart
├── pipeline_test.dart             # end-to-end two-node send→deliver→read
└── messaging_stress_test.dart     # 100k messages, 10k channels
```