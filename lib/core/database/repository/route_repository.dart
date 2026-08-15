import 'package:onebit/core/database/cache/route_cache.dart';
import 'package:onebit/core/database/dao/route_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/models/page.dart';
import 'package:onebit/core/database/query/page_request.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/result/result.dart';

/// Repository for mesh routes.
///
/// Best-route reads are cached for 30 s; every write invalidates the touched
/// destination.
final class RouteRepository {
  RouteRepository({
    required this._dao,
    required this._cache,
    required this._logger,
  });

  final RouteDao _dao;
  final RouteCache _cache;
  final AppLogger _logger;

  static const _tag = 'route.dao';

  Future<Result<RouteRow?>> getRoute(String destination) => ResultGuards.guard(
    _logger,
    '$_tag.getRoute',
    () => _cache.getOrLoad(destination, () => _dao.getRoute(destination)),
  );

  Future<Result<List<RouteRow>>> routesViaNextHop(String nextHop) =>
      ResultGuards.guard(
        _logger,
        '$_tag.routesViaNextHop',
        () => _dao.routesViaNextHop(nextHop),
      );

  /// Best route to [destination] (highest quality, fewest hops), cached.
  Future<Result<RouteRow?>> bestRouteTo(String destination) =>
      ResultGuards.guard(
        _logger,
        '$_tag.bestRouteTo',
        () =>
            _cache.getOrLoad(destination, () => _dao.bestRouteTo(destination)),
      );

  Future<Result<Page<RouteRow>>> pageRoutes({
    PageRequest request = const PageRequest(),
    bool includeExpired = false,
  }) => ResultGuards.guard(
    _logger,
    '$_tag.pageRoutes',
    () => _dao.pageRoutes(request: request, includeExpired: includeExpired),
  );

  Stream<Result<List<RouteRow>>> watchRoutes() =>
      ResultGuards.guardWatch(_logger, '$_tag.watchRoutes', _dao.watchRoutes());

  Future<Result<int>> upsertRoute(RouteRow row) =>
      ResultGuards.guard(_logger, '$_tag.upsertRoute', () async {
        final written = await _dao.upsertRoute(row);
        _cache.put(row);
        return written;
      });

  Future<Result<int>> deleteRoute(String destination) =>
      ResultGuards.guard(_logger, '$_tag.deleteRoute', () async {
        final written = await _dao.deleteRoute(destination);
        _cache.invalidate(destination);
        return written;
      });

  /// Routes whose expiration passed; returns them and deletes them.
  Future<Result<List<RouteRow>>> pruneExpired({
    DateTime? now,
    int limit = 500,
  }) => ResultGuards.guard(
    _logger,
    '$_tag.pruneExpired',
    () => _dao.pruneExpired(now: now, limit: limit),
  );
}
