import 'package:flutter/foundation.dart';

import '../attachments/attachment.dart';

/// Preview family of an attachment — drives the future UI renderer.
enum PreviewKind {
  image,
  video,
  document,
  audio,
  voice,
  binary;

  String get wireName => name;

  static PreviewKind? fromWireName(String name) => switch (name) {
    'image' => PreviewKind.image,
    'video' => PreviewKind.video,
    'document' => PreviewKind.document,
    'audio' => PreviewKind.audio,
    'voice' => PreviewKind.voice,
    'binary' => PreviewKind.binary,
    _ => null,
  };

  /// The renderer a [MediaCategory] maps to by default.
  static PreviewKind forCategory(MediaCategory category) => switch (category) {
    MediaCategory.image => PreviewKind.image,
    MediaCategory.video => PreviewKind.video,
    MediaCategory.audio => PreviewKind.audio,
    MediaCategory.voice => PreviewKind.voice,
    MediaCategory.document => PreviewKind.document,
    MediaCategory.archive ||
    MediaCategory.binary ||
    MediaCategory.custom => PreviewKind.binary,
  };
}

/// Cached preview metadata of an attachment.
@immutable
final class MediaPreview {
  const MediaPreview({
    required this.previewId,
    required this.attachmentId,
    required this.kind,
    required this.metadataJson,
    required this.createdAt,
    this.thumbnailId,
  });

  final String previewId;
  final String attachmentId;
  final PreviewKind kind;

  /// Serialized [MediaProbeResult] (dimensions, duration, pages).
  final String metadataJson;

  /// The thumbnail attached to this preview (when generated).
  final String? thumbnailId;
  final DateTime createdAt;

  MediaPreview copyWith({String? thumbnailId}) => MediaPreview(
    previewId: previewId,
    attachmentId: attachmentId,
    kind: kind,
    metadataJson: metadataJson,
    thumbnailId: thumbnailId ?? this.thumbnailId,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is MediaPreview && other.previewId == previewId;

  @override
  int get hashCode => previewId.hashCode;

  @override
  String toString() => 'MediaPreview($previewId [$kind])';
}
