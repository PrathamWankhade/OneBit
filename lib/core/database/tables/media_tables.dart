import 'package:drift/drift.dart';

import 'converters.dart';
import 'enums.dart';

/// The Phase 9 media catalog: metadata of every attached file.
///
/// Plaintext file bytes live on disk (paths + hashes only in SQLite); the
/// small inline payload escape hatch is typed for ciphertext
/// (`inlineCiphertext`) so the future encryption layer slots in without a
/// schema change ("Encrypted Storage Ready").
@DataClassName('MediaAttachmentRow')
@TableIndex(name: 'idx_media_attachments_message', columns: {#messageId})
class MediaAttachments extends Table {
  TextColumn get attachmentId => text()();

  /// Owning message; null for attachments staged before a message exists.
  TextColumn get messageId => text().nullable()();

  TextColumn get category => textEnum<MediaCategory>()();

  TextColumn get fileName => text()();

  TextColumn get mimeType => text()();

  IntColumn get sizeBytes => integer()();

  /// Whole-file SHA-256 (hex), computed in the single staging pass.
  TextColumn get sha256 => text().nullable()();

  /// Serialized `MediaDetail` probe result (dimensions, duration, pages).
  TextColumn get mediaDetailJson => text().nullable()();

  /// On-disk location under the media root.
  TextColumn get localPath => text().nullable()();

  /// Future host for remote (streamed) attachments.
  TextColumn get remoteUri => text().nullable()();

  TextColumn get status => textEnum<AttachmentStatus>()();

  /// True when the payload is small enough to live in this row.
  BoolColumn get isInline => boolean().withDefault(const Constant(false))();

  /// Ciphertext of the inline payload (plaintext in v1, sealed later).
  BlobColumn get inlineCiphertext => blob().nullable()();

  IntColumn get createdAt => integer().map(dateTimeMsConverter)();

  IntColumn get updatedAt => integer().map(dateTimeMsConverter)();

  @override
  Set<Column> get primaryKey => {attachmentId};
}

/// One chunked file transfer between two nodes.
///
/// [chunksBitmap] is the authoritative "what is acked/received" record
/// (BLOB of packed bits); it is persisted on every change so a process
/// restart resumes from the exact bitmap. [bytesTransferred] is recomputed
/// from the bitmap inside the same transaction and can never disagree.
@DataClassName('TransferSessionRow')
@TableIndex(name: 'idx_transfer_sessions_attachment', columns: {#attachmentId})
class TransferSessions extends Table {
  TextColumn get sessionId => text()();

  TextColumn get attachmentId => text()();

  TextColumn get peerNodeId => text()();

  TextColumn get direction => textEnum<TransferDirection>()();

  TextColumn get state => textEnum<TransferState>()();

  IntColumn get chunkSize => integer()();

  IntColumn get totalChunks => integer()();

  BlobColumn get chunksBitmap => blob()();

  IntColumn get bytesTransferred => integer().withDefault(const Constant(0))();

  IntColumn get createdAt => integer().map(dateTimeMsConverter)();

  IntColumn get updatedAt => integer().map(dateTimeMsConverter)();

  IntColumn get completedAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  /// Human-readable reason of the latest failure.
  TextColumn get lastError => text().nullable()();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  /// Session TTL in seconds (expired sessions are swept by maintenance).
  IntColumn get ttlSeconds => integer().nullable()();

  @override
  Set<Column> get primaryKey => {sessionId};
}

/// Per-chunk ledger of a transfer session.
///
/// The bitmap remains the crash-safe source of truth; this table carries
/// the per-chunk geometry (offset/size/sha256) and bookkeeping (attempts,
/// sent/acked timestamps). `(sessionId, index)` is the primary key.
@DataClassName('TransferChunkRow')
@TableIndex(name: 'idx_transfer_chunks_session', columns: {#sessionId, #index})
class TransferChunks extends Table {
  TextColumn get sessionId => text()();

  IntColumn get index => integer()();

  /// Absolute byte offset inside the file (defense-in-depth ordering key).
  IntColumn get offset => integer()();

  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();

  /// Hex SHA-256 of this chunk's bytes (transit corruption detection).
  TextColumn get sha256 => text().nullable()();

  TextColumn get state => textEnum<ChunkState>()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  IntColumn get sentAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  IntColumn get ackedAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  @override
  Set<Column> get primaryKey => {sessionId, index};
}

/// Generated thumbnails (raster or probe-kind) per attachment.
@DataClassName('MediaThumbnailRow')
@TableIndex(name: 'idx_media_thumbnails_attachment', columns: {#attachmentId})
class MediaThumbnails extends Table {
  TextColumn get thumbnailId => text()();

  TextColumn get attachmentId => text()();

  TextColumn get kind => textEnum<ThumbnailKind>()();

  IntColumn get width => integer()();

  IntColumn get height => integer()();

  TextColumn get localPath => text().nullable()();

  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();

  IntColumn get generatedAt => integer().map(dateTimeMsConverter)();

  @override
  Set<Column> get primaryKey => {thumbnailId};
}

/// Cached metadata preview of an attachment.
@DataClassName('MediaPreviewRow')
class MediaPreviews extends Table {
  TextColumn get previewId => text()();

  TextColumn get attachmentId => text()();

  TextColumn get kind => textEnum<PreviewKind>()();

  /// Serialized probe result (MediaProbeResult JSON).
  TextColumn get metadataJson => text().nullable()();

  TextColumn get thumbnailId => text().nullable()();

  IntColumn get createdAt => integer().map(dateTimeMsConverter)();

  @override
  Set<Column> get primaryKey => {previewId};
}

/// Stored voice notes (domain-independent of the legacy VoiceNotes table).
@DataClassName('VoiceRecordingRow')
class VoiceRecordings extends Table {
  TextColumn get voiceNoteId => text()();

  TextColumn get messageId => text().nullable()();

  TextColumn get fileName => text()();

  TextColumn get mimeType => text()();

  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();

  IntColumn get durationMs => integer().withDefault(const Constant(0))();

  IntColumn get sampleRate => integer().nullable()();

  /// Waveform buckets as JSON (`[0.0..1.0]` amplitudes).
  TextColumn get waveformJson => text().nullable()();

  TextColumn get localPath => text().nullable()();

  IntColumn get createdAt => integer().map(dateTimeMsConverter)();

  @override
  Set<Column> get primaryKey => {voiceNoteId};
}

/// Cache catalogue — the durable mirror of memory/disk cache state.
@DataClassName('CacheEntryRow')
@TableIndex(name: 'idx_cache_entries_kind', columns: {#kind})
class CacheEntries extends Table {
  TextColumn get key => text()();

  TextColumn get kind => textEnum<CacheKind>()();

  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();

  IntColumn get accessCount => integer().withDefault(const Constant(0))();

  IntColumn get lastAccessAt => integer().map(dateTimeMsConverter)();

  IntColumn get createdAt => integer().map(dateTimeMsConverter)();

  TextColumn get path => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Durable mirror of `TransferStatistics` counters and gauges.
@DataClassName('MediaStatisticRow')
class MediaStatistics extends Table {
  TextColumn get statKey => text()();

  IntColumn get value => integer().withDefault(const Constant(0))();

  IntColumn get recordedAt => integer().map(dateTimeMsConverter)();

  @override
  Set<Column> get primaryKey => {statKey};
}
