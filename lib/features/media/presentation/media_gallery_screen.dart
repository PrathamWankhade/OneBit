import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/media/attachments/attachment.dart';
import 'package:onebit/features/media/presentation/media_gallery_controller.dart';
import 'package:onebit/features/media/presentation/media_providers.dart';
import 'package:onebit/l10n/app_localizations.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/formatting/onebit_formatters.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_radius.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Rendered thumbnail bytes of an attachment (null when unavailable).
final galleryThumbnailProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, attachmentId) async {
      final engine = ref.watch(mediaEngineProvider);
      final thumb = (await engine.generateThumbnail(attachmentId)).value;
      final path = thumb?.localPath;
      if (path == null) return null;
      try {
        return await File(path).readAsBytes();
      } on Object {
        return null;
      }
    });

/// Shared media gallery: every attachment of this node, filterable by
/// category (deep-linkable via [AppRoutePaths.gallery]).
class MediaGalleryScreen extends ConsumerWidget {
  const MediaGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(mediaGalleryControllerProvider);

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.mediaGalleryTitle)),
      body: switch (view) {
        AsyncData(:final value) => _GalleryBody(value: value),
        AsyncError(:final error) => OneBitErrorState(
          message: l10n.commonError,
          detail: '$error',
        ),
        _ => const OneBitLoadingIndicator(),
      },
    );
  }
}

final class _GalleryBody extends ConsumerWidget {
  const _GalleryBody({required this.value});

  final MediaGalleryView value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(mediaGalleryControllerProvider.notifier);

    if (value.loading) {
      return const OneBitLoadingIndicator();
    }
    if (value.failure != null) {
      return OneBitErrorState(
        message: l10n.galleryUnavailableTitle,
        detail: '$value.failure',
        onRetry: controller.retry,
        retryLabel: l10n.commonRetry,
      );
    }
    if (value.attachments.isEmpty) {
      return OneBitEmptyState(
        title: l10n.galleryEmptyTitle,
        message: l10n.galleryEmptyMessage,
        icon: OneBitIcons.attachFile,
      );
    }

    return Column(
      children: [
        const SizedBox(height: OneBitSpacing.s),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: OneBitSpacing.m),
          child: Row(
            children: [
              for (final filter in MediaGalleryFilter.values) ...[
                ChoiceChip(
                  label: Text(_filterLabel(l10n, filter)),
                  selected: value.filter == filter,
                  onSelected: (_) => controller.selectFilter(filter),
                ),
                const SizedBox(width: OneBitSpacing.xs),
              ],
            ],
          ),
        ),
        const SizedBox(height: OneBitSpacing.s),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              OneBitSpacing.m,
              OneBitSpacing.xs,
              OneBitSpacing.m,
              OneBitSpacing.m,
            ),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: OneBitSpacing.m,
              crossAxisSpacing: OneBitSpacing.m,
              childAspectRatio: 1.05,
            ),
            itemCount: value.attachments.length,
            itemBuilder: (context, index) {
              final attachment = value.attachments[index];
              return _AttachmentTile(attachment: attachment);
            },
          ),
        ),
      ],
    );
  }

  String _filterLabel(AppLocalizations l10n, MediaGalleryFilter filter) =>
      switch (filter) {
        MediaGalleryFilter.all => l10n.galleryFilterAll,
        MediaGalleryFilter.images => l10n.galleryFilterImages,
        MediaGalleryFilter.videos => l10n.galleryFilterVideos,
        MediaGalleryFilter.audio => l10n.galleryFilterAudio,
        MediaGalleryFilter.voiceNotes => l10n.galleryFilterVoiceNotes,
        MediaGalleryFilter.documents => l10n.galleryFilterDocuments,
      };
}

final class _AttachmentTile extends ConsumerWidget {
  const _AttachmentTile({required this.attachment});

  final Attachment attachment;

  IconData get _categoryIcon => switch (attachment.metadata.category) {
    MediaCategory.image => OneBitIcons.image,
    MediaCategory.video => OneBitIcons.video,
    MediaCategory.audio => OneBitIcons.audio,
    MediaCategory.voice => OneBitIcons.voiceNote,
    MediaCategory.document => OneBitIcons.document,
    MediaCategory.archive => OneBitIcons.archiveFile,
    MediaCategory.binary => OneBitIcons.binaryFile,
    MediaCategory.custom => OneBitIcons.file,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final showThumbnail =
        attachment.metadata.category == MediaCategory.image ||
        attachment.metadata.category == MediaCategory.video ||
        attachment.metadata.category == MediaCategory.voice;
    final thumbnail = showThumbnail
        ? ref.watch(galleryThumbnailProvider(attachment.attachmentId))
        : const AsyncData<Uint8List?>(null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(OneBitRadius.md),
            child: SizedBox(
              width: double.infinity,
              child: switch (thumbnail) {
                AsyncData(:final value) when value != null => Image.memory(
                  value,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
                _ => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(
                    _categoryIcon,
                    size: 36,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              },
            ),
          ),
        ),
        const SizedBox(height: OneBitSpacing.xs),
        Text(
          attachment.metadata.fileName,
          style: OneBitTypography.technicalStyle(
            fontSize: OneBitTypography.caption,
            color: scheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          OneBitFormatters.bytes(attachment.metadata.sizeBytes),
          style: OneBitTypography.technicalStyle(
            fontSize: OneBitTypography.caption,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
