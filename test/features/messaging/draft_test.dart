import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_channel_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_draft_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_type.dart';
import 'package:onebit/features/messaging/domain/drafts/draft.dart';

import 'support/messaging_node.dart' show pumpUntil;
import 'support/messaging_support.dart';

void main() {
  group('SqliteDraftRepository', () {
    late OneBitDatabase db;
    late SqliteDraftRepository repo;
    late String channelId;

    setUp(() async {
      db = await openInMemoryDb();
      repo = SqliteDraftRepository(db: db, logger: silentLogger);
      // Drafts reference the Channels table (FK enforced), so every draft
      // lives under a real channel row.
      final channels = SqliteChannelRepository(
        db: db,
        localNodeId: 'node-a',
        logger: silentLogger,
      );
      channelId = (await channels.create(
        const CreateChannelParams(type: ChannelType.private, peer: 'node-b'),
      )).value!.channelId;
    });

    tearDown(() => db.close());

    test('persists, restores and overwrites a draft', () async {
      final result = await repo.save(
        Draft(channelId: channelId, body: 'hello draft'),
      );
      expect(result.isOk, isTrue);

      final loaded = (await repo.load(channelId)).value!;
      expect(loaded.body, 'hello draft');

      await repo.save(Draft(channelId: channelId, body: 'edited draft'));
      expect((await repo.load(channelId)).value!.body, 'edited draft');
    });

    test('load returns null when absent', () async {
      expect((await repo.load(channelId)).value, isNull);
    });

    test('supports long messages', () async {
      final longBody = List.filled(16 * 1024, 'x').join();
      await repo.save(Draft(channelId: channelId, body: longBody));
      expect((await repo.load(channelId)).value!.body.length, longBody.length);
    });

    test('keeps one draft per channel', () async {
      await repo.save(Draft(channelId: channelId, body: 'one'));
      await repo.save(Draft(channelId: channelId, body: 'two'));
      final all = (await repo.listAll()).value!;
      expect(all.where((d) => d.channelId == channelId), hasLength(1));
    });

    test('records edit target and deletes cleanly', () async {
      await repo.save(
        Draft(channelId: channelId, body: 'edit me', editingMessageId: 'm-7'),
      );
      final draft = (await repo.load(channelId)).value!;
      expect(draft.editingMessageId, 'm-7');
      await repo.delete(channelId);
      expect((await repo.load(channelId)).value, isNull);
      expect((await repo.listAll()).value, isEmpty);
    });

    test('watch emits null then the saved draft', () async {
      // drift watch() delivers its initial snapshot asynchronously, so we
      // collect all events and assert the sequence, never the timing.
      final events = <Result<Draft?>>[];
      final sub = repo.watch(channelId).listen(events.add);
      await repo.save(Draft(channelId: channelId, body: 'now I exist'));
      await pumpUntil(
        () => events.isNotEmpty && events.last.value?.body != null,
      );
      await sub.cancel();
      expect(events.first.value, isNull);
      expect(events.last.value!.body, 'now I exist');
    });
  });
}
