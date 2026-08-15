import 'package:onebit/core/result/result.dart';

import 'attachment.dart';

/// Contract for the media catalog store.
///
/// Implementations: drift-backed (`SqliteAttachmentRepository`) and
/// in-memory fakes for tests. Every call returns a [Result] — nothing
/// throws across this boundary.
abstract interface class AttachmentRepository {
  /// Upserts the catalog row of [attachment].
  Future<Result<Attachment>> save(Attachment attachment);

  Future<Result<Attachment?>> get(String attachmentId);

  /// Catalog rows of one message, newest first.
  Future<Result<List<Attachment>>> listByMessage(String messageId);

  Future<Result<List<Attachment>>> listByCategory(MediaCategory category);

  /// Soft-purges the row; the caller owns file cleanup.
  Future<Result<void>> delete(String attachmentId);

  /// Forward-only status transition.
  Future<Result<void>> updateStatus(
    String attachmentId,
    AttachmentStatus status,
  );

  /// Hard-deletes rows created before [cutoff] (bounded).
  Future<Result<List<Attachment>>> purgeBefore(
    DateTime cutoff, {
    int limit = 500,
  });

  /// Live catalog of [messageId] (re-emits on change).
  Stream<Result<List<Attachment>>> watchByMessage(String messageId);
}
