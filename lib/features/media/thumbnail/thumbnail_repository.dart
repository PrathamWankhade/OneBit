import 'package:onebit/core/result/result.dart';

import 'thumbnail.dart';

/// Contract for thumbnail persistence.
abstract interface class ThumbnailRepository {
  Future<Result<Thumbnail>> save(Thumbnail thumbnail);

  /// The newest thumbnail of [attachmentId] (or null).
  Future<Result<Thumbnail?>> forAttachment(String attachmentId);

  Future<Result<void>> delete(String thumbnailId);

  /// Hard-deletes thumbnails generated before [cutoff] (bounded).
  Future<Result<void>> purgeBefore(DateTime cutoff, {int limit = 500});

  /// Live stream of the attachment's newest thumbnail.
  Stream<Result<Thumbnail?>> watch(String attachmentId);
}
