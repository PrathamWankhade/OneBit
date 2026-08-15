import 'package:onebit/core/result/result.dart';

import '../attachments/attachment_repository.dart';
import '../cache/cache_repository.dart';
import '../preview/preview_repository.dart';
import '../thumbnail/thumbnail_repository.dart';
import '../transfer/transfer_repository.dart';
import '../transfer/transfer_statistics.dart';
import '../voice/voice_repository.dart';

/// The composite aggregate of the media subsystem: one object the engine
/// and use cases talk to, composed from the five domain repositories.
///
/// Adapters (SQLite in production, memory fakes in tests) implement the
/// same contracts, so the engine never sees a storage implementation.
abstract class MediaRepository {
  MediaRepository({
    required this.attachments,
    required this.transfers,
    required this.thumbnails,
    required this.previews,
    required this.voice,
    required this.cache,
  });

  final AttachmentRepository attachments;
  final TransferRepository transfers;
  final ThumbnailRepository thumbnails;
  final PreviewRepository previews;
  final VoiceRepository voice;
  final CacheRepository cache;

  /// Aggregate transfer counters/gauges.
  Future<Result<TransferStatistics>> transferStatistics();
}

/// Production composite — a plain passthrough aggregate over the six
/// repositories.
final class CompositeMediaRepository extends MediaRepository {
  CompositeMediaRepository({
    required super.attachments,
    required super.transfers,
    required super.thumbnails,
    required super.previews,
    required super.voice,
    required super.cache,
  });

  @override
  Future<Result<TransferStatistics>> transferStatistics() =>
      transfers.statistics();
}
