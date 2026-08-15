import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:onebit/core/crypto/backup/backup_cipher.dart';
import 'package:onebit/core/crypto/backup/backup_format.dart';
import 'package:onebit/core/database/backup/backup_document.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/migration/migration_registry.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';

/// Export/import of the entire database as a single backup document.
///
/// Export: consistent read snapshot → JSON → zlib (when smaller) → optional
/// AES-256-GCM envelope (`BackupCipher`, header bound via AAD).
///
/// Import: structural parse → schema gate → decrypt → integrity check →
/// transactional replace (children-first delete, parents-first insert).
final class DatabaseBackupService {
  DatabaseBackupService({required this._db, required this._logger})
    : _tables = _db.allTables.whereType<TableInfo<Table, Object?>>().toList(
        growable: false,
      );

  final OneBitDatabase _db;
  final AppLogger _logger;

  /// All registered tables; order matches the directory tree and drives both
  /// export and the FK-safe import ordering.
  final List<TableInfo<Table, Object?>> _tables;

  static const String _lastImportKey = 'last_import_at';
  static const String _lastExportKey = 'last_export_at';

  /// Exports the whole database into an `ONEBITDB` document.
  ///
  /// [passphrase] null → plaintext payload; non-null → AES-256-GCM envelope.
  Future<Result<Uint8List>> exportBackup({
    required String nodeId,
    String? passphrase,
    String appVersion = '',
  }) async {
    try {
      final exportedAt = DateTime.now().toUtc();
      final snapshot = await _readSnapshot();

      final packed = await BackupPayload.pack(snapshot.bytes);
      final header = BackupHeader(
        schemaVersion: MigrationRegistry.currentVersion,
        exportedAt: exportedAt.toIso8601String(),
        nodeId: nodeId,
        appVersion: appVersion,
        tableCount: snapshot.tableCount,
        rowCount: snapshot.rowCount,
        integrity: packed.integrity,
        compression: packed.compression,
        encrypted: passphrase != null,
      );

      final Uint8List payload;
      if (passphrase != null) {
        final encrypted = await BackupCipher.encrypt(
          passphrase: passphrase,
          plaintext: <String, Object?>{'payload': _b64(packed.bytes)},
          aad: BackupAad(
            nodeId: nodeId,
            createdAt: exportedAt.toIso8601String(),
          ),
        );
        final envelope = encrypted.fold(
          (value) => value,
          (failure) => throw _FailureInfo(
            operation: 'decrypt',
            message: '$failure',
            cause: failure,
          ),
        );
        payload = BackupFormat.encodeEnvelope(envelope);
      } else {
        payload = packed.bytes;
      }

      final document = BackupDocumentCodec.encode(
        header: header,
        payloadBytes: payload,
      );
      await _db.applicationMetadata.insertOnConflictUpdate(
        MetadataRow(
          key: _lastExportKey,
          value: exportedAt.toIso8601String(),
          updatedAt: DateTime.now(),
        ),
      );
      return Ok(document);
    } on Object catch (error, stackTrace) {
      return Err(_mapFailure(error, stackTrace));
    }
  }

  /// Imports [document], replacing the current database contents.
  ///
  /// [passphrase] must match the export one when the backup is encrypted; a
  /// wrong passphrase fails GCM authentication.
  Future<Result<BackupImportSummary>> importBackup({
    required List<int> document,
    String? passphrase,
  }) async {
    try {
      final parsed = BackupDocumentCodec.decode(document);
      final header = parsed.header;
      if (header.schemaVersion > MigrationRegistry.currentVersion) {
        throw _FailureInfo(
          operation: 'schema',
          message:
              'Backup schema v${header.schemaVersion} is newer than '
              'supported v${MigrationRegistry.currentVersion}',
        );
      }

      final Uint8List uncompressed;
      if (header.encrypted) {
        if (passphrase == null) {
          throw const _FailureInfo(
            operation: 'decrypt',
            message: 'Backup is encrypted but no passphrase was provided',
          );
        }
        final envelope = BackupFormat.decodeEnvelope(parsed.payload);
        final decrypted = await BackupCipher.decrypt(
          passphrase: passphrase,
          envelope: envelope,
        );
        final plaintext = decrypted.fold(
          (value) => value,
          (failure) => throw _FailureInfo(
            operation: 'decrypt',
            message: '$failure',
            cause: failure,
          ),
        );
        final encoded = plaintext['payload'] as String?;
        if (encoded == null) {
          throw const _FailureInfo(
            operation: 'decrypt',
            message: 'Missing payload field',
          );
        }
        uncompressed = await BackupPayload.unpack(
          bytes: _unb64(encoded),
          compression: header.compression,
          integrity: header.integrity,
        );
      } else {
        uncompressed = await BackupPayload.unpack(
          bytes: parsed.payload,
          compression: header.compression,
          integrity: header.integrity,
        );
      }

      final decoded = jsonDecode(utf8.decode(uncompressed));
      if (decoded is! Map) {
        throw const _FailureInfo(
          operation: 'parse',
          message: 'Payload is not an object',
        );
      }
      final tables = decoded.cast<String, Object?>();
      if (tables.length != header.tableCount ||
          !_tables.every((t) => tables.containsKey(t.actualTableName))) {
        throw _FailureInfo(
          operation: 'import',
          message: 'Backup is missing tables (expected ${header.tableCount})',
        );
      }

      var importedRows = 0;
      await _db.transaction(() async {
        await _clear();
        importedRows = await _insertAll(tables);
        await _db.applicationMetadata.insertOnConflictUpdate(
          MetadataRow(
            key: _lastImportKey,
            value: DateTime.now().toUtc().toIso8601String(),
            updatedAt: DateTime.now(),
          ),
        );
      });
      if (importedRows != header.rowCount) {
        throw _FailureInfo(
          operation: 'import',
          message: 'Expected ${header.rowCount} rows, imported $importedRows',
        );
      }

      final summary = BackupImportSummary(
        nodeId: header.nodeId,
        exportedAt: DateTime.parse(header.exportedAt),
        schemaVersion: header.schemaVersion,
        tableCount: header.tableCount,
        rowCount: header.rowCount,
        importedAt: DateTime.now(),
      );
      _logger.info(
        'Backup imported (rows=${summary.rowCount}, schema=${summary.schemaVersion})',
        tag: LogTags.storage,
      );
      return Ok(summary);
    } on Object catch (error, stackTrace) {
      return Err(_mapFailure(error, stackTrace));
    }
  }

  // ---- Export helpers -----------------------------------------------------------

  Future<({List<int> bytes, int tableCount, int rowCount})>
  _readSnapshot() async {
    final map = <String, Object?>{};
    var rowCount = 0;
    await _db.transaction(() async {
      for (final table in _tables) {
        final tableName = table.actualTableName;
        final rows = await _db.select(table).get();
        map[tableName] = rows
            .map((row) => (row as dynamic).toJson() as Map<String, Object?>)
            .toList();
        rowCount += rows.length;
      }
    });
    return (
      bytes: utf8.encode(jsonEncode(map)),
      tableCount: _tables.length,
      rowCount: rowCount,
    );
  }

  /// Deletes children before parents so FK constraints are satisfied.
  Future<void> _clear() async {
    for (final table in _tables.reversed) {
      await _db.delete(table).go();
    }
  }

  /// Inserts rows parents-first (reverse of [_clear]) with
  /// `insertOnConflictUpdate` semantics for idempotent restores.
  Future<int> _insertAll(Map<String, Object?> tables) async {
    var rowCount = 0;
    await _db.batch((batch) {
      for (final table in _tables) {
        final jsonList = tables[table.actualTableName];
        if (jsonList is! List) {
          continue;
        }
        final rows = jsonList.map((json) {
          if (json is! Map) {
            throw const FormatException('Row is not an object');
          }
          return _rowFromJson(table, json.cast<String, Object?>());
        }).toList();
        if (rows.isNotEmpty) {
          batch.insertAllOnConflictUpdate(
            table,
            rows.cast<Insertable<Object?>>(),
          );
          rowCount += rows.length;
        }
      }
    });
    return rowCount;
  }

  Object? _rowFromJson(
    TableInfo<Table, Object?> table,
    Map<String, Object?> json,
  ) {
    if (table == _db.identity) return IdentityRow.fromJson(json);
    if (table == _db.trustedNodes) return TrustedNodeRow.fromJson(json);
    if (table == _db.nodeProfiles) return NodeProfileRow.fromJson(json);
    if (table == _db.channels) return ChannelRow.fromJson(json);
    if (table == _db.typingEvents) return TypingEventRow.fromJson(json);
    if (table == _db.messages) return MessageRow.fromJson(json);
    if (table == _db.attachments) return AttachmentRow.fromJson(json);
    if (table == _db.voiceNotes) return VoiceNoteRow.fromJson(json);
    if (table == _db.deliveryReceipts) return DeliveryReceiptRow.fromJson(json);
    if (table == _db.readReceipts) return ReadReceiptRow.fromJson(json);
    if (table == _db.packets) return PacketRow.fromJson(json);
    if (table == _db.packetFragments) return PacketFragmentRow.fromJson(json);
    if (table == _db.routes) return RouteRow.fromJson(json);
    if (table == _db.neighbors) return NeighborRow.fromJson(json);
    if (table == _db.sessions) return SessionRow.fromJson(json);
    if (table == _db.sessionKeys) return SessionKeyRow.fromJson(json);
    if (table == _db.pendingQueue) return PendingQueueRow.fromJson(json);
    if (table == _db.retryQueue) return RetryQueueRow.fromJson(json);
    if (table == _db.relayQueue) return RelayQueueRow.fromJson(json);
    if (table == _db.settings) return SettingRow.fromJson(json);
    if (table == _db.applicationMetadata) return MetadataRow.fromJson(json);
    if (table == _db.logs) return LogRow.fromJson(json);
    if (table == _db.diagnostics) return DiagnosticRow.fromJson(json);
    if (table == _db.developerEvents) return DeveloperEventRow.fromJson(json);
    if (table == _db.statistics) return StatisticRow.fromJson(json);
    throw const FormatException('Unknown table in backup');
  }

  // ---- Failure mapping -----------------------------------------------------------

  BackupFailure _mapFailure(Object error, StackTrace stackTrace) {
    if (error is _FailureInfo) {
      return BackupFailure(
        operation: error.operation,
        message: error.message,
        cause: error.cause ?? error,
        stackTrace: stackTrace,
      );
    }
    if (error is BackupFailure) {
      return error;
    }
    return BackupFailure(
      operation: 'backup',
      message: error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }

  static String _b64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _unb64(String encoded) {
    final padding = (4 - encoded.length % 4) % 4;
    return Uint8List.fromList(
      base64Url.decode(encoded.padRight(encoded.length + padding, '=')),
    );
  }
}

/// Internal marker carrying a precise backup phase for error mapping.
final class _FailureInfo implements Exception {
  const _FailureInfo({
    required this.operation,
    required this.message,
    this.cause,
  });

  final String operation;
  final String message;
  final Object? cause;

  @override
  String toString() => '$operation: $message';
}
