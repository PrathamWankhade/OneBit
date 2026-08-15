import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_channel_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_message_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_type.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_metadata.dart';
import 'package:onebit/features/messaging/domain/messages/message_ordering.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';

import 'support/messaging_support.dart';

Message msg(
  String id, {
  required String channel,
  required DateTime timestamp,
  int sequence = 0,
  String sender = 'node-a',
  MessageStatus status = MessageStatus.queued,
}) => Message(
  messageId: id,
  channelId: channel,
  sender: sender,
  receiver: 'node-b',
  timestamp: timestamp,
  sequence: sequence,
  packetOrder: timestamp.microsecondsSinceEpoch,
  body: 'body of $id',
  status: status,
);

void main() {
  group('SqliteMessageRepository', () {
    late OneBitDatabase db;
    late SqliteMessageRepository repo;
    late SqliteChannelRepository channels;
    late String channelId;

    setUp(() async {
      db = await openInMemoryDb();
      repo = SqliteMessageRepository(db: db, logger: silentLogger);
      channels = SqliteChannelRepository(
        db: db,
        localNodeId: 'node-a',
        logger: silentLogger,
      );
      channelId = (await channels.create(
        const CreateChannelParams(type: ChannelType.private, peer: 'node-b'),
      )).value!.channelId;
    });

    tearDown(() => db.close());

    Future<void> insertMany(int count, {DateTime? base}) async {
      final origin = base ?? DateTime(2026, 1, 1, 9);
      for (var i = 0; i < count; i++) {
        await repo.insert(
          msg(
            'm-$i',
            channel: channelId,
            timestamp: origin.add(Duration(minutes: i)),
            sequence: i + 1,
          ),
        );
      }
    }

    test('insert is idempotent by messageId', () async {
      final a = msg('dup', channel: channelId, timestamp: DateTime(2026, 1, 1));
      await repo.insert(a);
      final second = await repo.insert(
        msg(
          'dup',
          channel: channelId,
          timestamp: DateTime(2026, 1, 1, 5),
          sequence: 99,
        ),
      );
      expect(second.value!.timestamp, a.timestamp);
      final count = (await repo.countMessages(channelId: channelId)).value!;
      expect(count, 1);
    });

    test('pages the timeline with keyset cursors (no duplication)', () async {
      await insertMany(120);
      // pageChannel is newest-first: the first page holds sequences 71..120.
      final page1 = (await repo.pageChannel(channelId, limit: 50)).value!;
      expect(page1.items, hasLength(50));
      expect(page1.hasMore, isTrue);
      expect(page1.items.first.sequence, 71);

      // The cursor moves strictly older: the next page holds 21..70.
      final page2 = (await repo.pageChannel(
        channelId,
        cursor: page1.cursor,
        limit: 50,
      )).value!;
      expect(page2.items, hasLength(50));
      expect(page2.items.first.sequence, 21);
      expect(page2.items.last.sequence, 70);
    });

    test('pages to the end cleanly', () async {
      await insertMany(7);
      var cursor = (await repo.pageChannel(channelId, limit: 5)).value!.cursor;
      final page2 = (await repo.pageChannel(
        channelId,
        cursor: cursor,
        limit: 5,
      )).value!;
      expect(page2.items, hasLength(2));
      expect(page2.hasMore, isFalse);
      cursor = page2.cursor;
      final page3 = (await repo.pageChannel(
        channelId,
        cursor: cursor,
        limit: 5,
      )).value!;
      expect(page3.items, isEmpty);
      expect(page3.hasMore, isFalse);
    });

    test('status transitions are forward-only', () async {
      final stored = await repo.insert(
        msg('s', channel: channelId, timestamp: DateTime(2026, 1, 1)),
      );
      await repo.setStatus(stored.value!.messageId, MessageStatus.waiting);
      final regressed = await repo.setStatus(
        stored.value!.messageId,
        MessageStatus.created,
      );
      expect(regressed.isErr, isTrue);
    });

    test('watchChannel streams timeline updates', () async {
      await insertMany(3);
      final first = await repo.watchChannel(channelId, limit: 10).first;
      expect(first.value, hasLength(3));
      await repo.insert(
        msg('m-99', channel: channelId, timestamp: DateTime(2026, 1, 1, 10)),
      );
      final second = await repo.watchChannel(channelId, limit: 10).first;
      expect(second.value, hasLength(4));
    });

    test('markReadThrough respects timeline order', () async {
      await insertMany(5);
      // Full timeline is ascending [1..5]; mark through message 3, so the
      // first three messages (plus any equals with the same timestamp/seq)
      // become read — never messages above the boundary.
      final all = (await repo.pageChannel(channelId, limit: 10)).value!;
      final target = all.items[2];
      expect(target.sequence, 3);
      final marked = (await repo.markReadThrough(
        channelId,
        MessageOrderKey.of(target),
      )).value!;
      expect(marked, 3);
      final newer = (await repo.pageChannel(
        channelId,
        limit: 10,
      )).value!.items.where((m) => m.readAt != null).length;
      expect(newer, 3);
      final boundary = (await repo.pageChannel(
        channelId,
        limit: 10,
      )).value!.items[3];
      expect(boundary.readAt, isNull);
    });

    test('delete tombstones and hides from the timeline', () async {
      await insertMany(4);
      const victimId = 'm-1';
      await repo.delete(victimId);
      final gone = (await repo.getMessage(victimId)).value!;
      expect(gone.deleted, isTrue);
      final ids = (await repo.pageChannel(
        channelId,
        limit: 10,
      )).value!.items.map((m) => m.messageId);
      expect(ids, isNot(contains(victimId)));
    });

    test('purgeDeleted removes old tombstones only', () async {
      await insertMany(3);
      await repo.delete('m-0');
      final oldTombstone = (await repo.getMessage('m-0')).value!;
      final purged = (await repo.purgeDeleted(
        oldTombstone.timestamp.add(const Duration(minutes: 1)),
      )).value!;
      expect(purged, hasLength(1));
      expect((await repo.getMessage('m-0')).value, isNull);
    });

    test('star toggles persist', () async {
      await insertMany(1);
      await repo.star('m-0', starred: true);
      expect((await repo.getMessage('m-0')).value!.starred, isTrue);
      await repo.star('m-0', starred: false);
      expect((await repo.getMessage('m-0')).value!.starred, isFalse);
    });

    test('outboxPending finds composed messages without an envelope', () async {
      final composed = await repo.insert(
        msg('p', channel: channelId, timestamp: DateTime(2026, 1, 1)),
      );
      expect((await repo.outboxPending('node-a')).value, hasLength(1));
      // Once the outbox pairs the message with an envelope (packetId), it is
      // no longer pending — even though its status is still queued.
      await repo.update(
        composed.value!.copyWith(
          metadata: const MessageMetadata(packetId: 'pkt-1'),
        ),
      );
      expect((await repo.outboxPending('node-a')).value, isEmpty);
    });

    test('expireOverdue marks only expired TTL messages', () async {
      final now = DateTime(2026, 1, 1, 12);
      await repo.insert(
        msg(
          'ttl-1',
          channel: channelId,
          timestamp: now,
        ).copyWith(ttl: const Duration(seconds: 60)),
      );
      await repo.insert(
        msg(
          'ttl-2',
          channel: channelId,
          timestamp: now,
        ).copyWith(ttl: const Duration(seconds: 3600)),
      );
      final expired = (await repo.expireOverdue(
        now.add(const Duration(minutes: 2)),
      )).value!;
      expect(expired.map((m) => m.messageId), ['ttl-1']);
      expect(
        (await repo.getMessage('ttl-1')).value!.status,
        MessageStatus.expired,
      );
    });
  });
}
