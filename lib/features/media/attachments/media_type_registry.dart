import 'attachment.dart';

/// The registry of supported file types.
///
/// Single source of truth for extension → MIME → [MediaCategory] mapping,
/// used by validation, probing and staging. Unknown extensions map to
/// `binary` / `custom`; the registry never *rejects* a file by itself —
/// policy lives in the validator's rule configuration.
abstract final class MediaTypeRegistry {
  const MediaTypeRegistry._();

  /// Builds the canonical MIME type for [fileName] (fallback: `application/octet-stream`).
  static String mimeForFileName(String fileName) =>
      extensionMime[extensionOf(fileName)] ?? 'application/octet-stream';

  /// Guesses the category from [fileName] (sniffing wins where possible).
  static MediaCategory categoryForFileName(String fileName) =>
      extensionCategory[extensionOf(fileName)] ?? MediaCategory.binary;

  /// Only characters safe on every OS and wire format survive.
  static String sanitizeFileName(String fileName) {
    final name = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return name.isEmpty ? 'attachment' : name;
  }

  /// Lowercased extension without the dot ('' when none).
  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  static const Map<String, String> extensionMime = <String, String>{
    // Images
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'bmp': 'image/bmp',
    // Video
    'mp4': 'video/mp4',
    'mkv': 'video/x-matroska',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    // Audio
    'aac': 'audio/aac',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'm4a': 'audio/mp4',
    // Documents
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'md': 'text/markdown',
    'docx':
        'application/vnd.openxmlformats-officedocument.'
        'wordprocessingml.document',
    'doc': 'application/msword',
    'xlsx':
        'application/vnd.openxmlformats-officedocument.'
        'spreadsheetml.sheet',
    'csv': 'text/csv',
    'json': 'application/json',
    // Archives
    'zip': 'application/zip',
    'tar': 'application/x-tar',
    'gz': 'application/gzip',
    'apk': 'application/vnd.android.package-archive',
  };

  static const Map<String, MediaCategory> extensionCategory =
      <String, MediaCategory>{
        'png': MediaCategory.image,
        'jpg': MediaCategory.image,
        'jpeg': MediaCategory.image,
        'webp': MediaCategory.image,
        'gif': MediaCategory.image,
        'bmp': MediaCategory.image,
        'mp4': MediaCategory.video,
        'mkv': MediaCategory.video,
        'mov': MediaCategory.video,
        'webm': MediaCategory.video,
        'aac': MediaCategory.audio,
        'mp3': MediaCategory.audio,
        'wav': MediaCategory.audio,
        'ogg': MediaCategory.audio,
        'm4a': MediaCategory.audio,
        'pdf': MediaCategory.document,
        'txt': MediaCategory.document,
        'md': MediaCategory.document,
        'docx': MediaCategory.document,
        'doc': MediaCategory.document,
        'xlsx': MediaCategory.document,
        'csv': MediaCategory.document,
        'json': MediaCategory.document,
        'zip': MediaCategory.archive,
        'tar': MediaCategory.archive,
        'gz': MediaCategory.archive,
        'apk': MediaCategory.archive,
      };

  /// The extension families the attach pipeline will compress eagerly.
  static bool isCompressibleCategory(MediaCategory category) =>
      category == MediaCategory.document || category == MediaCategory.archive;
}
