import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_channel_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_conversation_history.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_message_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_type.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';

import 'support/messaging_support.dart';

void main() {
  group('SqliteConversationHistory', () {
    late OneBitDatabase db;
    late SqliteConversationHistory history;
    late SqliteMessageRepository messages;
    late String channelId;

    setUp(() async {
      db = await openInMemoryDb();
      messages = SqliteMessageRepository(db: db, logger: silentLogger);
      final channels = SqliteChannelRepository(
        db: db,
        localNodeId: 'node-a',
        logger: silentLogger,
      );
      history = SqliteConversationHistory(db: db, logger: silentLogger);
      channelId = (await channels.create(
        const CreateChannelParams(type: ChannelType.private, peer: 'node-b'),
      )).value!.channelId;
    });

    tearDown(() => db.close());

    Future<void> insertMany(int count) async {
      final base = DateTime(2026, 1, 1, 9);
      for (var i = 0; i < count; i++) {
        await messages.insert(
          Message(
            messageId: 'h-$i',
            channelId: channelId,
            sender: 'node-a',
            receiver: 'node-b',
            body: 'history $i',
            timestamp: base.add(Duration(minutes: i)),
            sequence: i + 1,
          ),
        );
      }
    }

    test('loadNewest returns the newest page', () async {
      await insertMany(60);
      final page = (await history.loadNewest(channelId, limit: 25)).value!;
      expect(page.items, hasLength(25));
      expect(page.items.last.messageId, 'h-59');
      expect(page.hasMore, isTrue);
    });

    test('loadOlder pages backward contiguously without duplicates', () async {
      await insertMany(60);
      final newest = (await history.loadNewest(channelId, limit: 20)).value!;
      final older = (await history.loadOlder(
        channelId,
        cursor: newest.cursor!,
        limit: 20,
      )).value!;
      expect(older.items, hasLength(20));
      // Contiguous: the newest message of the older page is the sequence
      // right before the oldest message of the newest page.
      expect(older.items.last.sequence, newest.items.first.sequence - 1);
      final ids = {
        ...newest.items.map((m) => m.messageId),
        ...older.items.map((m) => m.messageId),
      };
      expect(ids, hasLength(40));
    });

    test('loadAround jumps to a message with a bounded window', () async {
      await insertMany(100);
      final page = (await history.loadAround(
        channelId,
        anchorMessageId: 'h-50',
        window: 20,
      )).value!;
      expect(page.items.map((m) => m.messageId), contains('h-50'));
      final index = page.items.indexWhere((m) => m.messageId == 'h-50');
      final before = page.items.take(index).length;
      final after = page.items.skip(index + 1).length;
      expect(before, lessThanOrEqualTo(10));
      expect(after, lessThanOrEqualTo(10));
    });

    test('loadAround errors on an unknown anchor', () async {
      await insertMany(5);
      final result = await history.loadAround(
        channelId,
        anchorMessageId: 'ghost',
      );
      expect(result.isErr, isTrue);
    });

    test('count and newest helpers', () async {
      await insertMany(12);
      expect((await history.count(channelId)).value, 12);
      expect((await history.newest(channelId)).value!.messageId, 'h-11');
    });
  });
}
