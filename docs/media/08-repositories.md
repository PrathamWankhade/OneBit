# 08 — Repositories

Repositories are the only way the engine touches persistence. Every method
returns `Future<Result<T>>` or `Stream<Result<T>>` and never throws.

## 8.1 `AttachmentRepository` (attachments/)

```dart
Future<Result<Attachment>> save(Attachment attachment);
Future<Result<Attachment?>> get(String attachmentId);
Future<Result<List<Attachment>>> listByMessage(String messageId);
Future<Result<List<Attachment>>> listByCategory(MediaCategory category);
Future<Result<void>> delete(String attachmentId);
Future<Result<void>> updateStatus(String attachmentId, AttachmentStatus status);
Future<Result<void>> purgeBefore(DateTime cutoff, {int limit});
Stream<Result<List<Attachment>>> watchByMessage(String messageId);
```

## 8.2 `TransferRepository` (transfer/)

```dart
Future<Result<TransferSession>> createSession(TransferSession session);
Future<Result<TransferSession?>> sessionOf(String sessionId);
Future<Result<List<TransferSession>>> sessionsForAttachment(String attachmentId);
Future<Result<List<TransferSession>>> activeSessions();
Future<Result<TransferSession>> updateSession(TransferSession session);
Future<Result<void>> markChunkAcknowledged(String sessionId, int index);
Future<Result<void>> markChunkReceived(String sessionId, int index);
Future<Result<void>> markChunkFailed(String sessionId, int index);
Future<Result<List<TransferChunk>>> chunks(String sessionId);
Future<Result<void>> purgeSessionsBefore(DateTime cutoff);
Future<Result<TransferStatistics>> statistics();
Stream<Result<TransferSession>> watchSession(String sessionId);
```

Bitmap transitions are transactional: `markChunkAcknowledged` recomputes
`bytesTransferred` from the bitmap inside one transaction.

## 8.3 `ThumbnailRepository` (thumbnail/)

```dart
Future<Result<Thumbnail>> save(Thumbnail thumbnail);
Future<Result<Thumbnail?>> forAttachment(String attachmentId);
Future<Result<void>> delete(String thumbnailId);
Future<Result<void>> purgeBefore(DateTime cutoff, {int limit});
Stream<Result<Thumbnail?>> watch(String attachmentId);
```

## 8.4 `VoiceRepository` (voice/)

```dart
Future<Result<VoiceRecording>> save(VoiceRecording recording);
Future<Result<VoiceRecording?>> get(String voiceNoteId);
Future<Result<List<VoiceRecording>>> listByMessage(String messageId);
Future<Result<void>> delete(String voiceNoteId);
Future<Result<void>> updatePath(String voiceNoteId, String path);
Stream<Result<VoiceRecording?>> watch(String voiceNoteId);
```

## 8.5 `CacheRepository` (cache/)

```dart
Future<Result<void>> recordHit(String key);
Future<Result<void>> recordMiss(String key);
Future<Result<void>> upsertEntry(MediaCacheEntry entry);
Future<Result<void>> deleteEntry(String key);
Future<Result<List<MediaCacheEntry>>> entries({CacheKind? kind});
Future<Result<CacheStatistics>> statistics();
Future<Result<void>> clear();
```

## 8.6 `PreviewRepository` (preview/)

```dart
Future<Result<MediaPreview>> save(MediaPreview preview);
Future<Result<MediaPreview?>> forAttachment(String attachmentId);
Future<Result<void>> delete(String previewId);
```

## 8.7 `MediaRepository` (aggregate — domain/)

The aggregate façade used by the engine and use cases; the data layer's
`SqliteMediaRepository` implements all of the above contracts, so one
object satisfies every seam:

```dart
abstract interface class MediaRepository
    implements AttachmentRepository, TransferRepository,
    ThumbnailRepository, VoiceRepository, CacheRepository,
    PreviewRepository {
  /// Aggregate-level convenience queries.
  Future<Result<MediaSummary>> summary();
}
```

`MediaSummary` — per-category counts and total bytes (drives the storage
budget UI and the cache cleaner).