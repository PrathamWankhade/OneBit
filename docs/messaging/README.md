# Messaging Engine — Phase 8

Design series for the OneBit messaging domain. The engine sits above the DTN
store-and-forward layer and below all future UI; it is the only owner of
message lifecycle, ordering, receipts, drafts, typing, search and internal
notifications.

## Documents

| # | Document |
| --- | --- |
| 01 | [Architecture](01-architecture.md) — goals, layering, modules, channels, ordering, receipts, typing, search, groups |
| 02 | [Folder structure](02-folder-structure.md) — module layout and test layout |
| 03 | [Sequence diagrams](03-sequence-diagram.md) — send, retry, typing, search |
| 04 | [Class diagram](04-class-diagram.md) — engine, repositories, models |
| 05 | [Message pipeline](05-message-pipeline.md) — state machine, wire envelopes, throttles |
| 06 | [Models](06-models.md) — the immutable domain vocabulary |
| 07 | [Repositories](07-repositories.md) — contracts + implementation rules |
| 08 | [Use cases](08-use-cases.md) — the action surface |
| 09 | [Riverpod](09-riverpod.md) — provider surface for the future UI |
| 10 | [Database integration](10-database-integration.md) — schema v3, migrations, FTS |

## Phase boundaries

In scope: messaging logic only. Out of scope (later phases): Flutter
widgets/screens, chat UI, animations, themes, media/voice/file transfer (only
their message types are declared), Android system notifications, BLE work.