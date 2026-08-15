import 'dart:io';

import 'package:onebit/core/logger/log_level.dart';
import 'package:onebit/core/logger/log_output.dart';
import 'package:onebit/core/logger/log_record.dart';

/// [LogOutput] that renders records to the process standard output.
///
/// Prefer this over `print` — it goes through `dart:io` directly and is
/// subject to the same `--enable-asserts`-independent behavior as the VM
/// console, while keeping the logger module free of Flutter imports.
final class ConsoleLogOutput implements LogOutput {
  ConsoleLogOutput({this.minimumLevel = LogLevel.debug, this.useColor = true});

  /// Records below this level are dropped by this sink.
  final LogLevel minimumLevel;

  /// Whether to emit ANSI color codes (disable on non-TTY environments).
  final bool useColor;

  @override
  void write(LogRecord record) {
    if (!record.level.atLeast(minimumLevel)) return;
    final line = record.toLine();
    stdout.writeln(useColor ? _withColor(record.level, line) : line);
  }

  @override
  void dispose() {}

  String _withColor(LogLevel level, String line) {
    const ansi = {
      LogLevel.trace: '\u001B[90m', // gray
      LogLevel.debug: '\u001B[36m', // cyan
      LogLevel.info: '\u001B[32m', // green
      LogLevel.warning: '\u001B[33m', // yellow
      LogLevel.error: '\u001B[31m', // red
      LogLevel.fatal: '\u001B[35m', // magenta
    };
    return '${ansi[level] ?? ''}$line\u001B[0m';
  }
}
