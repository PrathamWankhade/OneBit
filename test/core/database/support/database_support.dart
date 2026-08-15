import 'package:drift/native.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_filter.dart';
import 'package:onebit/core/logger/log_output.dart';
import 'package:onebit/core/logger/log_record.dart';

/// A logger that swallows everything — tests only assert on results, not logs.
final AppLogger silentLogger = AppLogger(
  filter: const AllowAllLogFilter(),
  output: _SilentLogOutput(),
);

final class _SilentLogOutput implements LogOutput {
  @override
  void write(LogRecord record) {}

  @override
  void dispose() {}
}

/// Opens a fresh in-memory database with the full 25-table schema.
Future<OneBitDatabase> openInMemoryDb() async =>
    OneBitDatabase(NativeDatabase.memory());
