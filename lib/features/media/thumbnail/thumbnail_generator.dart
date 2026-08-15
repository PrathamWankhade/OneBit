import 'package:onebit/core/result/result.dart';

import '../attachments/attachment.dart';
import 'thumbnail.dart';

/// Everything a generator needs to produce a thumbnail.
final class ThumbnailRequest {
  const ThumbnailRequest({
    required this.attachment,
    required this.probe,
    required this.suggestedId,
  });

  final Attachment attachment;

  /// The probed [MediaDetail] of the attachment (may be null).
  final MediaDetail? probe;

  /// Caller-drafted id (used as-is by data generators).
  final String suggestedId;
}

/// The thumbnail generation seam.
///
/// Data-layer implementations rasterize where they can ([ThumbnailKind.raster])
/// and the built-in [ProbeThumbnailGenerator] provides the metadata-only
/// fallback ([ThumbnailKind.probe]) — generators never throw.
abstract interface class ThumbnailGenerator {
  /// Raster target box (shared by raster generators).
  int get targetWidth;

  int get targetHeight;

  Future<Result<Thumbnail>> generate(ThumbnailRequest request);
}

/// Metadata-only thumbnail: probed dimensions, no raster bytes.
///
/// The offline fallback for formats no decoder can rasterize yet. Never
/// fails; returns a `probe`-kind thumbnail.
final class ProbeThumbnailGenerator implements ThumbnailGenerator {
  const ProbeThumbnailGenerator();

  @override
  int get targetWidth => 128;

  @override
  int get targetHeight => 128;

  @override
  Future<Result<Thumbnail>> generate(ThumbnailRequest request) async {
    final media = request.probe;
    final (width, height) = switch (media) {
      ImageDetail(:final width, :final height) => (width, height),
      VideoDetail(:final width, :final height) => (width, height),
      _ => (0, 0),
    };
    return Ok(
      Thumbnail(
        thumbnailId: request.suggestedId,
        attachmentId: request.attachment.attachmentId,
        kind: ThumbnailKind.probe,
        width: width,
        height: height,
        generatedAt: DateTime.now(),
      ),
    );
  }
}
