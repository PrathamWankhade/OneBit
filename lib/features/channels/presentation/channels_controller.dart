import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_sort.dart';
import 'package:onebit/features/messaging/domain/channels/conversation_summary.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';

/// The last message of a channel (delivery/read presentation only).
final channelLastMessageProvider =
    StreamProvider.family.autoDispose<Result<List<Message>>, String>(
      (ref, channelId) => ref
          .watch(messageRepositoryProvider)
          .watchChannel(channelId, limit: 1),
    );

/// Delivery chip of the last outbound message; `null` for inbound-only
/// channels and deleted messages.
OneBitStatusPreset? deliveryPresetFor(Message? message, String localNodeId) {
  if (message == null || message.sender != localNodeId) return null;
  return switch (message.status) {
    MessageStatus.created ||
    MessageStatus.queued ||
    MessageStatus.waiting ||
    MessageStatus.routing ||
    MessageStatus.relayed => OneBitStatusPreset.pending,
    MessageStatus.delivered => OneBitStatusPreset.completed,
    MessageStatus.verified || MessageStatus.read => OneBitStatusPreset.verified,
    MessageStatus.expired || MessageStatus.failed => OneBitStatusPreset.failed,
    MessageStatus.deleted => null,
  };
}

/// Renders the conversation list; owns every channel-level action.
final AsyncNotifierProvider<ChannelsController, ChannelsView>
channelsViewProvider = AsyncNotifierProvider<ChannelsController, ChannelsView>(
  ChannelsController.new,
);

final class ChannelsView {
  const ChannelsView({
    required this.summaries,
    required this.offline,
    required this.loaded,
    this.error,
  });

  /// Active conversations, pinned-first then last-activity.
  final List<ConversationSummary> summaries;

  /// Whether the mesh engine is not running (list stays usable).
  final bool offline;

  /// Whether the conversation stream has emitted at least once.
  final bool loaded;

  /// Stream failure, when the list could not load.
  final Object? error;

  bool get isEmpty => summaries.isEmpty;
}

final class ChannelsController extends AsyncNotifier<ChannelsView> {
  ChannelRepository get _channels => ref.read(channelRepositoryProvider);

  @override
  Future<ChannelsView> build() async {
    final summariesAsync = ref.watch(conversationSummariesProvider);
    final meshAsync = ref.watch(
      meshStateProvider,
      (prev, next) => next.value?.value,
    );

    final engineState = meshAsync;
    final offline =
        engineState != null && engineState != MeshEngineState.running;

    if (summariesAsync.hasError) {
      return ChannelsView(
        summaries: const [],
        offline: offline,
        loaded: true,
        error: summariesAsync.error,
      );
    }
    final result = summariesAsync.value;
    if (result == null) {
      return ChannelsView(summaries: const [], offline: offline, loaded: false);
    }
    if (result.isErr) {
      return ChannelsView(
        summaries: const [],
        offline: offline,
        loaded: true,
        error: result.failure,
      );
    }
    final summaries = ConversationSorter.sort(result.value!);
    return ChannelsView(summaries: summaries, offline: offline, loaded: true);
  }

  /// Re-runs the conversation stream (error recovery).
  void retry() => ref.invalidate(conversationSummariesProvider);

  /// Soft-hides the channel; returns true on success (undo snackbar).
  Future<bool> archive(String channelId) async =>
      (await _channels.archive(channelId)).isOk;

  /// Brings an archived channel back; returns true on success.
  Future<bool> restore(String channelId) async =>
      (await _channels.archive(channelId, archived: false)).isOk;

  Future<bool> setPinned(String channelId, {required bool pinned}) async =>
      (await _channels.setPinned(channelId, pinned: pinned)).isOk;

  Future<bool> setMuted(String channelId, {required bool muted}) async {
    final result = muted
        ? await _channels.setMuted(channelId)
        : await _channels.unmute(channelId);
    return result.isOk;
  }

  /// Resets the unread counter of the channel.
  Future<bool> markRead(String channelId) async {
    final result = await ref
        .read(messagingEngineProvider)
        .markChannelRead(channelId);
    return result.isOk;
  }
}
