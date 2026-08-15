import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/backup/backup_document.dart';
import 'package:onebit/core/database/backup/backup_service.dart';
import 'package:onebit/core/database/dao/channel_dao.dart';
import 'package:onebit/core/database/dao/message_dao.dart';
import 'package:onebit/core/database/dao/settings_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/migration/migration_registry.dart';
import 'package:onebit/core/database/tables/enums.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';

import 'support/database_support.dart';

void main() {
  final now = DateTime.now();

  Future<OneBitDatabase> seed({OneBitDatabase? db}) async {
    final database = db ?? await openInMemoryDb();
    final channel = ChannelDao(database);
    final message = MessageDao(database);
    final settings = SettingsDao(database);

    await channel.upsertChannel(
      ChannelRow(
        channelId: 'ch-1',
        type: ChannelType.direct,
        createdAt: now,
        updatedAt: now,
        unreadCount: 2,
        archived: false,
        pinned: false,
        muted: false,
        lastSequence: 4,
        notificationPreference: 'all',
      ),
    );
    await message.insertMessage(
      MessageRow(
        messageId: 'm-1',
        channelId: 'ch-1',
        sender: 'node-a',
        timestamp: now,
        encryptedPayload: Uint8List.fromList([1, 2, 3]),
        messageType: MessageType.text,
        status: MessageStatus.delivered,
        forwarded: false,
        edited: false,
        deleted: false,
        priority: PriorityLevel.normal,
        version: 1,
        sequence: 1,
        packetOrder: 0,
        attemptCount: 0,
        verified: false,
        starred: false,
      ),
    );
    await settings.setSetting('theme', 'dark');
    return database;
  }

  DatabaseBackupService serviceFor(OneBitDatabase db) =>
      DatabaseBackupService(db: db, logger: silentLogger);

  group('backup document codec', () {
    test('round-trips a header', () {
      final header = BackupHeader(
        schemaVersion: 1,
        exportedAt: '2026-01-01T00:00:00.000Z',
        nodeId: 'NODE-TEST',
        appVersion: '1.0.0',
        tableCount: 25,
        rowCount: 4,
        integrity: 'a' * 64,
      );
      final doc = BackupDocumentCodec.encode(
        header: header,
        payloadBytes: Uint8List.fromList([9, 8, 7]),
      );
      final parsed = BackupDocumentCodec.decode(doc);
      expect(parsed.header.schemaVersion, 1);
      expect(parsed.header.tableCount, 25);
      expect(parsed.payload, [9, 8, 7]);
    });

    test('rejects bad magic', () {
      final bogus = Uint8List.fromList(List.filled(20, 1));
      expect(() => BackupDocumentCodec.decode(bogus), throwsFormatException);
    });
  });

  group('export/import', () {
    test('plaintext round-trip restores all rows', () async {
      final source = await seed();
      final exported = await serviceFor(
        source,
      ).exportBackup(nodeId: 'NODE-A', appVersion: 'test');
      final document = exported.fold((v) => v, (f) => fail('$f'));
      expect(document, isNotEmpty);

      final target = await openInMemoryDb();
      final imported = await serviceFor(
        target,
      ).importBackup(document: document);
      final summary = imported.fold((v) => v, (f) => fail('$f'));
      expect(summary.rowCount, 3);
      expect(summary.nodeId, 'NODE-A');
      expect(summary.schemaVersion, MigrationRegistry.currentVersion);

      final settings = SettingsDao(target);
      expect(await settings.getSettingValue('theme'), 'dark');
      final channel = ChannelDao(target);
      expect((await channel.getChannel('ch-1'))!.unreadCount, 2);

      await source.close();
      await target.close();
    });

    test('passphrase round-trip', () async {
      final source = await seed();
      final exported = await serviceFor(
        source,
      ).exportBackup(nodeId: 'NODE-A', passphrase: 'hunter2');
      final document = exported.fold((v) => v, (f) => fail('$f'));

      final target = await openInMemoryDb();
      final imported = await serviceFor(
        target,
      ).importBackup(document: document, passphrase: 'hunter2');
      expect(imported.isOk, isTrue);
      await source.close();
      await target.close();
    });

    test('wrong passphrase fails GCM authentication', () async {
      final source = await seed();
      final exported = await serviceFor(
        source,
      ).exportBackup(nodeId: 'NODE-A', passphrase: 'correct');
      final document = exported.fold((v) => v, (f) => fail('$f'));

      final target = await openInMemoryDb();
      final imported = await serviceFor(
        target,
      ).importBackup(document: document, passphrase: 'wrong');
      expect(imported, isA<Err<BackupImportSummary>>());
      expect(imported.failure, isA<BackupFailure>());
      await source.close();
      await target.close();
    });

    test('missing passphrase for encrypted backup is rejected', () async {
      final source = await seed();
      final exported = await serviceFor(
        source,
      ).exportBackup(nodeId: 'NODE-A', passphrase: 'secret');
      final document = exported.fold((v) => v, (f) => fail('$f'));

      final target = await openInMemoryDb();
      final imported = await serviceFor(
        target,
      ).importBackup(document: document);
      expect(imported.isErr, isTrue);
      await source.close();
      await target.close();
    });

    test('tampered payload fails the integrity check', () async {
      final source = await seed();
      final exported = await serviceFor(
        source,
      ).exportBackup(nodeId: 'NODE-A', appVersion: 'test');
      final document = exported.fold((v) => v, (f) => fail('$f'));

      final tampered = Uint8List.fromList(document);
      tampered[tampered.length ~/ 2] ^= 0xFF;

      final target = await openInMemoryDb();
      final imported = await serviceFor(
        target,
      ).importBackup(document: tampered);
      expect(imported.isErr, isTrue);
      await source.close();
      await target.close();
    });

    test('newer schema version is rejected', () async {
      final source = await seed();
      final exported = await serviceFor(
        source,
      ).exportBackup(nodeId: 'NODE-A', appVersion: 'test');
      final document = exported.fold((v) => v, (f) => fail('$f'));

      // Rewrite the header to claim a schema version newer than the app.
      final text = String.fromCharCodes(document);
      final headerEnd = text.indexOf('\n');
      final headerJson = text.substring(9, headerEnd);
      final patched = headerJson.replaceFirst(
        '"schema":${MigrationRegistry.currentVersion}',
        '"schema":${MigrationRegistry.currentVersion + 1}',
      );
      final rebuilt = Uint8List.fromList([
        ...document.sublist(0, 9),
        ...patched.codeUnits,
        0x0A,
        ...document.sublist(headerEnd + 1),
      ]);

      final target = await openInMemoryDb();
      final imported = await serviceFor(target).importBackup(document: rebuilt);
      expect(imported.isErr, isTrue);
      final failure = imported.failure! as BackupFailure;
      expect(failure.operation, 'schema');
      await source.close();
      await target.close();
    });

    test('import replaces existing rows', () async {
      final source = await seed();
      final exported = await serviceFor(
        source,
      ).exportBackup(nodeId: 'NODE-A', appVersion: 'test');
      final document = exported.fold((v) => v, (f) => fail('$f'));

      final target = await seed();
      final settings = SettingsDao(target);
      await settings.setSetting('stale_key', 'value');

      final imported = await serviceFor(
        target,
      ).importBackup(document: document);
      expect(imported.isOk, isTrue);
      expect(await settings.getSettingValue('stale_key'), isNull);
      expect(await settings.getSettingValue('theme'), 'dark');
      await source.close();
      await target.close();
    });
  });
}
