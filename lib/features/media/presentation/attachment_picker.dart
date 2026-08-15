import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/features/media/attachments/attachment.dart';
import 'package:onebit/shared/design_system/components/onebit_bottom_sheets.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';

/// What the picker asks for.
enum AttachmentPickKind {
  /// Any file type.
  any,

  /// Image payloads (jpeg/png/gif/bmp/webp).
  image,

  /// Documents (pdf, text, office).
  document,
}

/// One user-chosen file, ready to be staged by the media engine.
final class AttachmentPick {
  const AttachmentPick({
    required this.fileName,
    required this.sourcePath,
    this.declaredCategory,
    this.declaredMimeType,
  });

  final String fileName;
  final String sourcePath;
  final MediaCategory? declaredCategory;
  final String? declaredMimeType;
}

/// Presentation seam for picking files to attach. Tests override this with
/// a fake; the production implementation uses the system file picker.
abstract interface class AttachmentPicker {
  /// Opens the picker and returns the chosen file (null when cancelled).
  Future<AttachmentPick?> pick(
    BuildContext context, {
    AttachmentPickKind kind = AttachmentPickKind.any,
  });
}

/// System file picker (file_picker plugin) driven by a labelled action
/// sheet so the caller picks an image / document / any file.
final class SystemAttachmentPicker implements AttachmentPicker {
  @override
  Future<AttachmentPick?> pick(
    BuildContext context, {
    AttachmentPickKind kind = AttachmentPickKind.any,
  }) async {
    final selection = await _sheet(context);
    if (selection == null) return null;
    final result = await FilePicker.pickFiles(
      type: _typeFor(selection),
      allowMultiple: false,
    );
    final files = result?.files;
    final file = (files == null || files.isEmpty) ? null : files.first;
    if (file == null || file.path == null) return null;
    return AttachmentPick(
      fileName: file.name,
      sourcePath: file.path!,
      declaredCategory: _categoryFor(selection),
      declaredMimeType: _mimeFor(selection, file.name),
    );
  }

  Future<AttachmentPickKind?> _sheet(BuildContext context) {
    final l10n = context.l10n;
    return showOneBitActionSheet<AttachmentPickKind>(
      context,
      title: l10n.composeAttachmentTitle,
      actions: [
        OneBitSheetAction(
          label: l10n.composeAttachmentImage,
          icon: OneBitIcons.image,
          value: AttachmentPickKind.image,
        ),
        OneBitSheetAction(
          label: l10n.composeAttachmentDocument,
          icon: OneBitIcons.document,
          value: AttachmentPickKind.document,
        ),
        OneBitSheetAction(
          label: l10n.composeAttachmentFile,
          icon: OneBitIcons.file,
          value: AttachmentPickKind.any,
        ),
      ],
    );
  }

  static FileType _typeFor(AttachmentPickKind kind) => switch (kind) {
    AttachmentPickKind.image => FileType.image,
    AttachmentPickKind.document => FileType.custom,
    AttachmentPickKind.any => FileType.any,
  };

  static MediaCategory? _categoryFor(AttachmentPickKind kind) => switch (kind) {
    AttachmentPickKind.image => MediaCategory.image,
    AttachmentPickKind.document => MediaCategory.document,
    AttachmentPickKind.any => null,
  };

  static String? _mimeFor(AttachmentPickKind kind, String fileName) =>
      switch (kind) {
        AttachmentPickKind.image => _imageMime(fileName),
        _ => null,
      };

  static String? _imageMime(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }
}

final attachmentPickerProvider = Provider<AttachmentPicker>(
  (ref) => SystemAttachmentPicker(),
);
