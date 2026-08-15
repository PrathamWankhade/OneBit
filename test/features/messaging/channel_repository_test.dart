import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_channel_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_type.dart';

import 'support/messaging_support.dart';

void main() {
  group('SqliteChannelRepository', () {
    late OneBitDatabase db;
    late SqliteChannelRepository repo;

    setUp(() async {
      db = await openInMemoryDb();
      repo = SqliteChannelRepository(
        db: db,
        localNodeId: 'node-a',
        logger: silentLogger,
      );
    });

    tearDown(() => db.close());

    Future<String> openChannel(String peer) async {
      final result = await repo.create(
        CreateChannelParams(type: ChannelType.private, peer: peer),
      );
      return result.value!.channelId;
    }

    test('creates a private channel idempotently', () async {
      final first = (await repo.create(
        const CreateChannelParams(type: ChannelType.private, peer: 'node-b'),
      )).value!;
      final second = (await repo.create(
        const CreateChannelParams(type: ChannelType.private, peer: 'node-b'),
      )).value!;
      expect(first.channelId, second.channelId);
      expect(first.peer, 'node-b');

      // distinct peers produce distinct channels
      final other = (await repo.create(
        const CreateChannelParams(type: ChannelType.private, peer: 'node-c'),
      )).value!;
      expect(other.channelId, isNot(first.channelId));
    });

    test('refuses a private channel without a distinct peer', () async {
      final result = await repo.create(
        const CreateChannelParams(type: ChannelType.private),
      );
      expect(result.isErr, isTrue);
    });

    test('renames and archives', () async {
      final channelId = await openChannel('node-b');
      expect((await repo.getChannel(channelId)).value!.title, 'node-b');

      await repo.rename(channelId, 'Bob #2');
      expect((await repo.getChannel(channelId)).value!.title, 'Bob #2');

      await repo.archive(channelId);
      var list = (await repo.listSummaries()).value!;
      expect(list, isEmpty);
      list = (await repo.listSummaries(includeArchived: true)).value!;
      expect(list, hasLength(1));

      await repo.archive(channelId, archived: false);
      list = (await repo.listSummaries()).value!;
      expect(list, hasLength(1));
    });

    test('mute / unmute round-trip', () async {
      final channelId = await openChannel('node-b');
      await repo.setMuted(channelId);
      var channel = (await repo.getChannel(channelId)).value!;
      expect(channel.settings.isEffectivelyMuted, isTrue);
      await repo.unmute(channelId);
      channel = (await repo.getChannel(channelId)).value!;
      expect(channel.settings.isEffectivelyMuted, isFalse);
    });

    test('allocs monotonic per-channel sequences', () async {
      final a = await openChannel('node-b');
      final b = await openChannel('node-c');
      expect((await repo.nextSequence(a)).value, 1);
      expect((await repo.nextSequence(a)).value, 2);
      expect((await repo.nextSequence(b)).value, 1);
      expect((await repo.nextSequence(b)).value, 2);
    });

    test('bumpActivity tracks unread and last activity', () async {
      final channelId = await openChannel('node-b');
      final at = DateTime(2026, 1, 1, 12);
      await repo.bumpActivity(
        channelId,
        unreadDelta: 1,
        lastMessageId: 'm-1',
        lastMessageAt: at,
      );
      final summary = (await repo.listSummaries()).value!.single;
      expect(summary.unreadCount, 1);
      expect(summary.lastMessageId, 'm-1');
      expect(summary.lastMessageAt, at);
      expect(summary.lastActivityAt, isNotNull);
    });

    test('markRead resets the unread counter', () async {
      final channelId = await openChannel('node-b');
      await repo.bumpActivity(channelId, unreadDelta: 7);
      expect((await repo.listSummaries()).value!.single.unreadCount, 7);
      await repo.markRead(channelId);
      expect((await repo.listSummaries()).value!.single.unreadCount, 0);
    });

    test('deletes the channel (cascade contract)', () async {
      final channelId = await openChannel('node-b');
      await repo.deleteChannel(channelId);
      expect((await repo.getChannel(channelId)).value, isNull);
    });

    test('pins and unpins messages', () async {
      final channelId = await openChannel('node-b');
      await repo.pinMessage(channelId, 'm-1');
      await repo.pinMessage(channelId, 'm-2');
      var pinned = (await repo.pinnedMessages(channelId)).value!;
      expect(pinned, hasLength(2));
      await repo.unpinMessage(channelId, 'm-1');
      pinned = (await repo.pinnedMessages(channelId)).value!;
      expect(pinned.map((p) => p.messageId), ['m-2']);
    });

    test('pin channel surfaces in ordering', () async {
      final a = await openChannel('node-b');
      await openChannel('node-c');
      final at = DateTime(2026, 1, 1, 12);
      await repo.bumpActivity(a, lastMessageAt: at);
      await repo.setPinned(a, pinned: true);
      final list = (await repo.listSummaries()).value!;
      expect(list.first.channelId, a);
    });

    test('watchSummaries streams summaries', () async {
      await openChannel('node-b');
      final page = await repo.watchSummaries().first;
      expect(page.value, isNotNull);
      final summaries = page.value!;
      expect(summaries, hasLength(1));
    });
  });
}
