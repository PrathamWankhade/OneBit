import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/dao/channel_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/migration/migration_registry.dart';
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

  group('schema', () {
    const expectedTables = <String>{
      'identity',
      'trusted_nodes',
      'node_profiles',
      'channels',
      'typing_events',
      'messages',
      'attachments',
      'voice_notes',
      'delivery_receipts',
      'read_receipts',
      'packets',
      'packet_fragments',
      'routes',
      'neighbors',
      'sessions',
      'session_keys',
      'pending_queue',
      'retry_queue',
      'relay_queue',
      'settings',
      'application_metadata',
      'logs',
      'diagnostics',
      'developer_events',
      'statistics',
    };

    test('creates all 25 tables', () async {
      final result = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final names = result.map((row) => row.read<String>('name')).toSet();
      expect(
        names.containsAll(expectedTables),
        isTrue,
        reason: 'missing: ${expectedTables.difference(names)}',
      );
    });

    test('schemaVersion matches MigrationRegistry', () {
      expect(db.schemaVersion, MigrationRegistry.currentVersion);
    });

    test('deleting a channel cascades its messages and attachments', () async {
      final channelDao = ChannelDao(db);
      final now = DateTime.now();

      await channelDao.upsertChannel(
        ChannelRow(
          channelId: 'ch-1',
          type: ChannelType.direct,
          createdAt: now,
          updatedAt: now,
          unreadCount: 0,
          archived: false,
          pinned: false,
          muted: false,
          lastSequence: 0,
          notificationPreference: 'all',
        ),
      );

      final inserted = await db
          .into(db.messages)
          .insert(
            MessagesCompanion.insert(
              messageId: 'm-1',
              channelId: 'ch-1',
              sender: 'node-a',
              timestamp: now,
              encryptedPayload: Uint8List.fromList([1, 2, 3]),
              messageType: MessageType.text,
            ),
          );
      expect(inserted, 1);

      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              attachmentId: 'a-1',
              messageId: 'm-1',
              kind: AttachmentKind.file,
              createdAt: now,
            ),
          );

      await channelDao.deleteChannel('ch-1');

      expect(await db.select(db.messages).get(), isEmpty);
      expect(await db.select(db.attachments).get(), isEmpty);
    });

    test('identity uuid is unique', () async {
      final row = IdentityRow(
        nodeId: 'node-1',
        uuid: 'same-uuid',
        displayName: 'Alice',
        publicKey: Uint8List.fromList([1]),
        fingerprint: 'fp-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: 1,
      );
      await db.into(db.identity).insert(row);
      await expectLater(
        db
            .into(db.identity)
            .insert(
              IdentityRow(
                nodeId: 'node-2',
                uuid: 'same-uuid',
                displayName: 'Bob',
                publicKey: Uint8List.fromList([2]),
                fingerprint: 'fp-2',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                version: 1,
              ),
            ),
        throwsA(isA<Object>()),
      );
    });
  });
}
