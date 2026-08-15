import 'package:drift/drift.dart';

import '../database.dart';
import '../models/statistics_snapshot.dart';
import '../tables/enums.dart';
import '../tables/telemetry_tables.dart';

part 'statistics_dao.g.dart';

/// Typed persistence for counters, gauges and the telemetry tables.
@DriftAccessor(tables: [Statistics, Logs, Diagnostics, DeveloperEvents])
final class StatisticsDao extends DatabaseAccessor<OneBitDatabase>
    with _$StatisticsDaoMixin {
  StatisticsDao(super.db);

  @override
  $StatisticsTable get statistics => db.statistics;

  @override
  $LogsTable get logs => db.logs;

  @override
  $DiagnosticsTable get diagnostics => db.diagnostics;

  @override
  $DeveloperEventsTable get developerEvents => db.developerEvents;

  // ---- Statistics --------------------------------------------------------------

  Future<StatisticRow?> getStatistic(String name) =>
      (select(statistics)..where((t) => t.name.equals(name))).getSingleOrNull();

  /// Atomically increments a counter by [delta], creating it when missing.
  Future<void> increment(String name, {int delta = 1}) => transaction(() async {
    final existing = await getStatistic(name);
    if (existing == null) {
      await into(statistics).insert(
        StatisticRow(
          name: name,
          kind: StatisticKind.counter,
          value: delta.toDouble(),
          stringValue: null,
          updatedAt: DateTime.now(),
        ),
      );
    } else {
      await (update(statistics)..where((t) => t.name.equals(name))).write(
        StatisticsCompanion(
          value: Value(existing.value + delta),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  });

  Future<int> setGauge(String name, double value) =>
      into(statistics).insertOnConflictUpdate(
        StatisticRow(
          name: name,
          kind: StatisticKind.gauge,
          value: value,
          stringValue: null,
          updatedAt: DateTime.now(),
        ),
      );

  Future<int> setStringStatistic(String name, String value) =>
      into(statistics).insertOnConflictUpdate(
        StatisticRow(
          name: name,
          kind: StatisticKind.gauge,
          value: 0,
          stringValue: value,
          updatedAt: DateTime.now(),
        ),
      );

  Future<List<StatisticRow>> allStatistics() => select(statistics).get();

  /// Counts/aggregates across tables for the dashboard snapshot.
  Future<StatisticsSnapshot> snapshot() async {
    Future<int> countOf(TableInfo<Table, Object?> table) async {
      final row = await (selectOnly(
        table,
      )..addColumns([countAll()])).getSingle();
      return row.read(countAll()) ?? 0;
    }

    return StatisticsSnapshot(
      messages: await countOf(db.messages),
      packets: await countOf(db.packets),
      routes: await countOf(db.routes),
      neighbors: await countOf(db.neighbors),
      trustedNodes: await countOf(db.trustedNodes),
      sessions: await countOf(db.sessions),
      logs: await countOf(logs),
      stats: await countOf(statistics),
    );
  }

  // ---- Logs ---------------------------------------------------------------------

  Future<int> insertLog(LogsCompanion entry) => into(logs).insert(entry);

  Future<List<LogRow>> recentLogs({int limit = 200, String? tag}) {
    final query = select(logs)
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
      ..limit(limit);
    if (tag != null) {
      query.where((t) => t.tag.equals(tag));
    }
    return query.get();
  }

  Future<int> purgeLogs(DateTime olderThan, {int limit = 5000}) async {
    final found =
        await (select(logs)
              ..where(
                (t) => t.timestamp.isSmallerThanValue(
                  olderThan.millisecondsSinceEpoch,
                ),
              )
              ..limit(limit))
            .get();
    if (found.isEmpty) {
      return 0;
    }
    return (delete(
      logs,
    )..where((t) => t.logId.isIn(found.map((r) => r.logId)))).go();
  }

  // ---- Diagnostics ------------------------------------------------------------------

  Future<int> insertDiagnostic(String category, String name, String? value) =>
      into(diagnostics).insert(
        DiagnosticsCompanion.insert(
          category: category,
          name: name,
          value: Value(value),
          recordedAt: DateTime.now(),
        ),
      );

  Future<List<DiagnosticRow>> diagnosticsFor(
    String category, {
    int limit = 100,
  }) =>
      (select(diagnostics)
            ..where((t) => t.category.equals(category))
            ..orderBy([(t) => OrderingTerm.desc(t.recordedAt)])
            ..limit(limit))
          .get();

  // ---- Developer events ------------------------------------------------------------

  Future<int> insertDeveloperEvent(
    String name, {
    String? payload,
    int severity = 0,
  }) => into(developerEvents).insert(
    DeveloperEventsCompanion.insert(
      name: name,
      payload: Value(payload),
      severity: Value(severity),
      occurredAt: DateTime.now(),
    ),
  );

  Future<List<DeveloperEventRow>> recentDeveloperEvents({int limit = 200}) =>
      (select(developerEvents)
            ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
            ..limit(limit))
          .get();
}
