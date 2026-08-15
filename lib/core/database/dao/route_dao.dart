import 'package:drift/drift.dart';

import '../database.dart';
import '../models/page.dart';
import '../query/page_request.dart';
import '../tables/network_tables.dart';

part 'route_dao.g.dart';

/// Typed persistence for mesh routes.
@DriftAccessor(tables: [Routes])
final class RouteDao extends DatabaseAccessor<OneBitDatabase>
    with _$RouteDaoMixin {
  RouteDao(super.db);

  Future<RouteRow?> getRoute(String destination) => (select(
    routes,
  )..where((t) => t.destination.equals(destination))).getSingleOrNull();

  /// All routes that hand off via [nextHop].
  Future<List<RouteRow>> routesViaNextHop(String nextHop) =>
      (select(routes)..where((t) => t.nextHop.equals(nextHop))).get();

  /// Best route to [destination]: highest quality, fewest hops.
  Future<RouteRow?> bestRouteTo(String destination) =>
      (select(routes)
            ..where((t) => t.destination.equals(destination))
            ..orderBy([
              (t) => OrderingTerm.desc(t.quality),
              (t) => OrderingTerm.asc(t.hopCount),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<Page<RouteRow>> pageRoutes({
    PageRequest request = const PageRequest(),
    bool includeExpired = false,
  }) async {
    final query = select(routes);
    if (!includeExpired) {
      query.where(
        (t) =>
            t.expiration.isNull() |
            t.expiration.isBiggerThanValue(
              DateTime.now().millisecondsSinceEpoch,
            ),
      );
    }
    query
      ..orderBy([
        (t) => OrderingTerm.desc(t.quality),
        (t) => OrderingTerm.asc(t.hopCount),
      ])
      ..limit(request.limit, offset: request.offset);
    final rows = await query.get();
    return Page(
      items: rows,
      offset: request.offset,
      limit: request.limit,
      hasMore: rows.length == request.limit,
    );
  }

  Stream<List<RouteRow>> watchRoutes() => select(routes).watch();

  Future<int> upsertRoute(RouteRow row) =>
      into(routes).insertOnConflictUpdate(row);

  Future<int> deleteRoute(String destination) =>
      (delete(routes)..where((t) => t.destination.equals(destination))).go();

  /// Routes whose expiration passed [now]; returns them and deletes them.
  Future<List<RouteRow>> pruneExpired({DateTime? now, int limit = 500}) async {
    final timestamp = now ?? DateTime.now();
    final found =
        await (select(routes)
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
      await (delete(routes)
            ..where((t) => t.destination.isIn(found.map((r) => r.destination))))
          .go();
    }
    return found;
  }
}
