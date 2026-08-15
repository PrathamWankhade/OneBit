// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_dao.dart';

// ignore_for_file: type=lint
mixin _$MediaDaoMixin on DatabaseAccessor<OneBitDatabase> {
  $MediaAttachmentsTable get mediaAttachments =>
      attachedDatabase.mediaAttachments;
  $TransferSessionsTable get transferSessions =>
      attachedDatabase.transferSessions;
  $TransferChunksTable get transferChunks => attachedDatabase.transferChunks;
  $MediaThumbnailsTable get mediaThumbnails => attachedDatabase.mediaThumbnails;
  $MediaPreviewsTable get mediaPreviews => attachedDatabase.mediaPreviews;
  $VoiceRecordingsTable get voiceRecordings => attachedDatabase.voiceRecordings;
  $CacheEntriesTable get cacheEntries => attachedDatabase.cacheEntries;
  $MediaStatisticsTable get mediaStatistics => attachedDatabase.mediaStatistics;
  MediaDaoManager get managers => MediaDaoManager(this);
}

class MediaDaoManager {
  final _$MediaDaoMixin _db;
  MediaDaoManager(this._db);
  $$MediaAttachmentsTableTableManager get mediaAttachments =>
      $$MediaAttachmentsTableTableManager(
        _db.attachedDatabase,
        _db.mediaAttachments,
      );
  $$TransferSessionsTableTableManager get transferSessions =>
      $$TransferSessionsTableTableManager(
        _db.attachedDatabase,
        _db.transferSessions,
      );
  $$TransferChunksTableTableManager get transferChunks =>
      $$TransferChunksTableTableManager(
        _db.attachedDatabase,
        _db.transferChunks,
      );
  $$MediaThumbnailsTableTableManager get mediaThumbnails =>
      $$MediaThumbnailsTableTableManager(
        _db.attachedDatabase,
        _db.mediaThumbnails,
      );
  $$MediaPreviewsTableTableManager get mediaPreviews =>
      $$MediaPreviewsTableTableManager(_db.attachedDatabase, _db.mediaPreviews);
  $$VoiceRecordingsTableTableManager get voiceRecordings =>
      $$VoiceRecordingsTableTableManager(
        _db.attachedDatabase,
        _db.voiceRecordings,
      );
  $$CacheEntriesTableTableManager get cacheEntries =>
      $$CacheEntriesTableTableManager(_db.attachedDatabase, _db.cacheEntries);
  $$MediaStatisticsTableTableManager get mediaStatistics =>
      $$MediaStatisticsTableTableManager(
        _db.attachedDatabase,
        _db.mediaStatistics,
      );
}
