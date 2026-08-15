import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/media_tables.dart';

part 'media_dao.g.dart';

/// Typed persistence for the Phase 9 media subsystem.
///
/// All repository I/O funnels through this accessor. Chunk bitmap
/// transitions run inside `transaction()` so `bytesTransferred` and the
/// bitmap can never disagree. Enums are stored via the shared core
/// vocabulary (`tables/enums.dart`) as stable name strings.
@DriftAccessor(
  tables: [
    MediaAttachments,
    TransferSessions,
    TransferChunks,
    MediaThumbnails,
    MediaPreviews,
    VoiceRecordings,
    CacheEntries,
    MediaStatistics,
  ],
)
final class MediaDao extends DatabaseAccessor<OneBitDatabase>
    with _$MediaDaoMixin {
  MediaDao(super.db);

  // ---------------------------------------------------------------------
  // Attachments
  // ---------------------------------------------------------------------

  Future<void> insertAttachment(MediaAttachmentsCompanion row) =>
      into(mediaAttachments).insert(row);

  Future<MediaAttachmentRow?> attachmentRow(String attachmentId) => (select(
    mediaAttachments,
  )..where((t) => t.attachmentId.equals(attachmentId))).getSingleOrNull();

  /// First catalog row carrying [sha256] (duplicate detection).
  Future<MediaAttachmentRow?> attachmentBySha256(String sha256) => (select(
    mediaAttachments,
  )..where((t) => t.sha256.equals(sha256))).getSingleOrNull();

  Future<List<MediaAttachmentRow>> attachmentsForMessage(String messageId) {
    final query = select(mediaAttachments)
      ..where((t) => t.messageId.equals(messageId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  Stream<List<MediaAttachmentRow>> watchAttachmentsForMessage(
    String messageId,
  ) {
    final query = select(mediaAttachments)
      ..where((t) => t.messageId.equals(messageId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch();
  }

  Future<List<MediaAttachmentRow>> attachmentsByCategory(
    MediaCategory category,
  ) {
    final query = select(mediaAttachments)
      ..where((t) => t.category.equals(category.name))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  Future<void> updateAttachment(MediaAttachmentsCompanion row) => (update(
    mediaAttachments,
  )..where((t) => t.attachmentId.equals(row.attachmentId.value))).write(row);

  Future<void> deleteAttachment(String attachmentId) => (delete(
    mediaAttachments,
  )..where((t) => t.attachmentId.equals(attachmentId))).go();

  Future<List<MediaAttachmentRow>> purgeAttachmentsBefore(
    DateTime cutoff, {
    int limit = 500,
  }) async {
    final doomed =
        await (select(mediaAttachments)
              ..where(
                (t) => t.createdAt.isSmallerThanValue(
                  cutoff.millisecondsSinceEpoch,
                ),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
              ..limit(limit))
            .get();
    for (final row in doomed) {
      await purgeAttachment(row.attachmentId);
    }
    return doomed;
  }

  /// Per-category count and total bytes for the storage budget.
  Future<List<MediaSummaryAggregate>> summary() async {
    final rows = await select(mediaAttachments).get();
    final byCategory = <MediaCategory, (int, int)>{};
    for (final row in rows) {
      final (count, bytes) = byCategory[row.category] ?? (0, 0);
      byCategory[row.category] = (count + 1, bytes + row.sizeBytes);
    }
    return [
      for (final entry in byCategory.entries)
        MediaSummaryAggregate(
          category: entry.key,
          count: entry.value.$1,
          bytes: entry.value.$2,
        ),
    ];
  }

  // ---------------------------------------------------------------------
  // Transfer sessions
  // ---------------------------------------------------------------------

  Future<void> insertSession(TransferSessionsCompanion row) =>
      into(transferSessions).insert(row);

  /// Inserts the session row AND its chunk ledger in one transaction.
  Future<void> insertSessionWithChunks(
    TransferSessionsCompanion session,
    List<TransferChunksCompanion> chunks,
  ) => transaction(() async {
    await into(transferSessions).insert(session);
    await batch((b) => b.insertAll(transferChunks, chunks));
  });

  Future<TransferSessionRow?> sessionRow(String sessionId) => (select(
    transferSessions,
  )..where((t) => t.sessionId.equals(sessionId))).getSingleOrNull();

  Future<void> updateSession(TransferSessionsCompanion row) => (update(
    transferSessions,
  )..where((t) => t.sessionId.equals(row.sessionId.value))).write(row);

  Future<List<TransferSessionRow>> sessionsForAttachment(String attachmentId) {
    final query = select(transferSessions)
      ..where((t) => t.attachmentId.equals(attachmentId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  Future<List<TransferSessionRow>> activeSessions() {
    final active = TransferState.values
        .where(
          (s) =>
              s != TransferState.completed &&
              s != TransferState.failed &&
              s != TransferState.cancelled &&
              s != TransferState.expired,
        )
        .map((s) => s.name);
    final query = select(transferSessions)
      ..where((t) => t.state.isIn(active))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.get();
  }

  Future<List<TransferSessionRow>> purgeSessionsBefore(
    DateTime cutoff, {
    int limit = 200,
  }) async {
    final doomed =
        await (select(transferSessions)
              ..where(
                (t) => t.updatedAt.isSmallerThanValue(
                  cutoff.millisecondsSinceEpoch,
                ),
              )
              ..where((t) => t.state.isIn(TransferState.terminalNames))
              ..orderBy([(t) => OrderingTerm.asc(t.updatedAt)])
              ..limit(limit))
            .get();
    for (final row in doomed) {
      await deleteChunksForSession(row.sessionId);
      await (delete(
        transferSessions,
      )..where((t) => t.sessionId.equals(row.sessionId))).go();
    }
    return doomed;
  }

  Stream<TransferSessionRow?> watchSession(String sessionId) {
    final query = select(transferSessions)
      ..where((t) => t.sessionId.equals(sessionId));
    return query.watchSingleOrNull();
  }

  // ---------------------------------------------------------------------
  // Transfer chunks
  // ---------------------------------------------------------------------

  Future<void> insertChunk(TransferChunksCompanion row) =>
      into(transferChunks).insert(row);

  Future<TransferChunkRow?> chunkRow(String sessionId, int index) =>
      (select(transferChunks)..where(
            (t) => t.sessionId.equals(sessionId) & t.index.equals(index),
          ))
          .getSingleOrNull();

  Future<List<TransferChunkRow>> chunkRowsForSession(String sessionId) {
    final query = select(transferChunks)
      ..where((t) => t.sessionId.equals(sessionId))
      ..orderBy([(t) => OrderingTerm.asc(t.index)]);
    return query.get();
  }

  Future<void> updateChunk(TransferChunksCompanion row) =>
      (update(transferChunks)..where(
            (t) =>
                t.sessionId.equals(row.sessionId.value) &
                t.index.equals(row.index.value),
          ))
          .write(row);

  /// Marks chunk [index] acked/received — bitmap, `bytesTransferred` and
  /// the chunk row update in one transaction (they can never disagree).
  Future<void> markChunkBit(String sessionId, int index) =>
      transaction(() async {
        final session = await sessionRow(sessionId);
        final chunk = await chunkRow(sessionId, index);
        if (session == null || chunk == null) return;
        final bitmap = _markBit(session.chunksBitmap, index);
        final chunks = await chunkRowsForSession(sessionId);
        var bytes = 0;
        for (final row in chunks) {
          if (_isBitSet(bitmap, row.index)) bytes += row.sizeBytes;
        }
        await (update(
          transferSessions,
        )..where((t) => t.sessionId.equals(sessionId))).write(
          TransferSessionsCompanion(
            chunksBitmap: Value(bitmap),
            bytesTransferred: Value(bytes),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await (update(transferChunks)..where(
              (t) => t.sessionId.equals(sessionId) & t.index.equals(index),
            ))
            .write(
              TransferChunksCompanion(
                state: const Value(ChunkState.acknowledged),
                ackedAt: Value(DateTime.now()),
              ),
            );
      });

  Future<void> updateChunkState(
    String sessionId,
    int index,
    ChunkState state, {
    int? attempts,
    DateTime? sentAt,
    DateTime? ackedAt,
  }) =>
      (update(transferChunks)..where(
            (t) => t.sessionId.equals(sessionId) & t.index.equals(index),
          ))
          .write(
            TransferChunksCompanion(
              state: Value(state),
              attempts: attempts != null
                  ? Value(attempts)
                  : const Value.absent(),
              sentAt: sentAt != null ? Value(sentAt) : const Value.absent(),
              ackedAt: ackedAt != null ? Value(ackedAt) : const Value.absent(),
            ),
          );

  Future<void> setChunkHash(String sessionId, int index, String sha256) =>
      (update(transferChunks)..where(
            (t) => t.sessionId.equals(sessionId) & t.index.equals(index),
          ))
          .write(TransferChunksCompanion(sha256: Value(sha256)));

  /// Every session row (bounded) — statistics + maintenance scans.
  Future<List<TransferSessionRow>> allSessions({int limit = 5000}) =>
      (select(transferSessions)..limit(limit)).get();

  Future<int> sessionCount() => _countRows(transferSessions);

  Future<int> chunkCount() => _countRows(transferChunks);

  Future<int> _countRows<T extends Table, D>(TableInfo<T, D> table) async {
    final query = selectOnly(table)..addColumns([countAll()]);
    final row = await query.getSingle();
    return row.read(countAll()) ?? 0;
  }

  /// Big-endian packing (MSB of byte 0 = bit 0), matching the domain
  /// bitmap; new bits must not exceed `ceil(n/8)` bytes.
  static Uint8List _markBit(List<int> bytes, int index) {
    final packed = Uint8List.fromList(bytes);
    while ((packed.length << 3) <= index) {
      packed.add(0);
    }
    packed[index >> 3] |= 1 << (7 - (index & 7));
    return packed;
  }

  static bool _isBitSet(List<int> bytes, int index) {
    final byte = index >> 3;
    if (byte >= bytes.length) return false;
    return bytes[byte] & (1 << (7 - (index & 7))) != 0;
  }

  Future<void> deleteChunksForSession(String sessionId) => (delete(
    transferChunks,
  )..where((t) => t.sessionId.equals(sessionId))).go();

  Future<void> deleteChunk(String sessionId, int index) => (delete(
    transferChunks,
  )..where((t) => t.sessionId.equals(sessionId) & t.index.equals(index))).go();

  // ---------------------------------------------------------------------
  // Thumbnails
  // ---------------------------------------------------------------------

  Future<void> insertThumbnail(MediaThumbnailsCompanion row) =>
      into(mediaThumbnails).insert(row);

  Future<MediaThumbnailRow?> thumbnailRow(String thumbnailId) => (select(
    mediaThumbnails,
  )..where((t) => t.thumbnailId.equals(thumbnailId))).getSingleOrNull();

  Future<MediaThumbnailRow?> thumbnailForAttachment(String attachmentId) =>
      (select(mediaThumbnails)
            ..where((t) => t.attachmentId.equals(attachmentId))
            ..orderBy([(t) => OrderingTerm.desc(t.generatedAt)])
            ..limit(1))
          .getSingleOrNull();

  Stream<MediaThumbnailRow?> watchThumbnailForAttachment(String attachmentId) {
    final query = select(mediaThumbnails)
      ..where((t) => t.attachmentId.equals(attachmentId))
      ..orderBy([(t) => OrderingTerm.desc(t.generatedAt)])
      ..limit(1);
    return query.watchSingleOrNull();
  }

  Future<void> deleteThumbnail(String thumbnailId) => (delete(
    mediaThumbnails,
  )..where((t) => t.thumbnailId.equals(thumbnailId))).go();

  Future<void> deleteThumbnailsForAttachment(String attachmentId) => (delete(
    mediaThumbnails,
  )..where((t) => t.attachmentId.equals(attachmentId))).go();

  Future<List<MediaThumbnailRow>> purgeThumbnailsBefore(
    DateTime cutoff, {
    int limit = 500,
  }) async {
    final doomed =
        await (select(mediaThumbnails)
              ..where(
                (t) => t.generatedAt.isSmallerThanValue(
                  cutoff.millisecondsSinceEpoch,
                ),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.generatedAt)])
              ..limit(limit))
            .get();
    for (final row in doomed) {
      await (delete(
        mediaThumbnails,
      )..where((t) => t.thumbnailId.equals(row.thumbnailId))).go();
    }
    return doomed;
  }

  // ---------------------------------------------------------------------
  // Previews
  // ---------------------------------------------------------------------

  Future<void> insertPreview(MediaPreviewsCompanion row) =>
      into(mediaPreviews).insert(row);

  Future<MediaPreviewRow?> previewRow(String previewId) => (select(
    mediaPreviews,
  )..where((t) => t.previewId.equals(previewId))).getSingleOrNull();

  Future<MediaPreviewRow?> previewForAttachment(String attachmentId) => (select(
    mediaPreviews,
  )..where((t) => t.attachmentId.equals(attachmentId))).getSingleOrNull();

  Future<void> deletePreview(String previewId) =>
      (delete(mediaPreviews)..where((t) => t.previewId.equals(previewId))).go();

  Future<void> deletePreviewsForAttachment(String attachmentId) => (delete(
    mediaPreviews,
  )..where((t) => t.attachmentId.equals(attachmentId))).go();

  // ---------------------------------------------------------------------
  // Voice recordings
  // ---------------------------------------------------------------------

  Future<void> insertVoiceRecording(VoiceRecordingsCompanion row) =>
      into(voiceRecordings).insert(row);

  Future<VoiceRecordingRow?> voiceRecordingRow(String voiceNoteId) => (select(
    voiceRecordings,
  )..where((t) => t.voiceNoteId.equals(voiceNoteId))).getSingleOrNull();

  Future<List<VoiceRecordingRow>> voiceRecordingsForMessage(String messageId) {
    final query = select(voiceRecordings)
      ..where((t) => t.messageId.equals(messageId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  Stream<VoiceRecordingRow?> watchVoiceRecording(String voiceNoteId) {
    final query = select(voiceRecordings)
      ..where((t) => t.voiceNoteId.equals(voiceNoteId));
    return query.watchSingleOrNull();
  }

  Future<void> updateVoiceRecording(VoiceRecordingsCompanion row) => (update(
    voiceRecordings,
  )..where((t) => t.voiceNoteId.equals(row.voiceNoteId.value))).write(row);

  Future<void> deleteVoiceRecording(String voiceNoteId) => (delete(
    voiceRecordings,
  )..where((t) => t.voiceNoteId.equals(voiceNoteId))).go();

  // ---------------------------------------------------------------------
  // Cache entries
  // ---------------------------------------------------------------------

  Future<void> upsertCacheEntry(CacheEntriesCompanion row) =>
      into(cacheEntries).insertOnConflictUpdate(row);

  Future<CacheEntryRow?> cacheEntryRow(String key) =>
      (select(cacheEntries)..where((t) => t.key.equals(key))).getSingleOrNull();

  Future<List<CacheEntryRow>> cacheEntryRows({CacheKind? kind}) {
    final query = select(cacheEntries);
    if (kind != null) {
      query.where((t) => t.kind.equals(kind.name));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.lastAccessAt)]);
    return query.get();
  }

  Future<void> deleteCacheEntry(String key) =>
      (delete(cacheEntries)..where((t) => t.key.equals(key))).go();

  Future<void> clearCacheEntries() => delete(cacheEntries).go();

  // ---------------------------------------------------------------------
  // Statistics
  // ---------------------------------------------------------------------

  Future<void> upsertStatistic(String key, int value) =>
      into(mediaStatistics).insertOnConflictUpdate(
        MediaStatisticsCompanion.insert(
          statKey: key,
          value: Value(value),
          recordedAt: DateTime.now(),
        ),
      );

  Future<int?> statisticValue(String key) =>
      (select(mediaStatistics)..where((t) => t.statKey.equals(key)))
          .getSingleOrNull()
          .then((row) => row?.value);

  Future<List<MediaStatisticRow>> allStatistics() =>
      select(mediaStatistics).get();

  // ---------------------------------------------------------------------
  // Aggregate maintenance
  // ---------------------------------------------------------------------

  /// Purges the full media footprint of [attachmentId] in one transaction:
  /// chunks, sessions, thumbnails, previews and the catalog row.
  Future<void> purgeAttachment(String attachmentId) => transaction(() async {
    final sessions = await sessionsForAttachment(attachmentId);
    for (final session in sessions) {
      await deleteChunksForSession(session.sessionId);
    }
    await (delete(
      transferSessions,
    )..where((t) => t.attachmentId.equals(attachmentId))).go();
    await deleteThumbnailsForAttachment(attachmentId);
    await deletePreviewsForAttachment(attachmentId);
    await deleteAttachment(attachmentId);
  });
}

/// One grouped row of [MediaDao.summary].
final class MediaSummaryAggregate {
  const MediaSummaryAggregate({
    required this.category,
    required this.count,
    required this.bytes,
  });

  final MediaCategory category;
  final int count;
  final int bytes;
}
