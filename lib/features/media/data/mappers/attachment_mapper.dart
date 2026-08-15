import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/tables/enums.dart' as core;
import 'package:onebit/features/media/attachments/attachment.dart';

/// Row ↔ domain mapping for the media catalog.
abstract final class AttachmentMapper {
  const AttachmentMapper._();

  static core.MediaCategory coreCategory(MediaCategory category) =>
      core.MediaCategory.values.byName(category.name);

  static MediaCategory domainCategory(core.MediaCategory category) =>
      MediaCategory.values.byName(category.name);

  static core.AttachmentStatus coreStatus(AttachmentStatus status) =>
      core.AttachmentStatus.values.byName(status.name);

  static AttachmentStatus domainStatus(core.AttachmentStatus status) =>
      AttachmentStatus.values.byName(status.name);

  static Attachment fromRow(MediaAttachmentRow row) {
    final mediaJson = row.mediaDetailJson;
    return Attachment(
      attachmentId: row.attachmentId,
      messageId: row.messageId,
      metadata: AttachmentMetadata(
        fileName: row.fileName,
        mimeType: row.mimeType,
        category: domainCategory(row.category),
        sizeBytes: row.sizeBytes,
        sha256: row.sha256,
        media: mediaJson == null ? null : _detailFromJson(mediaJson),
      ),
      status: domainStatus(row.status),
      localPath: row.localPath,
      remoteUri: row.remoteUri,
      isInline: row.isInline,
      inlineBytes: row.inlineCiphertext,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Builds the attachment's `mediaDetailJson` (kind-keyed detail JSON;
  /// null when the attachment carries no probed detail).
  static String? detailJson(Attachment attachment) {
    final detail = attachment.metadata.media;
    if (detail == null) return null;
    return jsonEncode(detail.toJson());
  }

  static MediaAttachmentsCompanion toRow(Attachment attachment) =>
      MediaAttachmentsCompanion(
        attachmentId: Value(attachment.attachmentId),
        messageId: Value(attachment.messageId),
        category: Value(coreCategory(attachment.metadata.category)),
        fileName: Value(attachment.metadata.fileName),
        mimeType: Value(attachment.metadata.mimeType),
        sizeBytes: Value(attachment.metadata.sizeBytes),
        sha256: Value(attachment.metadata.sha256),
        mediaDetailJson: Value(detailJson(attachment)),
        localPath: Value(attachment.localPath),
        remoteUri: Value(attachment.remoteUri),
        status: Value(coreStatus(attachment.status)),
        isInline: Value(attachment.isInline),
        inlineCiphertext: Value(
          attachment.inlineBytes == null
              ? null
              : Uint8List.fromList(attachment.inlineBytes!),
        ),
        createdAt: Value(attachment.createdAt),
        updatedAt: Value(attachment.updatedAt),
      );

  static MediaDetail? _detailFromJson(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, Object?>) {
        return MediaDetail.fromJson(decoded);
      }
    } on Object {
      return null;
    }
    return null;
  }
}
