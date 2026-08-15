import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_channel_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_message_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_search_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_type.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_search_result.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';
import 'package:onebit/features/messaging/domain/messages/message_type.dart';

import 'support/messaging_support.dart';

void main() {
  group('SqliteSearchRepository', () {
    late OneBitDatabase db;
    late SqliteSearchRepository repo;
    late SqliteChannelRepository channels;
    late SqliteMessageRepository messages;
    late String channelId;

    setUp(() async {
      db = await openInMemoryDb();
      repo = SqliteSearchRepository(db: db, logger: silentLogger);
      channels = SqliteChannelRepository(
        db: db,
        localNodeId: 'node-a',
        logger: silentLogger,
      );
      messages = SqliteMessageRepository(db: db, logger: silentLogger);
      channelId = (await channels.create(
        const CreateChannelParams(type: ChannelType.private, peer: 'node-b'),
      )).value!.channelId;
    });

    tearDown(() => db.close());

    Future<void> storeAndIndex(
      String id,
      String body, {
      MessageType type = MessageType.text,
    }) async {
      final message = Message(
        messageId: id,
        channelId: channelId,
        sender: 'node-b',
        receiver: 'node-a',
        body: body,
        type: type,
        timestamp: DateTime(2026, 1, 1, 10),
        status: MessageStatus.queued,
      );
      await messages.insert(message);
      await repo.indexMessage(
        messageId: id,
        channelId: channelId,
        body: body,
        sender: 'node-b',
        nodeName: 'node-b',
        type: type.name,
        timestampMs: DateTime(2026, 1, 1, 10).millisecondsSinceEpoch,
      );
    }

    test('matches keyword terms in message bodies', () async {
      await storeAndIndex('m-1', 'the quick brown fox');
      await storeAndIndex('m-2', 'utterly unrelated content');
      final result = (await repo.searchMessages(
        const MessageSearchQuery(terms: 'quick fox'),
      )).value!;
      expect(result.items.map((r) => r.messageId), ['m-1']);
    });

    test('finds nothing when nothing matches', () async {
      await storeAndIndex('m-1', 'the quick brown fox');
      final result = (await repo.searchMessages(
        const MessageSearchQuery(terms: 'zzz-nothing'),
      )).value!;
      expect(result.items, isEmpty);
    });

    test('filters by channel and sender', () async {
      await storeAndIndex('m-1', 'shared keyword');
      const query = MessageSearchQuery(terms: 'shared', sender: 'node-b');
      final result = (await repo.searchMessages(query)).value!;
      expect(result.items, hasLength(1));

      final otherChannel = (await channels.create(
        const CreateChannelParams(type: ChannelType.private, peer: 'node-c'),
      )).value!.channelId;
      final channelQuery = MessageSearchQuery(
        terms: 'shared',
        channelId: otherChannel,
      );
      final filtered = (await repo.searchMessages(channelQuery)).value!;
      expect(filtered.items, isEmpty);
    });

    test('filters by message type', () async {
      await storeAndIndex('m-1', 'plain words', type: MessageType.text);
      await storeAndIndex('m-2', 'plain words', type: MessageType.markdown);
      const query = MessageSearchQuery(
        terms: 'plain',
        type: MessageType.markdown,
      );
      final result = (await repo.searchMessages(query)).value!;
      expect(result.items.map((r) => r.messageId), ['m-2']);
    });

    test('pages search results', () async {
      for (var i = 0; i < 7; i++) {
        await storeAndIndex('page-$i', 'keyword number $i');
      }
      final first = (await repo.searchMessages(
        const MessageSearchQuery(terms: 'keyword'),
        limit: 3,
      )).value!;
      expect(first.items, hasLength(3));
      expect(first.hasMore, isTrue);
      final second = (await repo.searchMessages(
        const MessageSearchQuery(terms: 'keyword'),
        offset: 3,
        limit: 3,
      )).value!;
      expect(second.items, hasLength(3));
      final third = (await repo.searchMessages(
        const MessageSearchQuery(terms: 'keyword'),
        offset: 6,
        limit: 3,
      )).value!;
      expect(third.items, hasLength(1));
      expect(third.hasMore, isFalse);
    });

    test('removing a message removes it from the index', () async {
      await storeAndIndex('m-1', 'fragile keyword');
      await repo.removeFromIndex('m-1');
      final result = (await repo.searchMessages(
        const MessageSearchQuery(terms: 'fragile'),
      )).value!;
      expect(result.items, isEmpty);
    });

    test('rebuildIndex rehydrates the index from the message table', () async {
      await storeAndIndex('m-1', 'reindex me please');
      await repo.removeFromIndex('m-1');
      final rebuilt = (await repo.rebuildIndex()).value!;
      expect(rebuilt, 1);
      final result = (await repo.searchMessages(
        const MessageSearchQuery(terms: 'reindex'),
      )).value!;
      expect(result.items, hasLength(1));
    });

    test('searchChannels finds channels by title and id', () async {
      await channels.rename(channelId, 'Bob Channel');
      final byTitle = (await repo.searchChannels('Bob')).value!;
      expect(byTitle.map((s) => s.channelId), contains(channelId));
    });

    test('deleted messages are excluded unless requested', () async {
      await storeAndIndex('m-1', 'tomorrow it is gone');
      await messages.delete('m-1');
      final defaultResult = (await repo.searchMessages(
        const MessageSearchQuery(terms: 'tomorrow'),
      )).value!;
      expect(defaultResult.items, isEmpty);
      final includeDeleted = (await repo.searchMessages(
        const MessageSearchQuery(terms: 'tomorrow', includeDeleted: true),
      )).value!;
      expect(includeDeleted.items, hasLength(1));
    });
  });
}
