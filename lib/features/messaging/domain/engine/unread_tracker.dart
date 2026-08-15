import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';

import '../channels/channel_repository.dart';
import '../messages/message.dart';

/// Single writer of the per-channel unread counters and conversation-list
/// metadata (last message, preview, activity stamp).
///
/// The engine is the only caller of the channel bump path; repositories are
/// dumb storage underneath it.
final class UnreadTracker {
  UnreadTracker({required this._channels, required this._logger});

  final ChannelRepository _channels;
  final AppLogger _logger;

  static const _tag = LogTags.messaging;

  /// An inbound message arrived for this channel: bumps unread by one and
  /// freshens the conversation metadata.
  Future<Result<void>> onInbound(Message message) =>
      _bump(message, unreadDelta: 1);

  /// An outbound message was created: refresh the conversation metadata
  /// without touching the unread counter.
  Future<Result<void>> onOutbound(Message message) => _bump(message);

  Future<Result<void>> _bump(Message message, {int unreadDelta = 0}) async {
    final result = await _channels.bumpActivity(
      message.channelId,
      unreadDelta: unreadDelta,
      lastMessageId: message.messageId,
      lastMessageAt: message.timestamp,
    );
    if (result is Err<void>) {
      _logger.warning(
        'unread: bump(${message.channelId}) failed: ${result.failure}',
        tag: _tag,
      );
    }
    return result;
  }

  /// Marks the whole channel read (resets the counter).
  Future<Result<void>> markChannelRead(String channelId) async {
    final result = await _channels.markRead(channelId);
    if (result is Err<void>) {
      _logger.warning(
        'unread: markRead($channelId) failed: ${result.failure}',
        tag: _tag,
      );
    }
    return result;
  }

  /// Single-line preview clamp for the conversation list.
  static String preview(String body, {int maxLength = 96}) {
    final flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.length <= maxLength) return flat;
    return '${flat.substring(0, maxLength - 1)}…';
  }
}
