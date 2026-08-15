import 'package:flutter/foundation.dart';

import '../tables/enums.dart' show MessageStatus, MessageType;

/// Immutable filter for message queries.
///
/// Content search over ciphertext is impossible by design; filtering is
/// metadata-based (channel, sender, status, type, time window). [text] is a
/// free-text metadata search over sender node id and message id.
@immutable
final class MessageQuery {
  const MessageQuery({
    this.channelId,
    this.sender,
    this.status,
    this.messageType,
    this.before,
    this.after,
    this.includeDeleted = false,
    this.text,
  });

  /// Only messages in this channel.
  final String? channelId;

  /// Only messages from this sender node id.
  final String? sender;

  /// Only messages in this lifecycle state.
  final MessageStatus? status;

  /// Only messages of this content kind.
  final MessageType? messageType;

  /// Only messages strictly older than this timestamp.
  final DateTime? before;

  /// Only messages strictly newer than this timestamp.
  final DateTime? after;

  /// Whether soft-deleted messages are included (default: hidden).
  final bool includeDeleted;

  /// Free-text metadata search: substring match against sender node id or
  /// message id (case-sensitive, LIKE). Encrypted payloads are never
  /// searchable — content search arrives with the decryption layer.
  final String? text;
}
