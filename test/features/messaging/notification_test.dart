import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_notification_repository.dart';
import 'package:onebit/features/messaging/domain/notifications/notification.dart';

import 'support/messaging_support.dart';

void main() {
  group('SqliteNotificationRepository', () {
    late OneBitDatabase db;
    late SqliteNotificationRepository repo;

    setUp(() async {
      db = await openInMemoryDb();
      repo = SqliteNotificationRepository(db: db, logger: silentLogger);
    });

    tearDown(() => db.close());

    test('pushes and pages events newest-first', () async {
      await repo.push(
        NotificationEvent(
          kind: NotificationKind.messageReceived,
          createdAt: DateTime(2026, 1, 1, 10),
        ),
      );
      await repo.push(
        NotificationEvent(
          kind: NotificationKind.messageRead,
          createdAt: DateTime(2026, 1, 1, 11),
        ),
      );
      final page = (await repo.page()).value!;
      expect(page.items, hasLength(2));
      expect(page.items.first.kind, NotificationKind.messageRead);
    });

    test('preserves payloads and routing fields', () async {
      await repo.push(
        NotificationEvent(
          kind: NotificationKind.messageDelivered,
          channelId: 'c1',
          messageId: 'm-1',
          node: 'node-b',
          title: 'delivered',
          body: 'm-1',
          payload: {'count': 3},
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      final event = (await repo.page()).value!.items.single;
      expect(event.channelId, 'c1');
      expect(event.messageId, 'm-1');
      expect(event.node, 'node-b');
      expect(event.payload['count'], 3);
    });

    test('watch streams every pushed event', () async {
      final stream = repo.watch();
      final kinds = <NotificationKind>[];
      final sub = stream.listen((r) {
        if (r.value != null) kinds.add(r.value!.kind);
      });
      await repo.push(
        const NotificationEvent(kind: NotificationKind.messageEnqueued),
      );
      await repo.push(
        const NotificationEvent(kind: NotificationKind.messageFailed),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      // Each watch emission is a full snapshot (newest first), so a pushed
      // event may reappear in later snapshots. What matters: both kinds were
      // delivered.
      expect(kinds.toSet(), {
        NotificationKind.messageEnqueued,
        NotificationKind.messageFailed,
      });
    });

    test('clearAll empties the log', () async {
      await repo.push(const NotificationEvent(kind: NotificationKind.system));
      await repo.clearAll();
      expect((await repo.page()).value!.items, isEmpty);
    });
  });
}
