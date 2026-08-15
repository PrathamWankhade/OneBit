import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_filter.dart';
import 'package:onebit/core/logger/log_level.dart';
import 'package:onebit/core/logger/log_output.dart';
import 'package:onebit/core/logger/log_record.dart';

void main() {
  group('BufferLogOutput', () {
    test('keeps records up to capacity, oldest first', () {
      final buffer = BufferLogOutput(capacity: 3);

      for (var i = 0; i < 5; i++) {
        buffer.write(
          LogRecord(level: LogLevel.info, message: 'm$i', time: DateTime(2026)),
        );
      }

      final snapshot = buffer.snapshot();
      expect(snapshot.length, 3);
      expect(snapshot.first.message, 'm2');
      expect(snapshot.last.message, 'm4');
    });

    test('snapshot is immutable', () {
      final buffer = BufferLogOutput();
      buffer.write(
        LogRecord(level: LogLevel.info, message: 'x', time: DateTime(2026)),
      );

      final before = buffer.snapshot();
      buffer.write(
        LogRecord(level: LogLevel.debug, message: 'y', time: DateTime(2026)),
      );

      expect(before.length, 1);
      expect(buffer.snapshot().length, 2);
    });
  });

  group('AppLogger', () {
    test('applies the log filter before writing', () {
      final sink = BufferLogOutput();
      final logger = AppLogger(
        filter: const LevelAndTagFilter(minimumLevel: LogLevel.error),
        output: sink,
      );

      logger.info('dropped');
      logger.error('kept');

      expect(sink.snapshot().length, 1);
      expect(sink.snapshot().first.message, 'kept');
    });

    test('output group tolerates a throwing sink', () {
      final buffer = BufferLogOutput();
      final broken = LogOutputGroup([_ThrowingLogOutput(), buffer]);
      final logger = AppLogger(
        filter: const AllowAllLogFilter(),
        output: broken,
      );

      logger.warning('hello', error: StateError('x'));

      expect(buffer.snapshot().length, 1);
    });
  });
}

final class _ThrowingLogOutput implements LogOutput {
  @override
  void write(LogRecord record) => throw StateError('broken sink');

  @override
  void dispose() {}
}
