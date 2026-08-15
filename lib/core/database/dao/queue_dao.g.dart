// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_dao.dart';

// ignore_for_file: type=lint
mixin _$QueueDaoMixin on DatabaseAccessor<OneBitDatabase> {
  $PendingQueueTable get pendingQueue => attachedDatabase.pendingQueue;
  $RetryQueueTable get retryQueue => attachedDatabase.retryQueue;
  $PacketsTable get packets => attachedDatabase.packets;
  $RelayQueueTable get relayQueue => attachedDatabase.relayQueue;
  QueueDaoManager get managers => QueueDaoManager(this);
}

class QueueDaoManager {
  final _$QueueDaoMixin _db;
  QueueDaoManager(this._db);
  $$PendingQueueTableTableManager get pendingQueue =>
      $$PendingQueueTableTableManager(_db.attachedDatabase, _db.pendingQueue);
  $$RetryQueueTableTableManager get retryQueue =>
      $$RetryQueueTableTableManager(_db.attachedDatabase, _db.retryQueue);
  $$PacketsTableTableManager get packets =>
      $$PacketsTableTableManager(_db.attachedDatabase, _db.packets);
  $$RelayQueueTableTableManager get relayQueue =>
      $$RelayQueueTableTableManager(_db.attachedDatabase, _db.relayQueue);
}
