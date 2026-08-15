import 'package:drift/drift.dart';

import '../database.dart';
import '../models/page.dart';
import '../query/page_request.dart';
import '../tables/enums.dart';
import '../tables/network_tables.dart';

part 'neighbor_dao.g.dart';

/// Typed persistence for directly-observed neighbors.
@DriftAccessor(tables: [Neighbors])
final class NeighborDao extends DatabaseAccessor<OneBitDatabase>
    with _$NeighborDaoMixin {
  NeighborDao(super.db);

  Future<NeighborRow?> getNeighbor(String node) =>
      (select(neighbors)..where((t) => t.node.equals(node))).getSingleOrNull();

  /// Neighbors ordered by recency (most recently seen first).
  Future<List<NeighborRow>> listNeighbors({
    NeighborStatus? status,
    int limit = 100,
  }) {
    final query = select(neighbors)
      ..orderBy([(t) => OrderingTerm.desc(t.lastSeen)])
      ..limit(limit);
    if (status != null) {
      query.where((t) => t.status.equalsValue(status));
    }
    return query.get();
  }

  Future<Page<NeighborRow>> pageNeighbors({
    PageRequest request = const PageRequest(),
  }) async {
    final query = select(neighbors)
      ..orderBy([(t) => OrderingTerm.desc(t.lastSeen)])
      ..limit(request.limit, offset: request.offset);
    final rows = await query.get();
    return Page(
      items: rows,
      offset: request.offset,
      limit: request.limit,
      hasMore: rows.length == request.limit,
    );
  }

  Stream<List<NeighborRow>> watchNeighbors() => (select(
    neighbors,
  )..orderBy([(t) => OrderingTerm.desc(t.lastSeen)])).watch();

  /// Idempotent presence update.
  Future<int> upsertNeighbor(NeighborRow row) =>
      into(neighbors).insertOnConflictUpdate(row);

  Future<int> updateNeighborStatus(String node, NeighborStatus status) =>
      (update(neighbors)..where((t) => t.node.equals(node))).write(
        NeighborsCompanion(status: Value(status)),
      );

  /// Neighbors not seen since [olderThan] (returns them, then deletes them).
  Future<List<NeighborRow>> pruneStale(
    DateTime olderThan, {
    int limit = 500,
  }) async {
    final found =
        await (select(neighbors)
              ..where(
                (t) => t.lastSeen.isSmallerThanValue(
                  olderThan.millisecondsSinceEpoch,
                ),
              )
              ..limit(limit))
            .get();
    if (found.isNotEmpty) {
      await (delete(
        neighbors,
      )..where((t) => t.node.isIn(found.map((n) => n.node)))).go();
    }
    return found;
  }

  Future<int> countNeighbors() async {
    final row = await (selectOnly(
      neighbors,
    )..addColumns([countAll()])).getSingle();
    return row.read(countAll()) ?? 0;
  }
}
