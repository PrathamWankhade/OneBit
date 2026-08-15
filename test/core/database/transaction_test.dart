import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/dao/channel_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/tables/enums.dart';

import 'support/database_support.dart';

void main() {
  late OneBitDatabase db;

  setUp(() async {
    db = await openInMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  ChannelRow channelRow(String id, {required DateTime at}) => ChannelRow(
    channelId: id,
    type: ChannelType.direct,
    createdAt: at,
    updatedAt: at,
    unreadCount: 0,
    archived: false,
    pinned: false,
    muted: false,
    lastSequence: 0,
    notificationPreference: 'all',
  );

  test('transaction rolls back entirely on constraint violation', () async {
    final channel = ChannelDao(db);
    final at = DateTime.now();
    await channel.upsertChannel(channelRow('ch-1', at: at));

    await expectLater(
      db.transaction(() async {
        await channel.upsertChannel(channelRow('ch-new', at: at));
        await db.into(db.channels).insert(channelRow('ch-1', at: at));
      }),
      throwsA(isA<SqliteException>()),
    );

    final remaining = await channel.listChannels();
    expect(remaining, hasLength(1));
    expect(remaining.single.channelId, 'ch-1');
  });

  test('transaction aborted mid-way persists nothing', () async {
    final at = DateTime.now();

    await expectLater(
      db.transaction(() async {
        await db.into(db.channels).insert(channelRow('ch-1', at: at));
        throw StateError('simulated crash');
      }),
      throwsStateError,
    );

    expect(await db.select(db.channels).get(), isEmpty);
    expect(await db.select(db.messages).get(), isEmpty);
  });
}
