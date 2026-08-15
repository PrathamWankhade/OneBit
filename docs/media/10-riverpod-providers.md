# 10 — Riverpod Providers

Providers live in `presentation/media_providers.dart`. They are the only
place the presentation layer wires domain + data. Note: **no widgets** —
the providers expose data for Phase 10 controllers.

## Provider graph

```
databaseProvider ──▶ MediaDao ──┐
appLoggerProvider ──────────────┼──▶ Sqlite*Repository ──▶ MediaRepository
localNodeIdProvider ────────────┘
dtnRepositoryProvider ──▶ AttachmentManager ──▶ TransferEngine ─┐
mediaRepositoryProvider ────────────────────────────────────────┴──▶ MediaEngine
```

## Core providers

| Provider | Kind | Provides |
| --- | --- | --- |
| `mediaDaoProvider` | `Provider<MediaDao>` | drift DAO |
| `attachmentRepositoryProvider` | `Provider<AttachmentRepository>` | sqlite impl |
| `transferRepositoryProvider` | `Provider<TransferRepository>` | sqlite impl |
| `thumbnailRepositoryProvider` | `Provider<ThumbnailRepository>` | sqlite impl |
| `voiceRepositoryProvider` | `Provider<VoiceRepository>` | sqlite impl |
| `cacheRepositoryProvider` | `Provider<CacheRepository>` | sqlite impl |
| `previewRepositoryProvider` | `Provider<PreviewRepository>` | sqlite impl |
| `mediaRepositoryProvider` | `Provider<MediaRepository>` | aggregate sqlite impl |
| `attachmentStoreProvider` | `Provider<AttachmentStore>` | file store (root from `getApplicationDocumentsDirectory`) |
| `attachmentManagerProvider` | `Provider<AttachmentManager>` | DTN seam |
| `transferEngineProvider` | `Provider<TransferEngine>` | session engine (started lazily) |
| `mediaEngineProvider` | `Provider<MediaEngine>` | façade; `start()` on touch, `stop()` on dispose |

## Feature providers (Notifier / Stream / Future)

| Provider | Kind | Provides |
| --- | --- | --- |
| `activeTransferProvider` | `StreamProvider<List<TransferSession>>` | live active sessions |
| `transferProvider` (family) | `StreamProvider<TransferSession?>` | one session by id |
| `attachmentProvider` (family) | `FutureProvider<Attachment?>` | one attachment |
| `attachmentsByMessageProvider` (family) | `StreamProvider<List<Attachment>>` | catalog of a message |
| `previewProvider` (family) | `FutureProvider<MediaPreview?>` | preview + thumbnail |
| `voiceRecordingsProvider` (family) | `StreamProvider<List<VoiceRecording>>` | recordings of a message |
| `cacheStatisticsProvider` | `StreamProvider<CacheStatistics>` | cache health |
| `transferStatisticsProvider` | `Provider<Future<TransferStatistics>>` | stats snapshot |
| `mediaSummaryProvider` | `FutureProvider<MediaSummary>` | storage budget |
| `compressionProfilesProvider` | `Provider<List<CompressionProfile>>` | built-in profiles |

## Messaging seam (inbound dispatch)

The media engine receives its envelopes through an observer hook on the
messaging engine (see `01-architecture.md` §5). In the provider file:

```dart
final Provider<MediaEngine> mediaEngineProvider = Provider<MediaEngine>((ref) {
  final engine = MediaEngine(...);
  ref.watch(messagingEngineProvider).onUnknownEnvelope =
      (packet, reason) => engine.handleInboundEnvelope(packet);
  engine.start();
  ref.onDispose(() => unawaited(engine.stop()));
  return engine;
});
```

The hook is a plain `Future<void> Function(DtnPacket, String)?` field on
`MessagingEngine` — default `null`, so messaging behavior is unchanged when
the media feature is absent.