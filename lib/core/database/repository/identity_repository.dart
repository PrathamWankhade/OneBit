import 'package:onebit/core/database/cache/identity_cache.dart';
import 'package:onebit/core/database/cache/trust_cache.dart';
import 'package:onebit/core/database/dao/identity_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/database/tables/enums.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/result/result.dart';

/// Repository for the local identity, trusted nodes and node profiles.
///
/// Wraps [IdentityDao] with the `Result<T>` boundary and read-through caches
/// (identity cached until invalidated, trust rows for 30 s).
final class IdentityRepository {
  IdentityRepository({
    required this._dao,
    required this._identityCache,
    required this._trustCache,
    required this._logger,
  });

  final IdentityDao _dao;
  final IdentityCache _identityCache;
  final TrustCache _trustCache;
  final AppLogger _logger;

  static const _tag = 'identity.dao';

  // ---- Identity (single row) --------------------------------------------------

  /// The local identity row, cached until invalidated.
  Future<Result<IdentityRow?>> getIdentity() => ResultGuards.guard(
    _logger,
    '$_tag.getIdentity',
    () async => _identityCache.getOrLoadIdentity(_dao.getIdentity),
  );

  Future<Result<IdentityRow?>> getIdentityRow(String nodeId) =>
      ResultGuards.guard(
        _logger,
        '$_tag.getIdentityRow',
        () => _dao.getIdentityRow(nodeId),
      );

  Future<Result<int>> upsertIdentity(IdentityRow row) =>
      ResultGuards.guard(_logger, '$_tag.upsertIdentity', () async {
        final written = await _dao.upsertIdentity(row);
        _identityCache.putIdentity(row);
        return written;
      });

  Future<Result<int>> deleteIdentity(String nodeId) =>
      ResultGuards.guard(_logger, '$_tag.deleteIdentity', () async {
        final written = await _dao.deleteIdentity(nodeId);
        _identityCache.invalidate();
        return written;
      });

  // ---- Trusted nodes -----------------------------------------------------------

  /// Trust row for [nodeId], cached for 30 s.
  Future<Result<TrustedNodeRow?>> getTrustedNode(String nodeId) =>
      ResultGuards.guard(
        _logger,
        '$_tag.getTrustedNode',
        () => _trustCache.getOrLoad(nodeId, () => _dao.getTrustedNode(nodeId)),
      );

  Future<Result<List<TrustedNodeRow>>> listTrustedNodes({
    TrustStatus? status,
    int limit = 100,
  }) => ResultGuards.guard(
    _logger,
    '$_tag.listTrustedNodes',
    () => _dao.listTrustedNodes(status: status, limit: limit),
  );

  Future<Result<int>> upsertTrustedNode(TrustedNodeRow row) =>
      ResultGuards.guard(_logger, '$_tag.upsertTrustedNode', () async {
        final written = await _dao.upsertTrustedNode(row);
        _trustCache.put(row);
        return written;
      });

  Future<Result<int>> deleteTrustedNode(String nodeId) =>
      ResultGuards.guard(_logger, '$_tag.deleteTrustedNode', () async {
        final written = await _dao.deleteTrustedNode(nodeId);
        _trustCache.invalidate(nodeId);
        return written;
      });

  Future<Result<int>> setTrustStatus(String nodeId, TrustStatus status) =>
      ResultGuards.guard(_logger, '$_tag.setTrustStatus', () async {
        final written = await _dao.setTrustStatus(nodeId, status);
        _trustCache.invalidate(nodeId);
        return written;
      });

  Future<Result<int>> setTrustedNickname(String nodeId, String nickname) =>
      ResultGuards.guard(_logger, '$_tag.setTrustedNickname', () async {
        final written = await _dao.setTrustedNickname(nodeId, nickname);
        _trustCache.invalidate(nodeId);
        return written;
      });

  // ---- Node profiles ------------------------------------------------------------

  Future<Result<NodeProfileRow?>> getNodeProfile(String nodeId) =>
      ResultGuards.guard(
        _logger,
        '$_tag.getNodeProfile',
        () => _dao.getNodeProfile(nodeId),
      );

  Future<Result<List<NodeProfileRow>>> listNodeProfiles({int limit = 200}) =>
      ResultGuards.guard(
        _logger,
        '$_tag.listNodeProfiles',
        () => _dao.listNodeProfiles(limit: limit),
      );

  Future<Result<int>> upsertNodeProfile(NodeProfileRow row) =>
      ResultGuards.guard(
        _logger,
        '$_tag.upsertNodeProfile',
        () => _dao.upsertNodeProfile(row),
      );
}
