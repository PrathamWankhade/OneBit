import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/session_tables.dart';

part 'session_dao.g.dart';

/// Typed persistence for ratchet sessions and their keys.
@DriftAccessor(tables: [Sessions, SessionKeys])
final class SessionDao extends DatabaseAccessor<OneBitDatabase>
    with _$SessionDaoMixin {
  SessionDao(super.db);

  @override
  $SessionsTable get sessions => db.sessions;

  @override
  $SessionKeysTable get sessionKeys => db.sessionKeys;

  Future<SessionRow?> getSession(String sessionId) => (select(
    sessions,
  )..where((t) => t.sessionId.equals(sessionId))).getSingleOrNull();

  /// The most recent session with [node] (null when none exists).
  Future<SessionRow?> latestSessionForNode(String node) =>
      (select(sessions)
            ..where((t) => t.node.equals(node))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<int> upsertSession(SessionRow row) =>
      into(sessions).insertOnConflictUpdate(row);

  Future<int> updateSessionState(String sessionId, SessionState state) =>
      (update(sessions)..where((t) => t.sessionId.equals(sessionId))).write(
        SessionsCompanion(
          state: Value(state),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Sessions whose expiration passed [now] are marked expired and returned.
  Future<List<SessionRow>> expireSessions({
    DateTime? now,
    int limit = 100,
  }) async {
    final timestamp = now ?? DateTime.now();
    final found =
        await (select(sessions)
              ..where(
                (t) =>
                    t.expiration.isNotNull() &
                    t.expiration.isSmallerThanValue(
                      timestamp.millisecondsSinceEpoch,
                    ),
              )
              ..limit(limit))
            .get();
    if (found.isNotEmpty) {
      await (update(sessions)
            ..where((t) => t.sessionId.isIn(found.map((s) => s.sessionId))))
          .write(const SessionsCompanion(state: Value(SessionState.expired)));
    }
    return found;
  }

  // ---- Session keys ---------------------------------------------------------

  Future<int> insertSessionKey(SessionKeyRow row) =>
      into(sessionKeys).insert(row, mode: InsertMode.insertOrIgnore);

  Future<List<SessionKeyRow>> keysForSession(String sessionId) =>
      (select(sessionKeys)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.ratchetStep)]))
          .get();

  Future<SessionKeyRow?> keyAtStep(String sessionId, int ratchetStep) =>
      (select(sessionKeys)..where(
            (t) =>
                t.sessionId.equals(sessionId) &
                t.ratchetStep.equals(ratchetStep),
          ))
          .getSingleOrNull();
}
