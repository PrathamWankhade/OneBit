import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';

import '../messages/message.dart';
import '../search/search_repository.dart';

/// Keeps the FTS index a write-through mirror of the messages table.
///
/// Every message mutation (insert, edit, delete) funnels through here so the
/// index can never diverge from the rows the engine serves.
final class SearchIndexer {
  SearchIndexer({required this._repository, required this._logger});

  final SearchRepository _repository;
  final AppLogger _logger;

  static const _tag = LogTags.messaging;

  /// Indexes [message] (insert/edit path).
  ///
  /// [nodeName] is the peer display name used to make sender text
  /// searchable; it defaults to the node id when unknown.
  Future<Result<void>> indexMessage(Message message, {String? nodeName}) =>
      _repository.indexMessage(
        messageId: message.messageId,
        channelId: message.channelId,
        body: message.body,
        sender: message.sender,
        nodeName: nodeName ?? message.sender,
        type: message.type.name,
        timestampMs: message.timestamp.millisecondsSinceEpoch,
      );

  /// Evicts a message from the index (delete/tombstone path).
  Future<Result<void>> remove(String messageId) async {
    final result = await _repository.removeFromIndex(messageId);
    if (result is Err<void>) {
      _logger.warning(
        'search: remove($messageId) failed: ${result.failure}',
        tag: _tag,
      );
    }
    return result;
  }

  /// Rebuilds the whole index from the message table (startup/repair).
  Future<Result<int>> rebuild() => _repository.rebuildIndex();
}
