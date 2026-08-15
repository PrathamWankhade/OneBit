import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/features/messaging/domain/channels/channel.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_ordering.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';

/// Pinned messages of a channel with their bodies resolved.
final channelPinnedMessagesProvider =
    FutureProvider.family<Result<List<Message>>, String>((
      ref,
      channelId,
    ) async {
      final engine = ref.watch(messagingEngineProvider);
      final pinned = await engine.pinnedMessages(channelId);
      if (pinned.isErr) return Err(pinned.failure!);
      final messages = ref.read(messageRepositoryProvider);
      final resolved = <Message>[];
      for (final entry in pinned.value!) {
        final found = await messages.getMessage(entry.messageId);
        final message = found.value;
        if (message != null) resolved.add(message);
      }
      return Ok(resolved);
    });

/// Renders the channel timeline; owns pagination and channel actions.
final channelDetailsViewProvider = AsyncNotifierProvider.family
    .autoDispose<ChannelDetailsController, ChannelDetailsView, String>(
      ChannelDetailsController.new,
    );

final class ChannelDetailsView {
  const ChannelDetailsView({
    required this.loaded,
    this.channel,
    this.timeline = const [],
    this.pinned = const [],
    this.hasMore = false,
    this.loadingOlder = false,
    this.offline = false,
    this.error,
  });

  /// Whether the channel lookup and timeline have resolved.
  final bool loaded;

  /// The channel, or `null` when the id does not exist.
  final Channel? channel;

  /// Messages, oldest-first (including paged history).
  final List<Message> timeline;

  /// Pinned messages with bodies (newest first).
  final List<Message> pinned;

  /// Whether older messages exist past the timeline head.
  final bool hasMore;

  /// Whether an older page is being fetched.
  final bool loadingOlder;

  /// Whether the mesh engine is not running.
  final bool offline;

  /// Stream failure, when the timeline could not load.
  final Object? error;
}

final class ChannelDetailsController extends AsyncNotifier<ChannelDetailsView> {
  ChannelDetailsController(this.arg);

  /// The channel id this controller renders.
  final String arg;

  /// Page size of the timeline stream; a full page implies older history.
  static const int _timelinePageSize = 150;

  List<Message> _older = <Message>[];
  List<Message> _streamMessages = const <Message>[];
  List<Message> _pinned = const <Message>[];
  Channel? _channel;
  bool _channelResolved = false;
  bool _offline = false;
  bool _hasMore = false;
  bool _loadingOlder = false;
  Object? _error;

  String get _channelId => arg;

  @override
  Future<ChannelDetailsView> build() async {
    final channelAsync = ref.watch(channelProvider(_channelId));
    final timelineAsync = ref.watch(channelTimelineProvider(_channelId));
    final pinnedAsync = ref.watch(channelPinnedMessagesProvider(_channelId));
    final meshAsync = ref.watch(meshStateProvider);

    _channel = channelAsync.value?.value;
    _channelResolved = channelAsync.value != null;
    _pinned = pinnedAsync.value?.value ?? const <Message>[];
    final engineState = meshAsync.value?.value;
    _offline = engineState != null && engineState != MeshEngineState.running;

    if (channelAsync.hasError) {
      _error = channelAsync.error;
    } else if (timelineAsync.hasError) {
      _error = timelineAsync.error;
    } else {
      final result = timelineAsync.value;
      if (result != null && result.isErr) {
        _error = result.failure;
      } else {
        _error = null;
        _streamMessages = result?.value ?? const <Message>[];
        // A full stream page means older history may exist; the
        // load-older affordance must appear before the first tap, since
        // `_hasMore` only updates after a page is fetched. Once older
        // pages are in, keep the value set by [loadOlder].
        if (_older.isEmpty) {
          _hasMore = _streamMessages.length >= _timelinePageSize;
        }
      }
    }

    return _compose();
  }

  ChannelDetailsView _compose() {
    final seen = <String>{};
    final timeline = <Message>[..._older, ..._streamMessages]
        .where((message) => !message.deleted && message.body.isNotEmpty)
        .where((message) => seen.add(message.messageId))
        .toList();
    final loaded =
        _channelResolved ||
        _error != null ||
        _streamMessages.isNotEmpty ||
        _older.isNotEmpty;

    return ChannelDetailsView(
      loaded: loaded,
      channel: _channel,
      timeline: timeline,
      pinned: _pinned.reversed.toList(),
      hasMore: _hasMore,
      loadingOlder: _loadingOlder,
      offline: _offline,
      error: _error,
    );
  }

  /// Fetches the next older page (keyset pagination through the engine).
  Future<void> loadOlder() async {
    if (_loadingOlder) return;
    final oldestKnown = _older.isNotEmpty
        ? _older.first
        : _streamMessages.firstOrNull;
    if (oldestKnown == null) return;

    _loadingOlder = true;
    state = AsyncData(_compose());

    final cursor = TimelineCursor.after(oldestKnown);
    final result = await ref
        .read(messagingEngineProvider)
        .pageChannel(_channelId, cursor: cursor, limit: 50);

    if (ref.mounted) {
      _loadingOlder = false;
      if (result.isOk) {
        final page = result.value!;
        _older = [...page.items, ..._older];
        _hasMore = page.hasMore;
      }
      state = AsyncData(_compose());
    }
  }

  /// Re-runs every channel stream (error recovery).
  void retry() {
    ref.invalidate(channelProvider(_channelId));
    ref.invalidate(channelTimelineProvider(_channelId));
    ref.invalidate(channelPinnedMessagesProvider(_channelId));
  }

  Future<bool> markRead() async {
    final result = await ref
        .read(messagingEngineProvider)
        .markChannelRead(_channelId);
    return result.isOk;
  }

  Future<bool> setPinned({required bool pinned}) async {
    final result = await ref
        .read(channelRepositoryProvider)
        .setPinned(_channelId, pinned: pinned);
    return result.isOk;
  }

  Future<bool> setMuted({required bool muted}) async {
    final channels = ref.read(channelRepositoryProvider);
    final result = muted
        ? await channels.setMuted(_channelId)
        : await channels.unmute(_channelId);
    return result.isOk;
  }

  /// Soft-hides the channel; returns true on success.
  Future<bool> archive() async {
    final result = await ref
        .read(channelRepositoryProvider)
        .archive(_channelId);
    return result.isOk;
  }
}
