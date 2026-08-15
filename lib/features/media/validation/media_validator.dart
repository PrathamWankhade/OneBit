import 'package:flutter/foundation.dart';

import '../attachments/attachment.dart';
import '../attachments/media_type_registry.dart';
import '../preview/media_metadata_parser.dart';
import 'validation_result.dart';

/// Everything a validation run needs to judge one payload.
@immutable
final class MediaValidationRequest {
  const MediaValidationRequest({
    required this.fileName,
    required this.sizeBytes,
    required this.headerBytes,
    this.declaredMimeType,
    this.declaredCategory,
    this.computedSha256,
    this.expectedSha256,
  });

  final String fileName;
  final int sizeBytes;
  final List<int> headerBytes;
  final String? declaredMimeType;
  final MediaCategory? declaredCategory;

  /// SHA-256 computed during staging (hex), when already available.
  final String? computedSha256;

  /// Declared reference hash (compare when both present).
  final String? expectedSha256;
}

/// Seams the pure rule engine needs — provided by the engine at runtime.
abstract interface class MediaValidationContext {
  /// True when another catalog entry already carries this hash.
  Future<bool> existsBySha256(String sha256);

  /// Whether at least [bytes] of storage are available for a new payload.
  Future<bool> storageAvailable(int bytes);
}

/// One validation rule (pure).
abstract interface class ValidationRule {
  /// Stable id (e.g. `tooLarge`, `badExtension`).
  String get code;

  /// Runs the check; returns an issue or null (pass).
  Future<ValidationIssue?> check(
    MediaValidationRequest request,
    MediaValidationContext context,
  );
}

/// The production validator: runs the full rule set and never throws.
///
/// Defaults follow the supported file-type families; limits are
/// configurable so tests can exercise every rule cheaply.
final class MediaValidator implements ValidationRule {
  MediaValidator({
    List<ValidationRule>? rules,
    this.maxSizeBytes = _defaultMaxSizeBytes,
  }) : _rules = List.unmodifiable(
         rules ?? defaultRules(maxSizeBytes: maxSizeBytes),
       );

  /// Default attach limit: 1 GiB (BLE links move slowly — big files are
  /// legal but discouraged; the limit lives in one place).
  static const int _defaultMaxSizeBytes = 1024 * 1024 * 1024;

  final int maxSizeBytes;
  final List<ValidationRule> _rules;

  /// The 7-rule production set, bound to [maxSizeBytes].
  static List<ValidationRule> defaultRules({required int maxSizeBytes}) => [
    _SizeRule(maxSizeBytes: maxSizeBytes),
    const _TypeRule(),
    const _ExtensionRule(),
    const _ChecksumRule(),
    const _CorruptionRule(),
    const _DuplicateRule(),
    const _StorageRule(),
  ];

  @override
  String get code => 'mediaValidator';

  /// Runs every rule; returns [ValidationResult.ok] for a clean file.
  Future<ValidationResult> validate(
    MediaValidationRequest request,
    MediaValidationContext context,
  ) async {
    var result = ValidationResult.ok;
    for (final rule in _rules) {
      final issue = await rule.check(request, context);
      if (issue != null) {
        result = result.plus(issue);
      }
    }
    return result;
  }

  @override
  Future<ValidationIssue?> check(
    MediaValidationRequest request,
    MediaValidationContext context,
  ) async {
    final result = await validate(request, context);
    if (!result.hasErrors) return null;
    return ValidationIssue(
      code: 'validationFailed',
      message: '${result.errors.length} rule(s) failed',
    );
  }
}

final class _SizeRule implements ValidationRule {
  const _SizeRule({required this.maxSizeBytes});

  final int maxSizeBytes;

  @override
  String get code => 'tooLarge';

  @override
  Future<ValidationIssue?> check(
    MediaValidationRequest request,
    MediaValidationContext context,
  ) async => request.sizeBytes > maxSizeBytes
      ? ValidationIssue(
          code: code,
          message:
              'file is ${request.sizeBytes} bytes, limit is '
              '$maxSizeBytes',
        )
      : null;
}

final class _TypeRule implements ValidationRule {
  const _TypeRule();

  @override
  String get code => 'unsupportedType';

  static const Set<MediaCategory> _supported = {
    MediaCategory.image,
    MediaCategory.video,
    MediaCategory.audio,
    MediaCategory.voice,
    MediaCategory.document,
    MediaCategory.archive,
    MediaCategory.binary,
    MediaCategory.custom,
  };

  @override
  Future<ValidationIssue?> check(
    MediaValidationRequest request,
    MediaValidationContext context,
  ) async {
    final declared = request.declaredCategory;
    if (declared != null && !_supported.contains(declared)) {
      return ValidationIssue(
        code: code,
        message: 'category ${declared.wireName} is not a supported family',
      );
    }
    return null;
  }
}

final class _ExtensionRule implements ValidationRule {
  const _ExtensionRule();

  @override
  String get code => 'badExtension';

  /// Extensions that must never be transferred as attachments.
  static const Set<String> _dangerous = {
    'exe',
    'dll',
    'so',
    'dylib',
    'bat',
    'cmd',
    'sh',
    'ps1',
    'vbs',
    'js',
    'jar',
    'apk',
    'php',
    'py',
  };

  @override
  Future<ValidationIssue?> check(
    MediaValidationRequest request,
    MediaValidationContext context,
  ) async {
    final extension = MediaTypeRegistry.extensionOf(request.fileName);
    if (_dangerous.contains(extension)) {
      return ValidationIssue(
        code: code,
        message: 'refusing executable/script extension ".$extension"',
      );
    }
    final registryCategory = MediaTypeRegistry.categoryForFileName(
      request.fileName,
    );
    // Extension families the registry knows but the declared family disagrees.
    if (request.declaredCategory != null &&
        registryCategory != MediaCategory.binary &&
        registryCategory != request.declaredCategory) {
      return ValidationIssue(
        code: code,
        message:
            'extension "$extension" maps to '
            '${registryCategory.wireName}, declared '
            '${request.declaredCategory!.wireName}',
        severity: ValidationSeverity.warning,
      );
    }
    return null;
  }
}

final class _ChecksumRule implements ValidationRule {
  const _ChecksumRule();

  @override
  String get code => 'checksumMismatch';

  @override
  Future<ValidationIssue?> check(
    MediaValidationRequest request,
    MediaValidationContext context,
  ) async {
    final computed = request.computedSha256;
    final expected = request.expectedSha256;
    if (computed == null || expected == null || computed == expected) {
      return null;
    }
    return ValidationIssue(
      code: code,
      message: 'computed $computed does not match declared $expected',
    );
  }
}

final class _CorruptionRule implements ValidationRule {
  const _CorruptionRule();

  @override
  String get code => 'corruptHeader';

  @override
  Future<ValidationIssue?> check(
    MediaValidationRequest request,
    MediaValidationContext context,
  ) async {
    final declared = request.declaredCategory;
    if (declared == null ||
        declared == MediaCategory.binary ||
        declared == MediaCategory.custom) {
      return null;
    }
    final sniffed = _sniffCategory(request.headerBytes);
    if (sniffed == null) return null; // unknown magic — trust the extension
    if (sniffed != declared) {
      switch (declared) {
        case MediaCategory.image:
        case MediaCategory.video:
        case MediaCategory.audio:
        case MediaCategory.document:
        case MediaCategory.archive:
          return ValidationIssue(
            code: code,
            message:
                'header identifies ${sniffed.wireName}, declared '
                '${declared.wireName} — payload may be corrupt',
          );
        default:
          return null;
      }
    }
    return null;
  }

  static MediaCategory? _sniffCategory(List<int> header) {
    if (MagicBytes.startsWith(header, MagicBytes.png) ||
        MagicBytes.startsWith(header, MagicBytes.jpeg) ||
        MagicBytes.startsWith(header, MagicBytes.gif87) ||
        MagicBytes.startsWith(header, MagicBytes.gif89)) {
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

final class _DuplicateRule implements ValidationRule {
  const _DuplicateRule();

  @override
  String get code => 'duplicate';

  @override
  Future<ValidationIssue?> check(
    MediaValidationRequest request,
    MediaValidationContext context,
  ) async {
    final sha = request.computedSha256;
    if (sha == null) return null;
    final duplicate = await context.existsBySha256(sha);
    if (!duplicate) return null;
    return ValidationIssue(
      code: code,
      message: 'identical payload already exists in the catalog',
      severity: ValidationSeverity.warning,
    );
  }
}

final class _StorageRule implements ValidationRule {
  const _StorageRule();

  @override
  String get code => 'insufficientSpace';

  @override
  Future<ValidationIssue?> check(
    MediaValidationRequest request,
    MediaValidationContext context,
  ) async {
    final available = await context.storageAvailable(request.sizeBytes);
    if (!available) {
      return ValidationIssue(
        code: code,
        message: 'not enough free storage for ${request.sizeBytes} bytes',
      );
    }
    return null;
  }
}
