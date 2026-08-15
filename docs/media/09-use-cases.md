# 09 — Use Cases

All use cases live in `domain/use_cases/`, extend `UseCase<Params, Output>`
(shared base) and wrap `MediaEngine` operations. They are pure domain —
fully unit-testable without Flutter.

| Use case | Params | Output | Behavior |
| --- | --- | --- | --- |
| `AttachFile` | `AttachFileParams(file, messageId?, channelId?, category?, compress?, profile?)` | `Attachment` | validate → stage → probe → compress → persist catalog → lazy thumbnail |
| `RemoveAttachment` | `RemoveAttachmentParams(attachmentId)` | `void` | cancel any live session, purge files + DB rows, evict caches |
| `StartTransfer` | `StartTransferParams(attachmentId, peerNodeId, chunkSize?, ttl?)` | `TransferSession` | create session, announce, begin chunk pump |
| `PauseTransfer` | `PauseTransferParams(sessionId)` | `void` | scheduler stop, persist `paused`, best-effort `AP` |
| `ResumeTransfer` | `ResumeTransferParams(sessionId)` | `void` | read bitmap, `resuming → transferring`, pump missing chunks |
| `CancelTransfer` | `CancelTransferParams(sessionId)` | `void` | `cancelled`, purge temp, best-effort `AX` |
| `RetryTransfer` | `RetryTransferParams(sessionId)` | `void` | failed/cancelled → `queued` with fresh bitmap from local file |
| `GenerateThumbnail` | `GenerateThumbnailParams(attachmentId, force?)` | `Thumbnail` | lazy generation with per-attachment single-flight |
| `CompressMedia` | `CompressMediaParams(attachmentId, profile?)` | `CompressionStatistics` | compress staged file in place, keep original if gain below threshold |
| `ValidateMedia` | `ValidateMediaParams(filePath?, attachmentId?, rules?)` | `ValidationResult` | run the validator rule set (size, type, ext, checksum, corruption, duplicate, storage) |
| `LoadPreview` | `LoadPreviewParams(attachmentId)` | `MediaPreview?` | probe → save preview + thumbnail → return |

Rules of thumb for all use cases:

1. Never throw — return `Err(Failure)`.
2. Never import Flutter UI, drift, or `dart:io`.
3. Stay small — one action, orchestrated through the engine.