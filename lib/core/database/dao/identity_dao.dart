import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/identity_tables.dart';

part 'identity_dao.g.dart';

/// Typed persistence for the local identity, trusted nodes and node profiles.
///
/// DAO layer only — exceptions bubble up and repositories map them to
/// `Result<T>` failures.
@DriftAccessor(tables: [Identity, TrustedNodes, NodeProfiles])
final class IdentityDao extends DatabaseAccessor<OneBitDatabase>
    with _$IdentityDaoMixin {
  IdentityDao(super.db);

  @override
  $IdentityTable get identity => db.identity;

  @override
  $TrustedNodesTable get trustedNodes => db.trustedNodes;

  @override
  $NodeProfilesTable get nodeProfiles => db.nodeProfiles;

  // ---- Identity (single row) ------------------------------------------------

  Future<IdentityRow?> getIdentity() => (select(
    identity,
  )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).getSingleOrNull();

  Future<IdentityRow?> getIdentityRow(String nodeId) => (select(
    identity,
  )..where((t) => t.nodeId.equals(nodeId))).getSingleOrNull();

  Future<int> upsertIdentity(IdentityRow row) =>
      into(identity).insertOnConflictUpdate(row);

  Future<int> deleteIdentity(String nodeId) =>
      (delete(identity)..where((t) => t.nodeId.equals(nodeId))).go();

  // ---- Trusted nodes ---------------------------------------------------------

  Future<TrustedNodeRow?> getTrustedNode(String nodeId) => (select(
    trustedNodes,
  )..where((t) => t.nodeId.equals(nodeId))).getSingleOrNull();

  Future<List<TrustedNodeRow>> listTrustedNodes({
    TrustStatus? status,
    int limit = 100,
  }) {
    final query = select(trustedNodes)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
      ..limit(limit);
    if (status != null) {
      query.where((t) => t.trustStatus.equalsValue(status));
    }
    return query.get();
  }

  Future<int> upsertTrustedNode(TrustedNodeRow row) =>
      into(trustedNodes).insertOnConflictUpdate(row);

  Future<int> deleteTrustedNode(String nodeId) =>
      (delete(trustedNodes)..where((t) => t.nodeId.equals(nodeId))).go();

  Future<int> setTrustStatus(String nodeId, TrustStatus status) =>
      (update(trustedNodes)..where((t) => t.nodeId.equals(nodeId))).write(
        TrustedNodesCompanion(trustStatus: Value(status)),
      );

  Future<int> setTrustedNickname(String nodeId, String nickname) =>
      (update(trustedNodes)..where((t) => t.nodeId.equals(nodeId))).write(
        TrustedNodesCompanion(
          nickname: Value(nickname),
          updatedAt: Value(DateTime.now()),
        ),
      );

  // ---- Node profiles ----------------------------------------------------------

  Future<NodeProfileRow?> getNodeProfile(String nodeId) => (select(
    nodeProfiles,
  )..where((t) => t.nodeId.equals(nodeId))).getSingleOrNull();

  Future<List<NodeProfileRow>> listNodeProfiles({int limit = 200}) =>
      (select(nodeProfiles)
            ..orderBy([(t) => OrderingTerm.desc(t.lastSeen)])
            ..limit(limit))
          .get();

  Future<int> upsertNodeProfile(NodeProfileRow row) =>
      into(nodeProfiles).insertOnConflictUpdate(row);
}
