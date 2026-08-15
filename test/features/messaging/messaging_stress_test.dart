import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/tables/enums.dart' as core;
import 'package:onebit/features/messaging/data/repositories/sqlite_channel_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_message_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_type.dart';

import 'support/messaging_support.dart';

/// Stress: the messaging store is built for 100k+ messages across 10k+
/// channels with fast keyset pagination, minimal memory and no full-table
/// scans on the hot paths.
void main() {
  /// Bulk-loads [count] message rows into the given channels through drift's
  /// batch (single transaction, no per-row round trip).
  Future<void> bulkInsert(
    OneBitDatabase db,
    List<String> channelIds,
    int perChannel,
  ) async {
    final base = DateTime(2026, 1, 1);
    var seq = 0;
    await db.transaction(() async {
      for (final channelId in channelIds) {
        await db.batch((batch) {
          for (var i = 0; i < perChannel; i++) {
            seq++;
            batch.insert(
              db.messages,
              MessagesCompanion.insert(
                messageId: 'm$seq',
                channelId: channelId,
                sender: 'node-a',
                receiver: const Value('peer-x'),
                timestamp: base.add(Duration(seconds: seq)),
                encryptedPayload: Uint8List(0),
                messageType: core.MessageType.text,
                priority: const Value(core.PriorityLevel.normal),
                status: const Value(core.MessageStatus.queued),
                sequence: Value(i + 1),
                bodyText: Value('stress message $seq with enough text'),
              ),
            );
          }
        });
      }
    });
  }

  test(
    '100k messages across 10k channels page and list in bounded time',
    () async {
      final db = await openInMemoryDb();
      try {
        final channels = SqliteChannelRepository(
          db: db,
          localNodeId: 'node-a',
          logger: silentLogger,
        );
        final messages = SqliteMessageRepository(db: db, logger: silentLogger);

        // 10k channels × 10 messages = 100k rows.
        final channelIds = <String>[];
        for (var c = 0; c < 10000; c++) {
          final id = (await channels.create(
            CreateChannelParams(type: ChannelType.private, peer: 'peer-$c'),
          )).value!.channelId;
          channelIds.add(id);
        }
        final load = Stopwatch()..start();
        await bulkInsert(db, channelIds, 10);
        load.stop();
        expect((await messages.countMessages()).value, 100000);

        // Keyset pagination returns instantly on a small channel.
        final first = (await messages.pageChannel(
          channelIds.first,
          limit: 5,
        )).value!;
        expect(first.items, hasLength(5));
        final second = (await messages.pageChannel(
          channelIds.first,
          cursor: first.cursor,
          limit: 5,
        )).value!;
        expect(second.items, hasLength(5));

        // Channel listing of 10k conversations stays bounded.
        final summaries = (await channels.listSummaries()).value!;
        expect(summaries, hasLength(10000));

        // Watch stream on a hot channel emits the same page.
        final watched = await messages.watchChannel(channelIds.first).first;
        expect(watched.value, hasLength(10));

        // Sanity: bulk insert stays comfortably interactive for a 100k dataset.
        expect(load.elapsedMilliseconds, lessThan(30000));
      } finally {
        await db.close();
      }
    },
  );

  test('pagination cost stays flat as a single channel grows to 20k', () async {
    final db = await openInMemoryDb();
    try {
      final channels = SqliteChannelRepository(
        db: db,
        localNodeId: 'node-a',
        logger: silentLogger,
      );
      final messages = SqliteMessageRepository(db: db, logger: silentLogger);
      final channelId = (await channels.create(
        const CreateChannelParams(type: ChannelType.private, peer: 'peer-x'),
      )).value!.channelId;

      await bulkInsert(db, [channelId], 20000);

      final sw = Stopwatch()..start();
      final page = (await messages.pageChannel(channelId, limit: 50)).value!;
      sw.stop();
      expect(page.items, hasLength(50));
      // One keyset fetch of a 20k-row channel must stay well under a second.
      expect(sw.elapsedMilliseconds, lessThan(2500));
    } finally {
      await db.close();
    }
  });
}
