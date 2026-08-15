// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'statistics_dao.dart';

// ignore_for_file: type=lint
mixin _$StatisticsDaoMixin on DatabaseAccessor<OneBitDatabase> {
  $StatisticsTable get statistics => attachedDatabase.statistics;
  $LogsTable get logs => attachedDatabase.logs;
  $DiagnosticsTable get diagnostics => attachedDatabase.diagnostics;
  $DeveloperEventsTable get developerEvents => attachedDatabase.developerEvents;
  StatisticsDaoManager get managers => StatisticsDaoManager(this);
}

class StatisticsDaoManager {
  final _$StatisticsDaoMixin _db;
  StatisticsDaoManager(this._db);
  $$StatisticsTableTableManager get statistics =>
      $$StatisticsTableTableManager(_db.attachedDatabase, _db.statistics);
  $$LogsTableTableManager get logs =>
      $$LogsTableTableManager(_db.attachedDatabase, _db.logs);
  $$DiagnosticsTableTableManager get diagnostics =>
      $$DiagnosticsTableTableManager(_db.attachedDatabase, _db.diagnostics);
  $$DeveloperEventsTableTableManager get developerEvents =>
      $$DeveloperEventsTableTableManager(
        _db.attachedDatabase,
        _db.developerEvents,
      );
}
