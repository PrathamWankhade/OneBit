import 'package:flutter/foundation.dart';

import 'message.dart';

/// The deterministic total-order key of a message in a channel timeline.
///
/// Precedence: timestamp → sequence → packetOrder → messageId. The last
/// fallback (bytewise message id) guarantees the order is a strict total
/// order even when everything else collides, which is what makes
/// cursor-based pagination stable and conflict resolution deterministic.
@immutable
final class MessageOrderKey implements Comparable<MessageOrderKey> {
  const MessageOrderKey({
    required this.timestamp,
    required this.sequence,
    required this.packetOrder,
    required this.messageId,
  });

  final DateTime timestamp;
  final int sequence;
  final int packetOrder;
  final String messageId;

  factory MessageOrderKey.of(Message message) => MessageOrderKey(
    timestamp: message.timestamp,
    sequence: message.sequence,
    packetOrder: message.packetOrder,
    messageId: message.messageId,
  );

  /// Strict ordering: newer messages compare greater.
  @override
  int compareTo(MessageOrderKey other) {
    final at = timestamp.compareTo(other.timestamp);
    if (at != 0) return at;
    final seq = sequence.compareTo(other.sequence);
    if (seq != 0) return seq;
    final order = packetOrder.compareTo(other.packetOrder);
    if (order != 0) return order;
    return messageId.compareTo(other.messageId);
  }

  /// True when this key is strictly older than [other].
  bool isOlderThan(MessageOrderKey other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is MessageOrderKey && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(timestamp, sequence, packetOrder, messageId);

  @override
  String toString() =>
      'OrderKey(${timestamp.millisecondsSinceEpoch}/$sequence/$packetOrder/$messageId)';
}

/// Ordering engine: computes per-channel ordering keys and resolves
/// conflicts deterministically.
///
/// The engine is state-free on purpose (everything is derivable from the
/// persisted message rows); a channel's ordering is a pure function of its
/// messages, so delayed packets can never corrupt the timeline.
abstract final class OrderingEngine {
  const OrderingEngine._();

  /// Comparator over [Message]s implementing the timeline total order
  /// (newest last). Stable and replayable — safe for sort() and pagination.
  static int compareMessages(Message a, Message b) =>
      MessageOrderKey.of(a).compareTo(MessageOrderKey.of(b));

  /// Sorts a mixed batch (delayed arrivals included) into timeline order.
  static List<Message> sortTimeline(Iterable<Message> messages) {
    final list = messages.toList();
    list.sort(compareMessages);
    return list;
  }

  /// Resolves two messages that arrived with equivalent ordering keys into
  /// a definitive precedence: the more "authoritative" origin wins — an
  /// origin-assigned sequence beats a local arrival index (packetOrder).
  static Message resolveConflict(Message local, Message remote) {
    if (local.sequence > 0 && remote.sequence == 0) return local;
    if (local.sequence == 0 && remote.sequence > 0) return remote;
    return compareMessages(local, remote) >= 0 ? local : remote;
  }
}

/// Cursor for keyset pagination: "everything strictly older than X".
///
/// Cursor paging replaces offset paging for the timeline so 100k+ message
/// channels page in O(log n) per fetch and never skip or duplicate rows
/// while new messages arrive.
@immutable
final class TimelineCursor {
  const TimelineCursor(this.key);

  final MessageOrderKey key;

  /// The cursor positioned before the newest message (top of timeline).
  static TimelineCursor? newest() => null;

  /// Cursor for the oldest message of a page, for the next older page.
  static TimelineCursor after(Message lastOfPage) =>
      TimelineCursor(MessageOrderKey.of(lastOfPage));
}

/// One page of a channel timeline.
@immutable
final class MessagePage {
  const MessagePage({
    required this.items,
    required this.cursor,
    required this.hasMore,
  });

  /// Messages in ascending (chronological) order.
  final List<Message> items;

  /// Cursor referencing the oldest message of this page, for the next
  /// page request; null when this is the newest page.
  final TimelineCursor? cursor;

  /// Whether older messages exist past this page.
  final bool hasMore;

  /// Empty result at the oldest end.
  static const MessagePage end = MessagePage(
    items: [],
    cursor: null,
    hasMore: false,
  );

  int get itemCount => items.length;

  MessagePage copyWith({
    List<Message>? items,
    TimelineCursor? cursor,
    bool? hasMore,
  }) => MessagePage(
    items: items ?? this.items,
    cursor: cursor ?? this.cursor,
    hasMore: hasMore ?? this.hasMore,
  );
}
