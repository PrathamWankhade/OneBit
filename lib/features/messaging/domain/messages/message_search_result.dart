import 'package:flutter/foundation.dart';

import '../messages/message_metadata.dart';
import '../messages/message_priority.dart';
import '../messages/message_status.dart';
import '../messages/message_type.dart';

/// One hit of a message search, with the relevance rank from the FTS index.
@immutable
final class MessageSearchResult {
  const MessageSearchResult({
    required this.messageId,
    required this.channelId,
    required this.channelTitle,
    required this.sender,
    required this.receiver,
    required this.type,
    required this.status,
    required this.priority,
    required this.body,
    required this.snippet,
    required this.timestamp,
    required this.sequence,
    required this.deleted,
    required this.starred,
    required this.readAt,
    this.pinned = false,
    this.rank = 0.0,
    this.metadata = const MessageMetadata(),
  });

  final String messageId;
  final String channelId;
  final String channelTitle;
  final String sender;
  final String? receiver;
  final MessageType type;
  final MessageStatus status;
  final MessagePriority priority;

  /// Searchable content.
  final String body;

  /// FTS-generated highlight snippet.
  final String snippet;

  final DateTime timestamp;
  final int sequence;
  final bool deleted;
  final bool starred;
  final DateTime? readAt;

  /// True when the message is pinned in its channel.
  final bool pinned;

  /// FTS bm25 relevance (lower = better match).
  final double rank;

  final MessageMetadata metadata;

  @override
  bool operator ==(Object other) =>
      other is MessageSearchResult && other.messageId == messageId;

  @override
  int get hashCode => messageId.hashCode;
}

/// Filters for [SearchRepository.search]. All fields optional.
@immutable
final class MessageSearchQuery {
  const MessageSearchQuery({
    this.terms = '',
    this.channelId,
    this.sender,
    this.type,
    this.from,
    this.to,
    this.onlyUnread = false,
    this.onlyPinned = false,
    this.includeDeleted = false,
  });

  /// Keyword terms (FTS MATCH string; empty matches everything indexed).
  final String terms;

  /// Restrict to a single channel.
  final String? channelId;

  /// Restrict to a sender node id.
  final String? sender;

  /// Restrict to a content kind.
  final MessageType? type;

  /// Inclusive window start.
  final DateTime? from;

  /// Exclusive window end.
  final DateTime? to;

  /// Only messages the local user has not read.
  final bool onlyUnread;

  /// Only messages pinned in their channel.
  final bool onlyPinned;

  /// Include soft-deleted messages in results.
  final bool includeDeleted;

  /// If [terms] is non-empty, anything matches; otherwise the filters alone
  /// constrain the result set.
  bool get isEmpty =>
      terms.trim().isEmpty &&
      channelId == null &&
      sender == null &&
      type == null &&
      from == null &&
      to == null &&
      !onlyUnread &&
      !onlyPinned;

  MessageSearchQuery copyWith({
    String? terms,
    String? channelId,
    String? sender,
    MessageType? type,
    DateTime? from,
    DateTime? to,
    bool? onlyUnread,
    bool? onlyPinned,
    bool? includeDeleted,
  }) => MessageSearchQuery(
    terms: terms ?? this.terms,
    channelId: channelId ?? this.channelId,
    sender: sender ?? this.sender,
    type: type ?? this.type,
    from: from ?? this.from,
    to: to ?? this.to,
    onlyUnread: onlyUnread ?? this.onlyUnread,
    onlyPinned: onlyPinned ?? this.onlyPinned,
    includeDeleted: includeDeleted ?? this.includeDeleted,
  );
}

/// A page of search results.
@immutable
final class SearchPage<T> {
  const SearchPage({
    required this.items,
    required this.offset,
    required this.limit,
    required this.hasMore,
  });

  final List<T> items;
  final int offset;
  final int limit;
  final bool hasMore;

  int get itemCount => items.length;
}
