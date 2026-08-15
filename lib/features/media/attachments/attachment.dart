import 'package:flutter/foundation.dart';

/// Media family of an attachment — drives probing, compression dispatch,
/// storage layout and UI rendering.
enum MediaCategory {
  image,
  video,
  audio,
  voice,
  document,
  archive,
  binary,
  custom;

  String get wireName => name;

  static MediaCategory? fromWireName(String name) => switch (name) {
    'image' => MediaCategory.image,
    'video' => MediaCategory.video,
    'audio' => MediaCategory.audio,
    'voice' => MediaCategory.voice,
    'document' => MediaCategory.document,
    'archive' => MediaCategory.archive,
    'binary' => MediaCategory.binary,
    'custom' => MediaCategory.custom,
    _ => null,
  };
}

/// Lifecycle state of an attachment in the media catalog.
enum AttachmentStatus {
  /// Source is being copied into the media root.
  staging,

  /// Staged, probed and persisted; available locally.
  ready,

  /// An outbound transfer of this attachment is underway.
  transferring,

  /// An inbound transfer is filling this attachment.
  downloading,

  /// Transfer finished and the payload is verified locally.
  complete,

  /// The payload is missing, corrupt or untransferable.
  failed,

  /// Removed by the user or the cache cleaner; files purged.
  purged;

  String get wireName => name;

  static AttachmentStatus? fromWireName(String name) => switch (name) {
    'staging' => AttachmentStatus.staging,
    'ready' => AttachmentStatus.ready,
    'transferring' => AttachmentStatus.transferring,
    'downloading' => AttachmentStatus.downloading,
    'complete' => AttachmentStatus.complete,
    'failed' => AttachmentStatus.failed,
    'purged' => AttachmentStatus.purged,
    _ => null,
  };
}

/// The probed technical detail of a media payload (sealed union).
///
/// Serialized into `mediaDetailJson` by the data layer; `toJson`/`fromJson`
/// are pure shape conversions (no I/O).
sealed class MediaDetail {
  const MediaDetail();

  Map<String, Object?> toJson();

  static MediaDetail? fromJson(Map<String, Object?> json) {
    final kind = json['kind'];
    switch (kind) {
      case 'image':
        return ImageDetail(
          width: (json['width'] as num?)?.toInt() ?? 0,
          height: (json['height'] as num?)?.toInt() ?? 0,
        );
      case 'video':
        return VideoDetail(
          width: (json['width'] as num?)?.toInt() ?? 0,
          height: (json['height'] as num?)?.toInt() ?? 0,
          durationMs: (json['durationMs'] as num?)?.toInt(),
        );
      case 'audio':
        return AudioDetail(
          durationMs: (json['durationMs'] as num?)?.toInt(),
          sampleRate: (json['sampleRate'] as num?)?.toInt(),
        );
      case 'document':
        return DocumentDetail(
          pageCount: (json['pageCount'] as num?)?.toInt(),
          encoding: json['encoding'] as String?,
        );
      case 'binary':
        return BinaryDetail(note: json['note'] as String?);
      default:
        return null;
    }
  }
}

@immutable
final class ImageDetail extends MediaDetail {
  const ImageDetail({required this.width, required this.height});

  final int width;
  final int height;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'image',
    'width': width,
    'height': height,
  };

  @override
  bool operator ==(Object other) =>
      other is ImageDetail && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash('image', width, height);

  @override
  String toString() => 'ImageDetail($width×$height)';
}

@immutable
final class VideoDetail extends MediaDetail {
  const VideoDetail({
    required this.width,
    required this.height,
    this.durationMs,
  });

  final int width;
  final int height;
  final int? durationMs;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'video',
    'width': width,
    'height': height,
    if (durationMs != null) 'durationMs': durationMs,
  };

  @override
  bool operator ==(Object other) =>
      other is VideoDetail &&
      other.width == width &&
      other.height == height &&
      other.durationMs == durationMs;

  @override
  int get hashCode => Object.hash('video', width, height, durationMs);

  @override
  String toString() => 'VideoDetail($width×$height, ${durationMs ?? '?'}ms)';
}

@immutable
final class AudioDetail extends MediaDetail {
  const AudioDetail({this.durationMs, this.sampleRate});

  final int? durationMs;
  final int? sampleRate;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'audio',
    if (durationMs != null) 'durationMs': durationMs,
    if (sampleRate != null) 'sampleRate': sampleRate,
  };

  @override
  bool operator ==(Object other) =>
      other is AudioDetail &&
      other.durationMs == durationMs &&
      other.sampleRate == sampleRate;

  @override
  int get hashCode => Object.hash('audio', durationMs, sampleRate);

  @override
  String toString() => 'AudioDetail(${durationMs ?? '?'}ms)';
}

@immutable
final class DocumentDetail extends MediaDetail {
  const DocumentDetail({this.pageCount, this.encoding});

  final int? pageCount;
  final String? encoding;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'document',
    if (pageCount != null) 'pageCount': pageCount,
    if (encoding != null) 'encoding': encoding,
  };

  @override
  bool operator ==(Object other) =>
      other is DocumentDetail &&
      other.pageCount == pageCount &&
      other.encoding == encoding;

  @override
  int get hashCode => Object.hash('document', pageCount, encoding);

  @override
  String toString() => 'DocumentDetail(${pageCount ?? '?'} pages)';
}

@immutable
final class BinaryDetail extends MediaDetail {
  const BinaryDetail({this.note});

  final String? note;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'binary',
    if (note != null) 'note': note,
  };

  @override
  bool operator ==(Object other) => other is BinaryDetail && other.note == note;

  @override
  int get hashCode => Object.hash('binary', note);

  @override
  String toString() => 'BinaryDetail(${note ?? ''})';
}

/// Immutable metadata of an attachment payload.
@immutable
final class AttachmentMetadata {
  const AttachmentMetadata({
    required this.fileName,
    required this.mimeType,
    required this.category,
    required this.sizeBytes,
    this.sha256,
    this.media,
  });

  final String fileName;
  final String mimeType;
  final MediaCategory category;
  final int sizeBytes;

  /// Whole-file SHA-256 (hex), computed once during staging.
  final String? sha256;

  /// Probing result (dimensions / duration / pages) when available.
  final MediaDetail? media;

  AttachmentMetadata copyWith({
    String? fileName,
    String? mimeType,
    MediaCategory? category,
    int? sizeBytes,
    String? sha256,
    MediaDetail? media,
  }) => AttachmentMetadata(
    fileName: fileName ?? this.fileName,
    mimeType: mimeType ?? this.mimeType,
    category: category ?? this.category,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    sha256: sha256 ?? this.sha256,
    media: media ?? this.media,
  );
}

/// A source payload offered to [AttachFile].
///
/// Pure value: the I/O boundary stays on the [AttachmentStore] side, so use
/// cases never touch `dart:io`. Either [sourcePath] (staged from disk) or
/// [inlineBytes] (small in-memory payload) must be provided.
@immutable
final class MediaSource {
  const MediaSource({
    required this.fileName,
    this.sourcePath,
    this.inlineBytes,
    this.declaredMimeType,
    this.declaredCategory,
    this.sizeBytesOverride,
  }) : assert(
         sourcePath != null || inlineBytes != null,
         'either sourcePath or inlineBytes must be provided',
       );

  final String fileName;

  /// Absolute path of the source file (large payloads).
  final String? sourcePath;

  /// Inline payload for small attachments (≤ inline threshold).
  final List<int>? inlineBytes;

  /// MIME type declared by the caller; sniffers fill gaps, never override.
  final String? declaredMimeType;

  /// Category declared by the caller (defaults to sniffed category).
  final MediaCategory? declaredCategory;

  /// Caller-known size when [inlineBytes] are absent (avoids a stat call).
  final int? sizeBytesOverride;

  int get sizeBytes => inlineBytes?.length ?? sizeBytesOverride ?? 0;

  MediaSource copyWith({
    String? fileName,
    String? sourcePath,
    List<int>? inlineBytes,
    String? declaredMimeType,
    MediaCategory? declaredCategory,
    int? sizeBytesOverride,
  }) => MediaSource(
    fileName: fileName ?? this.fileName,
    sourcePath: sourcePath ?? this.sourcePath,
    inlineBytes: inlineBytes ?? this.inlineBytes,
    declaredMimeType: declaredMimeType ?? this.declaredMimeType,
    declaredCategory: declaredCategory ?? this.declaredCategory,
    sizeBytesOverride: sizeBytesOverride ?? this.sizeBytesOverride,
  );
}

/// The media catalog entry — the domain representation of an attached file.
@immutable
final class Attachment {
  const Attachment({
    required this.attachmentId,
    required this.metadata,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.messageId,
    this.localPath,
    this.remoteUri,
    this.isInline = false,
    this.inlineBytes,
  });

  final String attachmentId;

  /// Owning message id (null for standalone / pre-message attachments).
  final String? messageId;

  final AttachmentMetadata metadata;

  final AttachmentStatus status;

  /// Where the payload lives under the media root.
  final String? localPath;

  /// Future host for remote (streamed) payloads.
  final String? remoteUri;

  /// True when the payload is small enough to live in the database row.
  final bool isInline;

  /// The inline payload (filled by the store for small files only).
  final List<int>? inlineBytes;

  final DateTime createdAt;
  final DateTime updatedAt;

  Attachment copyWith({
    String? messageId,
    AttachmentMetadata? metadata,
    AttachmentStatus? status,
    String? localPath,
    String? remoteUri,
    bool? isInline,
    List<int>? inlineBytes,
    DateTime? updatedAt,
  }) => Attachment(
    attachmentId: attachmentId,
    messageId: messageId ?? this.messageId,
    metadata: metadata ?? this.metadata,
    status: status ?? this.status,
    localPath: localPath ?? this.localPath,
    remoteUri: remoteUri ?? this.remoteUri,
    isInline: isInline ?? this.isInline,
    inlineBytes: inlineBytes ?? this.inlineBytes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Attachment && other.attachmentId == attachmentId;

  @override
  int get hashCode => attachmentId.hashCode;

  @override
  String toString() =>
      'Attachment($attachmentId '
      '${metadata.fileName} [${metadata.category}/${metadata.sizeBytes}B, '
      '$status])';
}
