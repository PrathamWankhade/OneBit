import 'package:flutter/foundation.dart';

import '../attachments/attachment.dart';

/// A named compression configuration for one media family.
@immutable
final class CompressionProfile {
  const CompressionProfile({
    required this.profileId,
    required this.name,
    required this.category,
    required this.qualityPercent,
    required this.maxBytes,
    required this.enabled,
    this.lossless = false,
    this.minGainPercent = 5,
  }) : assert(
         qualityPercent >= 0 && qualityPercent <= 100,
         'quality must be 0..100',
       );

  final String profileId;
  final String name;
  final MediaCategory category;

  /// 0 (smallest) .. 100 (best quality).
  final int qualityPercent;

  /// Target maximum output size; compressors degrade toward it.
  final int maxBytes;

  final bool enabled;

  /// True for entropy-only compression (documents/archives).
  final bool lossless;

  /// Below this relative gain the original file is kept.
  final int minGainPercent;

  /// Built-in profiles, one per compressible family.
  static const List<CompressionProfile> builtIn = [
    CompressionProfile(
      profileId: 'doc_lossless',
      name: 'Lossless documents',
      category: MediaCategory.document,
      qualityPercent: 100,
      maxBytes: 64 * 1024 * 1024,
      enabled: true,
      lossless: true,
    ),
    CompressionProfile(
      profileId: 'archive_lossless',
      name: 'Lossless archives',
      category: MediaCategory.archive,
      qualityPercent: 100,
      maxBytes: 256 * 1024 * 1024,
      enabled: true,
      lossless: true,
    ),
    CompressionProfile(
      profileId: 'image_balanced',
      name: 'Balanced images',
      category: MediaCategory.image,
      qualityPercent: 85,
      maxBytes: 8 * 1024 * 1024,
      enabled: true,
    ),
    CompressionProfile(
      profileId: 'video_balanced',
      name: 'Balanced video',
      category: MediaCategory.video,
      qualityPercent: 80,
      maxBytes: 64 * 1024 * 1024,
      enabled: true,
    ),
  ];

  /// The built-in profile for [category], or null.
  static CompressionProfile? forCategory(MediaCategory category) =>
      builtIn.where((p) => p.category == category).firstOrNull;
}
