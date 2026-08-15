# 07 — Models

All models are immutable (`final` fields, `const` constructors where
possible) and carry no I/O logic. Enums serialize as stable wire names.

## 7.1 Attachment catalog

- **`Attachment`** — `attachmentId`, `messageId?`, `metadata:
  AttachmentMetadata`, `status: AttachmentStatus`, `localPath?`, `createdAt`,
  `updatedAt`, `isInline` (small payloads stored in DB), `remoteUri?`.
- **`AttachmentStatus`** — `staging, ready, transferring, downloading,
  complete, failed, purged`.
- **`AttachmentMetadata`** — `fileName`, `mimeType`, `category:
  MediaCategory`, `sizeBytes`, `sha256`, `media: MediaDetail?`.
- **`MediaCategory`** — `image, video, audio, voice, document, archive,
  binary, custom` (maps to supported file-type families).
- **`MediaDetail`** (sealed union) — `ImageDetail(width,height)`,
  `VideoDetail(width,height,durationMs)`, `AudioDetail(durationMs,sampleRate)`,
  `DocumentDetail(pageCount,encoding)`, `BinaryDetail(note)`.

## 7.2 Transfer

- **`TransferState`** — `queued, transferring, paused, resuming, verifying,
  completed, failed, cancelled, expired` (persisted, never renamed).
- **`TransferDirection`** — `send, receive`.
- **`TransferSession`** — `sessionId`, `attachmentId`, `peerNodeId`,
  `direction`, `state`, `chunkSize`, `totalChunks`, `chunksBitmap:
  TransferBitmap`, `bytesTransferred`, `createdAt`, `updatedAt`,
  `completedAt?`, `lastError?`, `attemptCount`, `ttl?`.
- **`TransferChunk`** — `sessionId`, `index`, `offset`, `sizeBytes`, `sha256`,
  `state: ChunkState`, `attempts`, `sentAt?`, `ackedAt?`.
- **`ChunkState`** — `pending, inFlight, acknowledged, failed`.
- **`TransferStatistics`** — counters and gauges: sessions started /
  active / completed / failed / cancelled, bytes transferred (send +
  receive), chunks sent / received / retried, average chunk rate,
  peakInFlight. Produced from the database by the statistics repository.

## 7.3 Thumbnails & previews

- **`Thumbnail`** — `thumbnailId`, `attachmentId`, `width`, `height`,
  `localPath`, `sizeBytes`, `generatedAt`, `kind: ThumbnailKind`
  (`raster, probe`).
- **`MediaPreview`** — `previewId`, `attachmentId`, `kind: PreviewKind`
  (`image, video, document, audio, voice, binary`), `metadataJson`
  (probe result serialization), `thumbnailId?`, `createdAt`.
- **`MediaProbeResult`** — `category`, `mimeType`, `width?`, `height?`,
  `durationMs?`, `sampleRate?`, `pageCount?`, `encoding?`, `note?`.

## 7.4 Voice

- **`VoiceRecording`** — `voiceNoteId`, `messageId?`, `fileName`,
  `mimeType`, `sizeBytes`, `durationMs`, `sampleRate?`, `waveform:
  WaveformData`, `localPath?`, `createdAt`.
- **`WaveformData`** — `buckets: List<double>` (0..1 normalized amplitudes,
  immutable via `List.unmodifiable`), `bucketCount`, `sampleCount`;
  `fromSamples(List<double>, bucketCount)` resamples.

## 7.5 Compression

- **`CompressionProfile`** — `profileId`, `name`, `category:
  MediaCategory`, `qualityPercent` (0..100), `maxBytes`, `enabled`,
  `lossless: bool`, `minGainPercent` (default 5 — below that, keep original).
- **`CompressionStatistics`** — `inputBytes`, `outputBytes`, `ratio`,
  `durationMs`, `method` (`none, zlib, nativeImage, nativeVideo`),
  `applied: bool`.

## 7.6 Cache

- **`MediaCacheEntry`** — `cacheId`, `key`, `kind: CacheKind`
  (`memory, disk, thumbnail, attachment`), `sizeBytes`, `accessCount`,
  `lastAccessAt`, `createdAt`, `path?`.
- **`CacheStatistics`** — `memoryEntries`, `memoryBytes`, `diskEntries`,
  `diskBytes`, `thumbnailEntries`, `hits`, `misses`, `evictions`,
  `lastCleanupAt`.

## 7.7 Validation

- **`ValidationResult`** — `ok`, `issues: List<ValidationIssue>`;
  `ValidationIssue(code, message, severity: error|warning)`.
- `ValidationRule` interface — `code`, `check(Source)`.

## 7.8 Wire envelopes (data layer)

`MediaEnvelope` sealed union: `MediaAnnounceEnvelope`,
`MediaChunkEnvelope`, `MediaAckEnvelope`, `MediaRequestEnvelope`,
`MediaPauseEnvelope`, `MediaCompleteEnvelope`, `MediaCancelEnvelope`,
`MediaUnknownEnvelope`. See `06-chunk-architecture.md` for the `AC` field
table.