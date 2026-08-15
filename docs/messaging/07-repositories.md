# Repositories — contracts and implementations

## Contracts (domain layer)

```dart
abstract interface class ChannelRepository {
  Stream<Result<List<ConversationSummary>>> watchSummaries({bool includeArchived});
  Future<Result<List<ConversationSummary>>> listSummaries(...);
  Future<Result<Channel>> getChannel(String id);
  Future<Result<Channel>> create(CreateChannelParams params);
  Future<Result<void>> rename(String id, String title);
  Future<Result<void>> archive(String id);          // soft hide
  Future<Result<void>> deleteChannel(String id);    // hard cascade
  Future<Result<void>> mute(String id, {DateTime? until});
  Future<Result<void>> unmute(String id);
  Future<Result<void>> setPinned(String id, bool pinned);
  Future<Result<void>> markChannelRead(String id);  // unread=0
  Future<Result<List<Message>>> pinnedMessages(String channelId);
}
```

```dart
abstract interface class MessageRepository {
  Stream<Result<List<Message>>> watchChannel(String channelId, {int limit});
  Future<Result<MessagePage>> pageChannel(String channelId, {PageCursor? cursor, int limit});
  Future<Result<Message?>> getMessage(String id);
  Future<Result<Message>> insert(Message message);          // idempotent by id
  Future<Result<Message>> update(Message message);          // edits, status flow
  Future<Result<void>> setStatus(String id, MessageStatus status);
  Future<Result<void>> delete(String id);                   // soft
  Future<Result<void>> star(String id, bool starred);
  Future<Result<void>> watchTimeline(StreamController);     // ordering-ready
}
```

```dart
abstract interface class DraftRepository {
  Future<Result<void>> save(Draft draft);
  Future<Result<Draft?>> load(String channelId);
  Future<Result<void>> delete(String channelId);
  Stream<Result<Draft?>> watch(String channelId);
}
```

```dart
abstract interface class ReceiptRepository {
  Future<Result<void>> saveDelivery(DeliveryReceipt);
  Future<Result<void>> saveRead(ReadReceipt);
  Future<Result<List<DeliveryReceipt>>> deliveryFor(String messageId);
  Future<Result<List<ReadReceipt>>> readFor(String messageId);
  Stream<Result<List<ReadReceipt>>> watchReadFor(String messageId);
}
```

```dart
abstract interface class SearchRepository {
  Future<Result<SearchPage<MessageSearchResult>>> search(MessageSearchQuery);
  Future<Result<SearchPage<ChannelSummary>>>   searchChannels(String query);
  Future<Result<void>> indexMessage(Message);
  Future<Result<void>> removeFromIndex(String messageId);
  Future<Result<int>>  rebuildIndex();          // repair path, returns rows
}
```

```dart
abstract interface class NotificationRepository {
  Future<Result<NotificationEvent>> push(NotificationEvent);
  Stream<Result<NotificationEvent>> watch();
  Future<Result<Page<NotificationEvent>>> page({PageRequest});
  Future<Result<int>> clearAll();
}
```

## Implementations (data layer)

All six implementations live under `features/messaging/data/repositories/`
and talk to the single drift database through `MessagingDao` (plus the
existing `MessageDao`/`ChannelDao` where row shape dictates). Every method:
1. runs inside `ResultGuards.guard`,
2. returns `Ok`/`Err` (never throws across the boundary),
3. logs with `TaggedLogger('messaging')`.

**Concurrency rule:** the engine serializes writes per channel with a
per-channel mutex in the outbox; drift transactions (`db.transaction`) hold
the row/table locks, and the DAO uses `insertOnConflictUpdate` for
idempotency.

## Repository guarantees

| Operation | Guarantee |
| --- | --- |
| insert message | idempotent (PK `messageId`), never overwrites an existing row with a stale copy |
| status flow | only forward transitions allowed (`delivered`→`read`, never backward unless `failed`/`expired`) |
| draft save | upsert keyed by channel |
| receipts | unique `(messageId, node)` — duplicates dropped |
| search index | write-through on every message insert/update/delete |
| channel summary | updated in the same transaction as the message write `tx` |