import 'package:onebit/core/database/dao/session_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/database/tables/enums.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/result/result.dart';

/// Repository for ratchet sessions and their keys.
final class SessionRepository {
  SessionRepository({required this._dao, required this._logger});

  final SessionDao _dao;
  final AppLogger _logger;

  static const _tag = 'session.dao';

  Future<Result<SessionRow?>> getSession(String sessionId) =>
      ResultGuards.guard(
        _logger,
        '$_tag.getSession',
        () => _dao.getSession(sessionId),
      );

  /// The most recent session with [node] (null when none exists).
  Future<Result<SessionRow?>> latestSessionForNode(String node) =>
      ResultGuards.guard(
        _logger,
        '$_tag.latestSessionForNode',
        () => _dao.latestSessionForNode(node),
      );

  Future<Result<int>> upsertSession(SessionRow row) => ResultGuards.guard(
    _logger,
    '$_tag.upsertSession',
    () => _dao.upsertSession(row),
  );

  Future<Result<int>> updateSessionState(
    String sessionId,
    SessionState state,
  ) => ResultGuards.guard(
    _logger,
    '$_tag.updateSessionState',
    () => _dao.updateSessionState(sessionId, state),
  );

  /// Sessions whose expiration passed [now]; returns them and marks expired.
  Future<Result<List<SessionRow>>> expireSessions({
    DateTime? now,
    int limit = 100,
  }) => ResultGuards.guard(
    _logger,
    '$_tag.expireSessions',
    () => _dao.expireSessions(now: now, limit: limit),
  );

  // ---- Session keys ---------------------------------------------------------

  Future<Result<int>> insertSessionKey(SessionKeyRow row) => ResultGuards.guard(
    _logger,
    '$_tag.insertSessionKey',
    () => _dao.insertSessionKey(row),
  );

  Future<Result<List<SessionKeyRow>>> keysForSession(String sessionId) =>
      ResultGuards.guard(
        _logger,
        '$_tag.keysForSession',
        () => _dao.keysForSession(sessionId),
      );

  Future<Result<SessionKeyRow?>> keyAtStep(String sessionId, int ratchetStep) =>
      ResultGuards.guard(
        _logger,
        '$_tag.keyAtStep',
        () => _dao.keyAtStep(sessionId, ratchetStep),
      );
}
