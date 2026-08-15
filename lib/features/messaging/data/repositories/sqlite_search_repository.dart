import 'package:drift/drift.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/database/tables/enums.dart' as core;
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/domain/channels/conversation_summary.dart';
import 'package:onebit/features/messaging/domain/messages/message_search_result.dart';
import 'package:onebit/features/messaging/domain/search/search_repository.dart';

import '../mappers/channel_mapper.dart';
import '../mappers/message_mapper.dart';

/// Drift FTS5-backed [SearchRepository].
///
/// The `message_search` FTS5 virtual table is created by the schema layer
/// (`messaging_schema.dart`); this repository only upserts/removes rows and
/// runs MATCH queries against it, never touching the wire. When FTS5 is
/// unavailable the schema layer installs a plain mirror table and search
/// degrades to a bounded LIKE scan.
final class SqliteSearchRepository implements SearchRepository {
  SqliteSearchRepository({
    required this._db,
    required this.logger,
    this.localNodeId,
  });

  final OneBitDatabase _db;
  final AppLogger logger;

  /// This node's id; enables private-channel lookup by peer display name.
  /// Null disables the node-name part of channel search.
  final String? localNodeId;

  static const _tag = LogTags.messaging;

  @override
  Future<Result<void>> indexMessage({
    required String messageId,
    required String channelId,
    required String body,
    required String sender,
    required String nodeName,
    required String type,
    required int timestampMs,
  }) => ResultGuards.guard(logger, '$_tag.indexMessage', () async {
    await _db.customStatement(
      'INSERT OR REPLACE INTO message_search '
      '(message_id, channel_id, body, sender, node_name, type, timestamp) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [messageId, channelId, body, sender, nodeName, type, timestampMs],
    );
  });

  @override
  Future<Result<void>> removeFromIndex(String messageId) =>
      ResultGuards.guard(logger, '$_tag.removeFromIndex', () async {
        await _db.customStatement(
          'DELETE FROM message_search WHERE message_id = ?',
          [messageId],
        );
      });

  @override
  Future<Result<int>> rebuildIndex() =>
      ResultGuards.guard(logger, '$_tag.rebuildIndex', () async {
        await _db.customStatement('DELETE FROM message_search');
        final rows = await _db.select(_db.messages).get();
        for (final row in rows) {
          await indexMessage(
            messageId: row.messageId,
            channelId: row.channelId,
            body: row.bodyText ?? '',
            sender: row.sender,
            nodeName: row.sender,
            type: row.messageType.name,
            timestampMs: row.timestamp.millisecondsSinceEpoch,
          );
        }
        return rows.length;
      });

  @override
  Future<Result<SearchPage<MessageSearchResult>>> searchMessages(
    MessageSearchQuery query, {
    int offset = 0,
    int limit = 50,
  }) => ResultGuards.guard(logger, '$_tag.searchMessages', () async {
    if (query.isEmpty) {
      return const SearchPage(items: [], offset: 0, limit: 50, hasMore: false);
    }

    final match = _ftsMatch(query.terms);
    try {
      final records = await _searchFts(
        query,
        match,
        offset: offset,
        limit: limit,
      );
      return await _hydrate(records, offset: offset, limit: limit);
    } on Object {
      // Degraded path: plain mirror table or exotic sqlite build without
      // FTS5. Scope expands to a LIKE scan so search never hard-fails.
      final records = await _searchLike(query, offset: offset, limit: limit);
      return _hydrate(records, offset: offset, limit: limit);
    }
  });

  /// FTS path: MATCH + post-filter + relevance ranking + snippet highlight.
  Future<List<_SearchRecord>> _searchFts(
    MessageSearchQuery query,
    String match, {
    required int offset,
    required int limit,
  }) async {
    // FTS5's MATCH requires the real table name (aliases break the query),
    // so column references stay fully qualified instead.
    final rows = await _db
        .customSelect(
          '''
SELECT message_search.message_id AS message_id,
       message_search.channel_id AS channel_id,
       message_search.body AS body, message_search.sender AS sender,
       message_search.type AS type,
       message_search.timestamp AS timestamp_ms, c.title AS channel_title,
       snippet(message_search, 2, '⋯', '⋯', '⋯', 12) AS snippet,
       bm25(message_search) AS rank
FROM message_search
JOIN messages m ON m.message_id = message_search.message_id
LEFT JOIN channels c ON c.channel_id = message_search.channel_id
WHERE message_search MATCH ?
  AND (? IS NULL OR message_search.channel_id = ?)
  AND (? IS NULL OR message_search.sender = ?)
  AND (? IS NULL OR message_search.type = ?)
  AND (? IS NULL OR message_search.timestamp >= ?)
  AND (? IS NULL OR message_search.timestamp < ?)
  AND (? = 0 OR m.read_at IS NULL)
  AND (? = 0 OR EXISTS (
        SELECT 1 FROM pinned_messages p
        WHERE p.channel_id = message_search.channel_id
          AND p.message_id = message_search.message_id))
  AND (? = 1 OR m.deleted = 0)
ORDER BY rank ASC
LIMIT ? OFFSET ?''',
          variables: [
            Variable(match),
            Variable(query.channelId),
            Variable(query.channelId),
            Variable(query.sender),
            Variable(query.sender),
            Variable(query.type?.name),
            Variable(query.type?.name),
            Variable(query.from?.millisecondsSinceEpoch),
            Variable(query.from?.millisecondsSinceEpoch),
            Variable(query.to?.millisecondsSinceEpoch),
            Variable(query.to?.millisecondsSinceEpoch),
            Variable(query.onlyUnread ? 1 : 0),
            Variable(query.onlyPinned ? 1 : 0),
            Variable(query.includeDeleted ? 1 : 0),
            Variable(limit),
            Variable(offset),
          ],
        )
        .get();
    return rows
        .map(
          (r) => _SearchRecord(
            messageId: r.read<String>('message_id'),
            channelId: r.read<String>('channel_id'),
            channelTitle: r.readNullable<String>('channel_title') ?? '',
            sender: r.read<String>('sender'),
            typeName: r.read<String>('type'),
            body: r.read<String>('body'),
            snippet: r.readNullable<String>('snippet') ?? '',
            timestampMs: r.read<int>('timestamp_ms'),
            rank: _readRank(r),
          ),
        )
        .toList();
  }

  /// Degraded path: LIKE scan over the mirror table with the same filters.
  Future<List<_SearchRecord>> _searchLike(
    MessageSearchQuery query, {
    required int offset,
    required int limit,
  }) async {
    final like = '%${query.terms.trim()}%';
    final rows = await _db
        .customSelect(
          '''
SELECT ms.message_id AS message_id, ms.channel_id AS channel_id,
       ms.body AS body, ms.sender AS sender, ms.type AS type,
       ms.timestamp AS timestamp_ms, c.title AS channel_title
FROM message_search ms
JOIN messages m ON m.message_id = ms.message_id
LEFT JOIN channels c ON c.channel_id = ms.channel_id
WHERE (ms.body LIKE ? OR ms.sender LIKE ? OR ms.node_name LIKE ?)
  AND (? IS NULL OR ms.channel_id = ?)
  AND (? IS NULL OR ms.sender = ?)
  AND (? IS NULL OR ms.type = ?)
  AND (? IS NULL OR ms.timestamp >= ?)
  AND (? IS NULL OR ms.timestamp < ?)
  AND (? = 0 OR m.read_at IS NULL)
  AND (? = 0 OR EXISTS (
        SELECT 1 FROM pinned_messages p
        WHERE p.channel_id = ms.channel_id AND p.message_id = ms.message_id))
  AND (? = 1 OR m.deleted = 0)
ORDER BY ms.timestamp DESC
LIMIT ? OFFSET ?''',
          variables: [
            Variable(like),
            Variable(like),
            Variable(like),
            Variable(query.channelId),
            Variable(query.channelId),
            Variable(query.sender),
            Variable(query.sender),
            Variable(query.type?.name),
            Variable(query.type?.name),
            Variable(query.from?.millisecondsSinceEpoch),
            Variable(query.from?.millisecondsSinceEpoch),
            Variable(query.to?.millisecondsSinceEpoch),
            Variable(query.to?.millisecondsSinceEpoch),
            Variable(query.onlyUnread ? 1 : 0),
            Variable(query.onlyPinned ? 1 : 0),
            Variable(query.includeDeleted ? 1 : 0),
            Variable(limit),
            Variable(offset),
          ],
        )
        .get();
    return rows
        .map(
          (r) => _SearchRecord(
            messageId: r.read<String>('message_id'),
            channelId: r.read<String>('channel_id'),
            channelTitle: r.readNullable<String>('channel_title') ?? '',
            sender: r.read<String>('sender'),
            typeName: r.read<String>('type'),
            body: r.read<String>('body'),
            snippet: _manualSnippet(r.read<String>('body'), query.terms),
            timestampMs: r.read<int>('timestamp_ms'),
            rank: 0,
          ),
        )
        .toList();
  }

  /// Hydrates search records with the live message rows (status, star,
  /// deleted, read state, sequence).
  Future<SearchPage<MessageSearchResult>> _hydrate(
    List<_SearchRecord> records, {
    required int offset,
    required int limit,
  }) async {
    if (records.isEmpty) {
      return SearchPage(
        items: const [],
        offset: offset,
        limit: limit,
        hasMore: false,
      );
    }

    final messageIds = records.map((r) => r.messageId).toSet();
    final stored = await (_db.select(
      _db.messages,
    )..where((t) => t.messageId.isIn(messageIds))).get();
    final byId = {for (final m in stored) m.messageId: m};
    final byPinned = await _pinnedIds(records: records);

    final items = records.map((r) {
      final row = byId[r.messageId];
      return MessageSearchResult(
        messageId: r.messageId,
        channelId: r.channelId,
        channelTitle: r.channelTitle,
        sender: r.sender,
        receiver: row?.receiver,
        type: MessageMapper.typeFromPersisted(
          core.MessageType.values
                  .where((t) => t.name == r.typeName)
                  .firstOrNull ??
              core.MessageType.text,
        ),
        status: MessageMapper.statusFromPersisted(
          row?.status ?? core.MessageStatus.pending,
        ),
        priority: MessageMapper.priorityFromPersisted(
          row?.priority ?? core.PriorityLevel.normal,
        ),
        body: r.body,
        snippet: r.snippet.isEmpty ? _manualSnippet(r.body, '') : r.snippet,
        timestamp: DateTime.fromMillisecondsSinceEpoch(r.timestampMs),
        sequence: row?.sequence ?? 0,
        deleted: row?.deleted ?? false,
        starred: row?.starred ?? false,
        readAt: row?.readAt,
        pinned: byPinned.contains(r.messageId),
        rank: r.rank,
      );
    }).toList();

    return SearchPage(
      items: items,
      offset: offset,
      limit: limit,
      hasMore: records.length == limit,
    );
  }

  /// The set of pinned message ids among [records] (one EXISTS query).
  Future<Set<String>> _pinnedIds({required List<_SearchRecord> records}) async {
    final ids = records.map((r) => r.messageId).toList();
    final rows = await (_db.select(
      _db.pinnedMessages,
    )..where((t) => t.messageId.isIn(ids))).get();
    return rows.map((r) => r.messageId).toSet();
  }

  @override
  Future<Result<List<ConversationSummary>>> searchChannels(
    String terms, {
    int limit = 25,
  }) => ResultGuards.guard(logger, '$_tag.searchChannels', () async {
    final like = '%$terms%';
    final rows =
        await (_db.select(_db.channels)
              ..where(
                (c) =>
                    c.title.like(like) |
                    c.channelId.like(like) |
                    c.lastMessageId.like(like),
              )
              ..limit(limit))
            .get();
    var summaries = rows.map(ChannelMapper.toSummary).toList();
    if (localNodeId != null) {
      final byName =
          (await searchChannelsByNodeName(terms, limit: limit)).value ?? [];
      summaries = _mergeUnique(summaries, byName);
    }
    return summaries;
  });

  /// Searches channels by peer *display name* (node profiles). Kept separate
  /// from the SQL LIKE path so profile joins stay a small, indexed query.
  @override
  Future<Result<List<ConversationSummary>>> searchChannelsByNodeName(
    String terms, {
    int limit = 25,
  }) => ResultGuards.guard(logger, '$_tag.searchChannelsByNodeName', () async {
    final myself = localNodeId;
    if (myself == null || terms.trim().isEmpty) {
      return const [];
    }
    final like = '%${terms.trim()}%';
    final profiles = await (_db.select(
      _db.nodeProfiles,
    )..where((p) => p.displayName.like(like) | p.nodeId.like(like))).get();
    if (profiles.isEmpty) return const [];

    final derived = profiles
        .map((p) => ChannelMapper.privateChannelId(myself, p.nodeId))
        .toSet();
    final rows =
        await (_db.select(_db.channels)
              ..where((c) => c.channelId.isIn(derived))
              ..limit(limit))
            .get();
    return rows.map(ChannelMapper.toSummary).map((s) {
      var title = s.title;
      for (final p in profiles) {
        if (p.displayName == null || p.displayName!.isEmpty) continue;
        if (ChannelMapper.privateChannelId(myself, p.nodeId) == s.channelId) {
          title = p.displayName!;
          break;
        }
      }
      return s.copyWith(title: title);
    }).toList();
  });

  static List<ConversationSummary> _mergeUnique(
    List<ConversationSummary> first,
    List<ConversationSummary> second,
  ) {
    final byId = {for (final s in first) s.channelId: s};
    for (final s in second) {
      byId.putIfAbsent(s.channelId, () => s);
    }
    return byId.values.toList();
  }

  /// Builds a safe FTS5 MATCH expression from user terms: every token is
  /// quoted and prefix-expanded so incremental typing-ahead keeps matching.
  static String _ftsMatch(String terms) {
    final tokens = terms
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '')}"*')
        .join(' ');
    return tokens.isEmpty ? '*' : tokens;
  }

  static String _manualSnippet(String body, String terms) {
    if (body.length <= 96) return body;
    final flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.length <= 120) return flat;
    return '…${flat.substring(0, 118)}…';
  }

  static double _readRank(QueryRow row) {
    final raw = row.read<double>('rank');
    return raw.isNaN ? 0 : raw;
  }
}

/// One FTS/LIKE record before hydration with live message rows.
final class _SearchRecord {
  const _SearchRecord({
    required this.messageId,
    required this.channelId,
    required this.channelTitle,
    required this.sender,
    required this.typeName,
    required this.body,
    required this.snippet,
    required this.timestampMs,
    required this.rank,
  });

  final String messageId;
  final String channelId;
  final String channelTitle;
  final String sender;
  final String typeName;
  final String body;
  final String snippet;
  final int timestampMs;
  final double rank;
}
