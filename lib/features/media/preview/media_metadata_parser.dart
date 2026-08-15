import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../attachments/attachment.dart';
import '../attachments/media_type_registry.dart';
import '../documents/document_metadata_parser.dart';
import '../images/image_metadata_parser.dart';
import '../videos/video_metadata_parser.dart';
import 'audio_metadata_parser.dart';

/// Everything a probe needs to identify one file.
///
/// Pure value: the caller (data layer) reads the header window from disk;
/// parsers only ever see bytes.
@immutable
final class MediaProbeInput {
  const MediaProbeInput({
    required this.fileName,
    required this.sizeBytes,
    required this.headerBytes,
    this.declaredMimeType,
    this.declaredCategory,
  });

  final String fileName;
  final int sizeBytes;

  /// The first [MediaMetadataParser.headerWindow] bytes of the file.
  final List<int> headerBytes;

  /// Caller-declared MIME (sniffers fill gaps, never override).
  final String? declaredMimeType;

  /// Caller-declared category (sniffers fill gaps, never override).
  final MediaCategory? declaredCategory;

  String? get extension {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return null;
    return fileName.substring(dot + 1).toLowerCase();
  }
}

/// Immutable outcome of a metadata probe.
@immutable
final class MediaProbeResult {
  const MediaProbeResult({
    required this.category,
    required this.mimeType,
    this.width,
    this.height,
    this.durationMs,
    this.sampleRate,
    this.pageCount,
    this.encoding,
    this.note,
  });

  final MediaCategory category;
  final String mimeType;
  final int? width;
  final int? height;
  final int? durationMs;
  final int? sampleRate;
  final int? pageCount;
  final String? encoding;
  final String? note;

  /// The domain detail view of this result (may be null for unknown files).
  MediaDetail? get detail => switch (category) {
    MediaCategory.image =>
      (width != null && height != null)
          ? ImageDetail(width: width!, height: height!)
          : null,
    MediaCategory.video =>
      (width != null && height != null)
          ? VideoDetail(width: width!, height: height!, durationMs: durationMs)
          : null,
    MediaCategory.audio => AudioDetail(
      durationMs: durationMs,
      sampleRate: sampleRate,
    ),
    MediaCategory.voice => AudioDetail(
      durationMs: durationMs,
      sampleRate: sampleRate,
    ),
    MediaCategory.document => DocumentDetail(
      pageCount: pageCount,
      encoding: encoding,
    ),
    _ => BinaryDetail(note: note),
  };

  Map<String, Object?> toJson() => {
    'category': category.wireName,
    'mimeType': mimeType,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (durationMs != null) 'durationMs': durationMs,
    if (sampleRate != null) 'sampleRate': sampleRate,
    if (pageCount != null) 'pageCount': pageCount,
    if (encoding != null) 'encoding': encoding,
    if (note != null) 'note': note,
  };

  static MediaProbeResult fromJson(Map<String, Object?> json) =>
      MediaProbeResult(
        category:
            MediaCategory.fromWireName(json['category']?.toString() ?? '') ??
            MediaCategory.binary,
        mimeType: json['mimeType']?.toString() ?? 'application/octet-stream',
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        durationMs: (json['durationMs'] as num?)?.toInt(),
        sampleRate: (json['sampleRate'] as num?)?.toInt(),
        pageCount: (json['pageCount'] as num?)?.toInt(),
        encoding: json['encoding'] as String?,
        note: json['note'] as String?,
      );

  /// Parses a stored `metadataJson` blob (defensive).
  static MediaProbeResult? fromJsonString(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, Object?>) {
        return fromJson(decoded);
      }
    } on Object {
      return null;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is MediaProbeResult &&
      other.category == category &&
      other.mimeType == mimeType &&
      other.width == width &&
      other.height == height &&
      other.durationMs == durationMs &&
      other.sampleRate == sampleRate &&
      other.pageCount == pageCount &&
      other.encoding == encoding &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
    category,
    mimeType,
    width,
    height,
    durationMs,
    sampleRate,
    pageCount,
    encoding,
    note,
  );

  @override
  String toString() =>
      'MediaProbeResult($category $mimeType '
      'w=$width h=$height dur=${durationMs ?? '?'}ms '
      'pages=${pageCount ?? '?'} ${note ?? ''})';
}

/// The probe-specific fields a subtype parser may extract.
///
/// Parser implementations return this shape; the dispatcher merges it with
/// category/MIME decisions into a full [MediaProbeResult].
@immutable
final class ParsedMediaAttributes {
  const ParsedMediaAttributes({
    this.width,
    this.height,
    this.durationMs,
    this.sampleRate,
    this.pageCount,
    this.encoding,
  });

  final int? width;
  final int? height;
  final int? durationMs;
  final int? sampleRate;
  final int? pageCount;
  final String? encoding;
}

/// Sniffs the payload category from magic bytes.
abstract final class MagicBytes {
  const MagicBytes._();

  static const List<int> png = [0x89, 0x50, 0x4E, 0x47];
  static const List<int> jpeg = [0xFF, 0xD8, 0xFF];
  static const List<int> gif87 = [0x47, 0x49, 0x46, 0x38, 0x37, 0x61];
  static const List<int> gif89 = [0x47, 0x49, 0x46, 0x38, 0x39, 0x61];
  static const List<int> webp = [
    0x52, 0x49, 0x46, 0x46, // RIFF
  ];
  static const List<int> zip = [0x50, 0x4B, 0x03, 0x04];
  static const List<int> zipEmpty = [0x50, 0x4B, 0x05, 0x06];
  static const List<int> pdf = [0x25, 0x50, 0x44, 0x46];
  static const List<int> ogg = [0x4F, 0x67, 0x67, 0x53];

  static bool startsWith(List<int> haystack, List<int> needle) {
    if (haystack.length < needle.length) return false;
    for (var i = 0; i < needle.length; i++) {
      if (haystack[i] != needle[i]) return false;
    }
    return true;
  }
}

/// Pure-header sniffing dispatch — the production [MediaMetadataParser].
///
/// Reads nothing from disk ([MediaProbeInput.headerBytes] is supplied by
/// the data layer), so it is fully unit-testable without a device. Files
/// that are not recognized degrade to `binary`/`custom` with a note.
final class BasicMediaMetadataParser implements MediaMetadataParser {
  BasicMediaMetadataParser({
    ImageMetadataParser imageParser = const ImageMetadataParser(),
    VideoMetadataParser videoParser = const VideoMetadataParser(),
    AudioMetadataParser audioParser = const AudioMetadataParser(),
    DocumentMetadataParser documentParser = const DocumentMetadataParser(),
  }) : _image = imageParser,
       _video = videoParser,
       _audio = audioParser,
       _document = documentParser;

  final ImageMetadataParser _image;
  final VideoMetadataParser _video;
  final AudioMetadataParser _audio;
  final DocumentMetadataParser _document;

  @override
  int get headerWindow => MediaMetadataParser.defaultHeaderWindow;

  @override
  MediaProbeResult parse(MediaProbeInput input) {
    final declared = input.declaredMimeType;
    final sniffedCategory = _sniffCategory(input.headerBytes);
    final extensionCategory = MediaTypeRegistry.categoryForFileName(
      input.fileName,
    );

    // Category: sniffed magic wins, extension fills gaps.
    final category =
        sniffedCategory ?? input.declaredCategory ?? extensionCategory;

    final mime = declared ?? MediaTypeRegistry.mimeForFileName(input.fileName);

    final probe = _probeFor(category);
    if (probe != null) {
      final result = probe(input);
      if (result != null) {
        return MediaProbeResult(
          category: category,
          mimeType: mime,
          width: result.width,
          height: result.height,
          durationMs: result.durationMs,
          sampleRate: result.sampleRate,
          pageCount: result.pageCount,
          encoding: result.encoding,
        );
      }
    }
    return MediaProbeResult(
      category: category,
      mimeType: mime,
      note: 'no structured metadata found',
    );
  }

  ParsedMediaAttributes? Function(MediaProbeInput input)? _probeFor(
    MediaCategory category,
  ) => switch (category) {
    MediaCategory.image => _image.parse,
    MediaCategory.video => _video.parse,
    MediaCategory.audio => _audio.parse,
    MediaCategory.voice => _audio.parse,
    MediaCategory.document => _document.parse,
    _ => null,
  };

  static MediaCategory? _sniffCategory(List<int> header) {
    if (MagicBytes.startsWith(header, MagicBytes.png)) {
      return MediaCategory.image;
    }
    if (MagicBytes.startsWith(header, MagicBytes.jpeg)) {
      return MediaCategory.image;
    }
    if (MagicBytes.startsWith(header, MagicBytes.gif87) ||
        MagicBytes.startsWith(header, MagicBytes.gif89)) {
      return MediaCategory.image;
    }
    // RIFF....WEBP — the WebP four-CC lives at offset 8.
    if (MagicBytes.startsWith(header, MagicBytes.webp) &&
        header.length >= 12 &&
        header[8] == 0x57 &&
        header[9] == 0x45 &&
        header[10] == 0x42 &&
        header[11] == 0x50) {
      return MediaCategory.image;
    }
    if (MagicBytes.startsWith(header, MagicBytes.pdf)) {
      return MediaCategory.document;
    }
    if (MagicBytes.startsWith(header, MagicBytes.zip) ||
        MagicBytes.startsWith(header, MagicBytes.zipEmpty)) {
      return MediaCategory.archive;
    }
    if (MagicBytes.startsWith(header, MagicBytes.ogg)) {
      return MediaCategory.audio;
    }
    return null;
  }
}

/// Parser contract: identify a file from its header window.
abstract interface class MediaMetadataParser {
  /// How many leading bytes the data layer feeds the parser.
  static const int defaultHeaderWindow = 64 * 1024;

  /// Maximum header window this parser needs.
  int get headerWindow;

  /// The identified metadata of [input]; never throws, never null.
  MediaProbeResult parse(MediaProbeInput input);
}
