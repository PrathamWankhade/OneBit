# 04 — Class Diagram

```mermaid
classDiagram
    class MediaEngine {
        <<facade>>
        +start() void
        +stop() Future~void~
        +attachFile(...) Future~Result~Attachment~~
        +removeAttachment(...) Future~Result~void~~
        +startTransfer(...) Future~Result~TransferSession~~
        +pauseTransfer(...) +resumeTransfer(...) +cancelTransfer(...)
        +generateThumbnail(...) Future~Result~Thumbnail~~
        +compressMedia(...) +validateMedia(...) +loadPreview(...)
    }
    MediaEngine --> MediaRepository
    MediaEngine --> TransferEngine
    MediaEngine --> CompressionEngine
    MediaEngine --> MediaValidator
    MediaEngine --> ThumbnailGenerator
    MediaEngine --> MediaMetadataParser
    MediaEngine --> AttachmentManager

    class MediaRepository {
        <<interface aggregate>>
    }
    class AttachmentRepository { <<interface>> }
    class TransferRepository { <<interface>> }
    class ThumbnailRepository { <<interface>> }
    class VoiceRepository { <<interface>> }
    class CacheRepository { <<interface>> }
    class PreviewRepository { <<interface>> }

    SqliteMediaRepository ..|> MediaRepository
    SqliteAttachmentRepository ..|> AttachmentRepository
    SqliteTransferRepository ..|> TransferRepository
    SqliteThumbnailRepository ..|> ThumbnailRepository
    SqliteVoiceRepository ..|> VoiceRepository
    SqliteCacheRepository ..|> CacheRepository
    SqlitePreviewRepository ..|> PreviewRepository

    MediaDao --> OneBitDatabase
    SqliteAttachmentRepository --> MediaDao
    SqliteTransferRepository --> MediaDao
    SqliteThumbnailRepository --> MediaDao
    SqliteVoiceRepository --> MediaDao
    SqliteCacheRepository --> MediaDao
    SqlitePreviewRepository --> MediaDao

    class TransferEngine {
        +startTransfer() +pauseTransfer() +resumeTransfer()
        +cancelTransfer() +retryTransfer()
        +handleInboundEnvelope(DtnPacket) Future~void~~
        -ChunkScheduler _scheduler
    }
    TransferEngine --> TransferRepository
    TransferEngine --> AttachmentStore
    TransferEngine --> AttachmentManager
    TransferEngine --> ChunkScheduler

    class TransferSession {
        <<immutable>>
        +sessionId +attachmentId +peerNodeId +direction
        +state +chunkSize +totalChunks +acknowledgedCount
        +bytesTransferred +createdAt +updatedAt +lastError
    }
    class TransferChunk {
        <<immutable>>
        +sessionId +index +offset +sizeBytes +sha256 +state +attempts
    }
    class TransferBitmap {
        +acknowledged(index) bool
        +markAcknowledged(index) TransferBitmap
        +missing() List~int~
        +toBytes() List~int~
    }
    TransferSession --> TransferState
    TransferSession --> TransferBitmap

    class Attachment {
        <<immutable>>
        +attachmentId +messageId +metadata +status
        +localPath +createdAt +updatedAt
    }
    class AttachmentMetadata {
        +fileName +mimeType +category +sizeBytes +sha256 +media
    }
    Attachment --> AttachmentMetadata
    AttachmentMetadata --> MediaDetail

    class MediaDetail {} <<sealed>>
    class ImageDetail { +width +height }
    class VideoDetail { +width +height +durationMs }
    class AudioDetail { +durationMs +sampleRate }
    class DocumentDetail { +pageCount +encoding }
    class BinaryDetail { +note }
    MediaDetail <|-- ImageDetail
    MediaDetail <|-- VideoDetail
    MediaDetail <|-- AudioDetail
    MediaDetail <|-- DocumentDetail
    MediaDetail <|-- BinaryDetail

    class VoiceRecording {
        +voiceNoteId +fileName +mimeType +durationMs
        +waveform +sampleRate +localPath
    }
    VoiceRecording --> WaveformData

    class Thumbnail {
        +thumbnailId +attachmentId +width +height +localPath +generatedAt
    }
    class MediaPreview {
        +previewId +attachmentId +kind +metadataJson +createdAt
    }
    class CompressionProfile {
        +profileId +category +qualityPercent +maxBytes +enabled
    }
    class CompressionStatistics {
        +inputBytes +outputBytes +ratio +durationMs +method
    }
    class MediaCacheEntry {
        +cacheId +key +kind +sizeBytes +accessCount +lastAccessAt
    }
    class TransferStatistics {
        +sessionsStarted +activeSessions +completedSessions
        +failedSessions +cancelledSessions +bytesTransferred
        +chunksSent +chunksReceived +chunkRetries +averageChunkRate
    }

    class AttachmentStore {
        +stage(source, category) Future~File~
        +resolve(category, fileName) File
        +tempFor(sessionId) File
        +delete(path) Future~void~~
        +fixtureForTest() ...
    }
    class AttachmentManager {
        +sendAnnounce(...) +sendChunk(...) +sendAck(...)
        +decode(payload) Result~MediaEnvelope~
    }
    AttachmentManager --> AttachmentWireCodec
    AttachmentManager --> DTNRepository

    class AttachmentWireCodec {
        +encodeAnnounce() +encodeChunk() +encodeAck() +encodeRequest()
        +encodePause() +encodeComplete() +encodeCancel()
        +decode(payload) Result~MediaEnvelope~
    }

    class MediaValidator {
        +validate(source) Future~ValidationResult~~
        +rules() List~ValidationRule~
    }
    class MediaMetadataParser {
        +parse(path) Future~MediaProbeResult~~
    }
    class ThumbnailGenerator {
        <<interface>>
        +generate(attachment) Future~Thumbnail~~
    }
    class Compressor {
        <<interface>>
        +compress(source, profile) Future~CompressionStatistics~~
    }
    class CompressionEngine {
        +compress(attachmentId, profile) Future~Result~CompressionStatistics~~
    }
    class MemoryCache { +get(key) +put(key, value) +evict() }
    class DiskCache { +get(key) +put(key, bytes) +evict() }
    class CacheCleaner { +clean() Future~CacheCleanupReport~~ }
```

## Key relationships

- `MediaEngine` is the **only** object the presentation layer (providers)
  constructs directly. Use cases wrap engine operations.
- Repositories are contracts in domain folders; the data layer implements
  every contract over `MediaDao` + `AttachmentStore`.
- `TransferEngine` talks to the mesh **only** through `AttachmentManager`
  (envelope-minded) which in turn uses `DTNRepository` (envelope delivery).
- Probes, compressors, thumbnail generators, recorder and player are
  interfaces — the phase 9 build ships pure-Dart implementations and marks
  native/streaming variants as future work.
- All models are immutable (`final` fields, `copyWith` where mutation is
  useful), matching the messaging models' style.