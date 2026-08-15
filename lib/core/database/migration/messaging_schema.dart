import '../database.dart';

/// Raw-schema extension the messaging domain needs but that drift does not
/// model: the FTS5 search index.
///
/// The `message_search` virtual table stays out of `@DriftDatabase` (drift
/// codegen would otherwise fight it), so this helper owns its DDL. It is
/// applied on fresh installs (via `onCreate`) and from the v3 migration
/// step; both paths are idempotent.
abstract final class MessagingSchema {
  const MessagingSchema._();

  /// The FTS5 index over local message content.
  ///
  /// Columns: message_id/channel_id/type/timestamp are `UNINDEXED` (never
  /// matched — they are filter-only), body/sender/node_name are full-text.
  static const String messageSearchDdl = '''
CREATE VIRTUAL TABLE IF NOT EXISTS message_search USING fts5(
  message_id UNINDEXED,
  channel_id UNINDEXED,
  body,
  sender,
  node_name,
  type UNINDEXED,
  timestamp UNINDEXED,
  tokenize = 'porter unicode61'
)''';

  /// Applies every raw schema object [OneBitDatabase] owns. Idempotent.
  static Future<void> install(OneBitDatabase db) async {
    try {
      await db.customStatement(messageSearchDdl);
    } on Object {
      // FTS5 may be unavailable on exotic sqlite builds; search degrades to
      // a LIKE scan rather than blocking the database from opening.
      await db.customStatement(
        'CREATE TABLE IF NOT EXISTS message_search '
        '(message_id TEXT, channel_id TEXT, body TEXT, sender TEXT, '
        'node_name TEXT, type TEXT, timestamp INTEGER)',
      );
    }
  }
}
