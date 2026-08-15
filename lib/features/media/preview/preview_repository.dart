import 'package:onebit/core/result/result.dart';

import 'media_preview.dart';

/// Contract for preview metadata persistence.
abstract interface class PreviewRepository {
  Future<Result<MediaPreview>> save(MediaPreview preview);

  Future<Result<MediaPreview?>> forAttachment(String attachmentId);

  Future<Result<void>> delete(String previewId);
}
