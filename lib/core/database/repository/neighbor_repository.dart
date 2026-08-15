import 'package:onebit/core/database/cache/neighbor_cache.dart';
import 'package:onebit/core/database/dao/neighbor_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/models/page.dart';
import 'package:onebit/core/database/query/page_request.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/database/tables/enums.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/result/result.dart';

/// Repository for directly-observed neighbors.
///
/// Presence rows are volatile (10 s TTL cache) and invalidated on writes.
final class NeighborRepository {
  NeighborRepository({
    required this._dao,
    required this._cache,
    required this._logger,
  });

  final NeighborDao _dao;
  final NeighborCache _cache;
  final AppLogger _logger;

  static const _tag = 'neighbor.dao';

  Future<Result<NeighborRow?>> getNeighbor(String node) => ResultGuards.guard(
    _logger,
    '$_tag.getNeighbor',
    () => _cache.getOrLoad(node, () => _dao.getNeighbor(node)),
  );

  Future<Result<List<NeighborRow>>> listNeighbors({
    NeighborStatus? status,
    int limit = 100,
  }) => ResultGuards.guard(
    _logger,
    '$_tag.listNeighbors',
    () => _dao.listNeighbors(status: status, limit: limit),
  );

  Future<Result<Page<NeighborRow>>> pageNeighbors({
    PageRequest request = const PageRequest(),
  }) => ResultGuards.guard(
    _logger,
    '$_tag.pageNeighbors',
    () => _dao.pageNeighbors(request: request),
  );

  Stream<Result<List<NeighborRow>>> watchNeighbors() => ResultGuards.guardWatch(
    _logger,
    '$_tag.watchNeighbors',
    _dao.watchNeighbors(),
  );

  /// Idempotent presence update; refreshes the cache row.
  Future<Result<int>> upsertNeighbor(NeighborRow row) =>
      ResultGuards.guard(_logger, '$_tag.upsertNeighbor', () async {
        final written = await _dao.upsertNeighbor(row);
        _cache.put(row);
        return written;
      });

  Future<Result<int>> updateNeighborStatus(
    String node,
    NeighborStatus status,
  ) => ResultGuards.guard(_logger, '$_tag.updateNeighborStatus', () async {
    final written = await _dao.updateNeighborStatus(node, status);
    _cache.invalidate(node);
    return written;
  });

  /// Neighbors not seen since [olderThan]; returns them and deletes them.
  Future<Result<List<NeighborRow>>> pruneStale(
    DateTime olderThan, {
    int limit = 500,
  }) => ResultGuards.guard(
    _logger,
    '$_tag.pruneStale',
    () => _dao.pruneStale(olderThan, limit: limit),
  );

  Future<Result<int>> countNeighbors() =>
      ResultGuards.guard(_logger, '$_tag.countNeighbors', _dao.countNeighbors);
}
