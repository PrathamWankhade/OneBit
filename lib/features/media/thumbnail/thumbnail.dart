import 'package:flutter/foundation.dart';

/// Kind of a generated thumbnail.
enum ThumbnailKind {
  /// Real raster pixels (downscaled image bytes on disk).
  raster,

  /// Metadata-only placeholder (no decoder available yet) — carries the
  /// probed dimensions, `localPath` may be null.
  probe;

  String get wireName => name;

  static ThumbnailKind? fromWireName(String name) => switch (name) {
    'raster' => ThumbnailKind.raster,
    'probe' => ThumbnailKind.probe,
    _ => null,
  };
}

/// A generated thumbnail of an attachment.
@immutable
final class Thumbnail {
  const Thumbnail({
    required this.thumbnailId,
    required this.attachmentId,
    required this.kind,
    required this.width,
    required this.height,
    required this.generatedAt,
    this.localPath,
    this.sizeBytes = 0,
  });

  final String thumbnailId;
  final String attachmentId;
  final ThumbnailKind kind;

  /// Scaled dimensions (target box may shrink, never upscales).
  final int width;
  final int height;

  /// On-disk thumbnail bytes (null for `probe` kind).
  final String? localPath;
  final int sizeBytes;
  final DateTime generatedAt;

  Thumbnail copyWith({
    ThumbnailKind? kind,
    int? width,
    int? height,
    String? localPath,
    int? sizeBytes,
    DateTime? generatedAt,
  }) => Thumbnail(
    thumbnailId: thumbnailId,
    attachmentId: attachmentId,
    kind: kind ?? this.kind,
    width: width ?? this.width,
    height: height ?? this.height,
    localPath: localPath ?? this.localPath,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    generatedAt: generatedAt ?? this.generatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Thumbnail && other.thumbnailId == thumbnailId;

  @override
  int get hashCode => thumbnailId.hashCode;

  @override
  String toString() =>
      'Thumbnail($thumbnailId [$kind $width×$height ${sizeBytes}B])';
}
