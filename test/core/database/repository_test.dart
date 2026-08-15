import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/cache/channel_cache.dart';
import 'package:onebit/core/database/cache/settings_cache.dart';
import 'package:onebit/core/database/dao/channel_dao.dart';
import 'package:onebit/core/database/dao/settings_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/channel_repository.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/database/repository/settings_repository.dart';
import 'package:onebit/core/database/tables/enums.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';

import 'support/database_support.dart';

void main() {
  late OneBitDatabase db;
  late ChannelRepository channels;
  late SettingsRepository settings;

  final now = DateTime.now();

  ChannelRow channelRow(String id) => ChannelRow(
    channelId: id,
    type: ChannelType.direct,
    createdAt: now,
    updatedAt: now,
    unreadCount: 0,
    archived: false,
    pinned: false,
    muted: false,
    lastSequence: 0,
    notificationPreference: 'all',
  );

  setUp(() async {
    db = await openInMemoryDb();
    channels = ChannelRepository(
      dao: ChannelDao(db),
      cache: ChannelCache(),
      logger: silentLogger,
    );
    settings = SettingsRepository(
      dao: SettingsDao(db),
      cache: SettingsCache(),
      logger: silentLogger,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('repository result boundary', () {
    test('writes return Ok and reads reflect them', () async {
      final written = await channels.upsertChannel(channelRow('ch-1'));
      expect(written, isA<Ok<int>>());
      expect(written.fold((v) => v, (_) => fail('unexpected Err')), 1);

      final read = await channels.getChannel('ch-1');
      expect(
        read.fold((row) => row!.channelId, (_) => fail('unexpected Err')),
        'ch-1',
      );
    });

    test(
      'read-through caching serves a second read without a DB hit',
      () async {
        await channels.upsertChannel(channelRow('ch-1'));
        await channels.getChannel('ch-1');

        await db.close();
        // The cached row survives the connection being torn down.
        final cached = await channels.getChannel('ch-1');
        expect(
          cached.fold((row) => row!.channelId, (_) => fail('unexpected Err')),
          'ch-1',
        );
      },
    );

    test('settings cache refreshes on write', () async {
      final first = await settings.getSettingValue('theme');
      expect(first.fold((v) => v, (_) => fail('unexpected Err')), isNull);

      await settings.setSetting('theme', 'dark');
      final after = await settings.getSettingValue('theme');
      expect(after.fold((v) => v, (_) => fail('unexpected Err')), 'dark');
    });

    test('failures map to Err(StorageFailure)', () async {
      final result = await ResultGuards.guard<String?>(
        silentLogger,
        'settings.dao.getSettingValue',
        () async => throw StateError('boom'),
      );
      expect(result, isA<Err<String?>>());
      final failure =
          result.fold((_) => fail('unexpected Ok'), (f) => f) as StorageFailure;
      expect(failure, isA<StorageFailure>());
      expect(failure.operation, contains('getSettingValue'));
    });

    test('watch streams emit Ok events', () async {
      final events = <Result<List<ChannelRow>>>[];
      final subscription = channels.watchChannels().listen(events.add);
      await channels.upsertChannel(channelRow('ch-1'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await subscription.cancel();

      expect(events, isNotEmpty);
      expect(events.first, isA<Ok<List<ChannelRow>>>());
    });
  });
}
