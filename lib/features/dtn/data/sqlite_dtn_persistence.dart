import '../../../core/database/dao/dtn_dao.dart';
import '../delivery/store_forward_engine.dart' show DtnPersistence;
import '../domain/dtn_envelope.dart';
import '../domain/dtn_failure.dart';
import 'dtn_row_mapper.dart';

/// The concrete [DtnPersistence] over `DtnDao`.
///
/// Each transition lands as a single-row upsert (atomic at the sqlite
/// level), which is exactly the durability contract the engine needs: no
/// envelope is ever *only* in memory, and restore is a full `selectAll()`.
final class SqliteDtnPersistence implements DtnPersistence {
  const SqliteDtnPersistence(this._dao);

  final DtnDao _dao;

  @override
  Future<void> upsert(DtnPacket packet) async {
    try {
      await _dao.upsert(DtnRowMapper.toRow(packet));
    } catch (e) {
      throw DtnFailure.persistenceError(e, 'upsert ${packet.packetId}');
    }
  }

  @override
  Future<void> deletePacket(String packetId) async {
    try {
      await _dao.deletePacket(packetId);
    } catch (e) {
      throw DtnFailure.persistenceError(e, 'delete $packetId');
    }
  }

  @override
  Future<List<DtnPacket>> loadAll() async {
    try {
      final rows = await _dao.selectAll();
      return rows.map(DtnRowMapper.toPacket).toList();
    } catch (e) {
      throw DtnFailure.persistenceError(e, 'loadAll');
    }
  }
}
