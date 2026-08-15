import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/dtn_tables.dart';

part 'dtn_dao.g.dart';

/// Typed persistence for the DTN envelope store.
///
/// Rows are the *only* durable source of truth for the DTN layer; the engine
/// rehydrates its views from [all] after a restart ([NetworkRecoveryManager]).
@DriftAccessor(tables: [DtnPackets])
final class DtnDao extends DatabaseAccessor<OneBitDatabase> with _$DtnDaoMixin {
  DtnDao(super.db);

  @override
  $DtnPacketsTable get dtnPackets => db.dtnPackets;

  /// Everything the DTN layer knows, in one read (sanity-bounded by the
  /// caller; the envelope TTL keeps the table small).
  Future<List<DtnPacketRow>> selectAll() => select(dtnPackets).get();

  /// First live envelope of a state, ordered by enqueue time (oldest first).
  Future<DtnPacketRow?> peekState(DtnPacketState state) =>
      (select(dtnPackets)
            ..where((t) => t.state.equalsValue(state))
            ..orderBy([(t) => OrderingTerm.asc(t.enqueuedAt)])
            ..limit(1))
          .getSingleOrNull();

  /// How many live envelopes exist in [states].
  Future<int> countStates(List<DtnPacketState> states) async {
    final query = selectOnly(dtnPackets)..addColumns([countAll()]);
    query.where(dtnPackets.state.isIn(states.map((s) => s.name)));
    final row = await query.getSingle();
    return row.read(countAll()) ?? 0;
  }

  Future<void> upsert(DtnPacketRow row) =>
      into(dtnPackets).insertOnConflictUpdate(row);

  /// Insert with an `INSERT OR IGNORE` (used by flow control on the ack
  /// ledger when exact-once semantics are desired per packet id).
  Future<int> insertIgnoringConflicts(DtnPacketRow row) =>
      into(dtnPackets).insert(row, mode: InsertMode.insertOrIgnore);

  Future<DtnPacketRow?> selectPacket(String packetId) => (select(
    dtnPackets,
  )..where((t) => t.packetId.equals(packetId))).getSingleOrNull();

  Future<int> deletePacket(String packetId) =>
      (delete(dtnPackets)..where((t) => t.packetId.equals(packetId))).go();

  /// Expired envelopes in batches (the recovery sweep prunes TTL'd rows).
  Future<List<DtnPacketRow>> expiredRows({DateTime? now, int limit = 500}) {
    final timestamp = now ?? DateTime.now();
    return (select(dtnPackets)
          ..where(
            (t) => t.expiresAt.isSmallerThanValue(
              timestamp.millisecondsSinceEpoch,
            ),
          )
          ..limit(limit))
        .get();
  }
}
