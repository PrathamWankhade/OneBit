import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/media/attachments/attachment.dart';
import 'package:onebit/features/media/presentation/media_providers.dart';

/// Gallery category filter; `all` merges every attachment category.
enum MediaGalleryFilter { all, images, videos, audio, voiceNotes, documents }

/// Presentation state of the shared media gallery.
final class MediaGalleryView {
  const MediaGalleryView({
    this.filter = MediaGalleryFilter.all,
    this.attachments = const <Attachment>[],
    this.loading = true,
    this.failure,
  });

  final MediaGalleryFilter filter;

  /// Attachments of the selected [filter], newest first.
  final List<Attachment> attachments;

  /// Initial load in progress.
  final bool loading;

  /// Last load failure (null when the last load succeeded).
  final Object? failure;

  MediaGalleryView copyWith({
    MediaGalleryFilter? filter,
    List<Attachment>? attachments,
    bool? loading,
    Object? failure,
  }) => MediaGalleryView(
    filter: filter ?? this.filter,
    attachments: attachments ?? this.attachments,
    loading: loading ?? this.loading,
    failure: failure ?? this.failure,
  );
}

/// Loads the attachment catalog grouped by [MediaGalleryFilter].
final mediaGalleryControllerProvider =
    AsyncNotifierProvider.autoDispose<MediaGalleryController, MediaGalleryView>(
      MediaGalleryController.new,
    );

final class MediaGalleryController extends AsyncNotifier<MediaGalleryView> {
  @override
  Future<MediaGalleryView> build() => _load(MediaGalleryFilter.all);

  Future<void> selectFilter(MediaGalleryFilter filter) async {
    if (state.value?.filter == filter && !(state.value?.loading ?? false)) {
      return;
    }
    state = AsyncData(state.value!.copyWith(loading: true, failure: null));
    final loaded = await _load(filter);
    state = AsyncData(loaded);
  }

  Future<MediaGalleryView> _load(MediaGalleryFilter filter) async {
    final engine = ref.watch(mediaEngineProvider);
    final categories = switch (filter) {
      MediaGalleryFilter.all => const [
        MediaCategory.image,
        MediaCategory.video,
        MediaCategory.audio,
        MediaCategory.voice,
        MediaCategory.document,
      ],
      MediaGalleryFilter.images => const [MediaCategory.image],
      MediaGalleryFilter.videos => const [MediaCategory.video],
      MediaGalleryFilter.audio => const [MediaCategory.audio],
      MediaGalleryFilter.voiceNotes => const [MediaCategory.voice],
      MediaGalleryFilter.documents => const [MediaCategory.document],
    };

    final merged = <Attachment>[];
    for (final category in categories) {
      final result = await engine.listByCategory(category);
      if (result.isErr) {
        return MediaGalleryView(
          filter: filter,
          attachments: merged,
          loading: false,
          failure: result.failure,
        );
      }
      merged.addAll(result.value ?? const []);
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return MediaGalleryView(
      filter: filter,
      attachments: merged,
      loading: false,
    );
  }

  Future<void> retry() =>
      selectFilter(state.value?.filter ?? MediaGalleryFilter.all);
}
