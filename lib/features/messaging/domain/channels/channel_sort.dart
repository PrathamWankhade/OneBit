import 'conversation_summary.dart';

/// Sort key of the conversation list.
enum ConversationSort {
  /// Newest last activity first (default).
  lastActivity,

  /// Alphabetical by title.
  title,

  /// Highest unread first (still pinned-first).
  unread,
}

/// Deterministic conversation-list ordering: pinned channels always float
/// first; within a group the requested [ConversationSort] applies.
abstract final class ConversationSorter {
  const ConversationSorter._();

  static List<ConversationSummary> sort(
    Iterable<ConversationSummary> summaries, {
    ConversationSort by = ConversationSort.lastActivity,
  }) {
    final list = summaries.toList()..sort((a, b) => _compare(a, b, by));
    return list;
  }

  static int _compare(
    ConversationSummary a,
    ConversationSummary b,
    ConversationSort by,
  ) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    switch (by) {
      case ConversationSort.title:
        final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        if (byTitle != 0) return byTitle;
      case ConversationSort.unread:
        final byUnread = b.unreadCount.compareTo(a.unreadCount);
        if (byUnread != 0) return byUnread;
      case ConversationSort.lastActivity:
        final aAt = a.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bAt = b.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final byActivity = bAt.compareTo(aAt);
        if (byActivity != 0) return byActivity;
    }
    return a.channelId.compareTo(b.channelId);
  }
}
