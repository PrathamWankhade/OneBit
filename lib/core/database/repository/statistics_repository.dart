import 'package:onebit/core/database/dao/statistics_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/models/statistics_snapshot.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/result/result.dart';

/// Repository for statistics and telemetry tables.
final class StatisticsRepository {
  StatisticsRepository({required this._dao, required this._logger});

  final StatisticsDao _dao;
  final AppLogger _logger;

  static const _tag = 'statistics.dao';

  Future<Result<StatisticRow?>> getStatistic(String name) => ResultGuards.guard(
    _logger,
    '$_tag.getStatistic',
    () => _dao.getStatistic(name),
  );

  /// Atomically increments a counter by [delta], creating it when missing.
  Future<Result<void>> increment(String name, {int delta = 1}) =>
      ResultGuards.guard(
        _logger,
        '$_tag.increment',
        () => _dao.increment(name, delta: delta),
      );

  Future<Result<int>> setGauge(String name, double value) => ResultGuards.guard(
    _logger,
    '$_tag.setGauge',
    () => _dao.setGauge(name, value),
  );

  Future<Result<int>> setStringStatistic(String name, String value) =>
      ResultGuards.guard(
        _logger,
        '$_tag.setStringStatistic',
        () => _dao.setStringStatistic(name, value),
      );

  Future<Result<List<StatisticRow>>> allStatistics() =>
      ResultGuards.guard(_logger, '$_tag.allStatistics', _dao.allStatistics);

  /// Counts/aggregates across tables for the dashboard snapshot.
  Future<Result<StatisticsSnapshot>> snapshot() =>
      ResultGuards.guard(_logger, '$_tag.snapshot', _dao.snapshot);

  // ---- Logs ---------------------------------------------------------------------

  Future<Result<int>> insertLog(LogsCompanion entry) => ResultGuards.guard(
    _logger,
    '$_tag.insertLog',
    () => _dao.insertLog(entry),
  );

  Future<Result<List<LogRow>>> recentLogs({int limit = 200, String? tag}) =>
      ResultGuards.guard(
        _logger,
        '$_tag.recentLogs',
        () => _dao.recentLogs(limit: limit, tag: tag),
      );

  Future<Result<int>> purgeLogs(DateTime olderThan, {int limit = 5000}) =>
      ResultGuards.guard(
        _logger,
        '$_tag.purgeLogs',
        () => _dao.purgeLogs(olderThan, limit: limit),
      );

  // ---- Diagnostics ------------------------------------------------------------------

  Future<Result<int>> insertDiagnostic(
    String category,
    String name,
    String? value,
  ) => ResultGuards.guard(
    _logger,
    '$_tag.insertDiagnostic',
    () => _dao.insertDiagnostic(category, name, value),
  );

  Future<Result<List<DiagnosticRow>>> diagnosticsFor(
    String category, {
    int limit = 100,
  }) => ResultGuards.guard(
    _logger,
    '$_tag.diagnosticsFor',
    () => _dao.diagnosticsFor(category, limit: limit),
  );

  // ---- Developer events ------------------------------------------------------------

  Future<Result<int>> insertDeveloperEvent(
    String name, {
    String? payload,
    int severity = 0,
  }) => ResultGuards.guard(
    _logger,
    '$_tag.insertDeveloperEvent',
    () => _dao.insertDeveloperEvent(name, payload: payload, severity: severity),
  );

  Future<Result<List<DeveloperEventRow>>> recentDeveloperEvents({
    int limit = 200,
  }) => ResultGuards.guard(
    _logger,
    '$_tag.recentDeveloperEvents',
    () => _dao.recentDeveloperEvents(limit: limit),
  );
}
