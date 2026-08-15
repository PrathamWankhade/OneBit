import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/packet_tables.dart';

part 'packet_dao.g.dart';

/// Typed persistence for packets and their fragments.
@DriftAccessor(tables: [Packets, PacketFragments])
final class PacketDao extends DatabaseAccessor<OneBitDatabase>
    with _$PacketDaoMixin {
  PacketDao(super.db);

  @override
  $PacketsTable get packets => db.packets;

  @override
  $PacketFragmentsTable get packetFragments => db.packetFragments;

  /// Inserts a packet (idempotent) and its fragments atomically.
  Future<void> insertPacketWithFragments(
    PacketRow packet,
    List<PacketFragmentRow> fragments,
  ) => transaction(() async {
    await into(packets).insertOnConflictUpdate(packet);
    if (fragments.isNotEmpty) {
      await batch((batch) {
        batch.insertAll(packetFragments, fragments);
      });
    }
  });

  Future<PacketRow?> getPacket(String packetId) => (select(
    packets,
  )..where((t) => t.packetId.equals(packetId))).getSingleOrNull();

  Future<int> insertPacket(PacketRow row) =>
      into(packets).insert(row, mode: InsertMode.insertOrIgnore);

  Future<int> updatePacketStatus(String packetId, PacketStatus status) =>
      (update(packets)..where((t) => t.packetId.equals(packetId))).write(
        PacketsCompanion(status: Value(status)),
      );

  /// Packets that are pending and not yet expired, highest priority first.
  Future<List<PacketRow>> pendingPackets({int limit = 100, DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    const priorityOrder = CustomExpression<int>(
      "CASE priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 WHEN 'normal' THEN 2 ELSE 3 END",
    );
    return (select(packets)
          ..where(
            (t) =>
                t.status.equalsValue(PacketStatus.pending) &
                (t.expiresAt.isNull() |
                    t.expiresAt.isBiggerThanValue(
                      timestamp.millisecondsSinceEpoch,
                    )),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(priorityOrder),
            (t) => OrderingTerm.asc(t.createdAt),
          ])
          ..limit(limit))
        .get();
  }

  Future<List<PacketRow>> expirePackets({DateTime? now, int limit = 500}) {
    final timestamp = now ?? DateTime.now();
    return (select(packets)
          ..where(
            (t) =>
                t.expiresAt.isNotNull() &
                t.expiresAt.isSmallerThanValue(
                  timestamp.millisecondsSinceEpoch,
                ),
          )
          ..limit(limit))
        .get();
  }

  Future<int> deletePackets(List<String> packetIds) async {
    if (packetIds.isEmpty) {
      return 0;
    }
    return (delete(packets)..where((t) => t.packetId.isIn(packetIds))).go();
  }

  Future<int> countPackets({PacketStatus? status}) async {
    final query = selectOnly(packets)..addColumns([countAll()]);
    if (status != null) {
      query.where(packets.status.equalsValue(status));
    }
    final row = await query.getSingle();
    return row.read(countAll()) ?? 0;
  }

  // ---- Fragments -----------------------------------------------------------------

  Future<List<PacketFragmentRow>> fragmentsFor(String packetId) =>
      (select(packetFragments)
            ..where((t) => t.packetId.equals(packetId))
            ..orderBy([(t) => OrderingTerm.asc(t.sequence)]))
          .get();

  Future<int> markFragmentReceived(int fragmentId) =>
      (update(
        packetFragments,
      )..where((t) => t.fragmentId.equals(fragmentId))).write(
        PacketFragmentsCompanion(
          received: const Value(true),
          receivedAt: Value(DateTime.now()),
        ),
      );

  Future<int> countMissingFragments(String packetId) async {
    final query = selectOnly(packetFragments)
      ..addColumns([countAll()])
      ..where(
        packetFragments.packetId.equals(packetId) &
            packetFragments.received.equals(false),
      );
    final row = await query.getSingle();
    return row.read(countAll()) ?? 0;
  }
}
