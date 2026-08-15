import 'package:drift/drift.dart';

import 'converters.dart';
import 'enums.dart';

/// Structured application, bluetooth, routing and packet log events.
@DataClassName('LogRow')
@TableIndex(name: 'idx_logs_timestamp', columns: {#timestamp})
@TableIndex(name: 'idx_logs_tag_level', columns: {#tag, #level})
class Logs extends Table {
  IntColumn get logId => integer().autoIncrement()();

  IntColumn get timestamp => integer().map(dateTimeMsConverter)();

  /// Severity matching `LogLevel.severity` (0..5).
  IntColumn get level => integer()();

  TextColumn get tag => text()();

  TextColumn get category => text().nullable()();

  TextColumn get message => text()();

  TextColumn get stackTrace => text().nullable()();
}

/// Named diagnostic probes (storage health, connectivity, battery).
@DataClassName('DiagnosticRow')
class Diagnostics extends Table {
  IntColumn get diagnosticId => integer().autoIncrement()();

  TextColumn get category => text()();

  TextColumn get name => text()();

  TextColumn get value => text().nullable()();

  IntColumn get recordedAt => integer().map(dateTimeMsConverter)();
}

/// Developer-facing event trail (dev tools, debug builds).
@DataClassName('DeveloperEventRow')
class DeveloperEvents extends Table {
  IntColumn get eventId => integer().autoIncrement()();

  TextColumn get name => text()();

  /// JSON payload.
  TextColumn get payload => text().nullable()();

  IntColumn get severity => integer().withDefault(const Constant(0))();

  IntColumn get occurredAt => integer().map(dateTimeMsConverter)();
}

/// Named counters and gauges (messages sent, packets forwarded, ...).
@DataClassName('StatisticRow')
class Statistics extends Table {
  TextColumn get name => text()();

  TextColumn get kind =>
      textEnum<StatisticKind>().withDefault(const Constant('counter'))();

  RealColumn get value => real().withDefault(const Constant(0))();

  TextColumn get stringValue => text().nullable()();

  IntColumn get updatedAt => integer().map(dateTimeMsConverter)();

  @override
  Set<Column> get primaryKey => {name};
}
