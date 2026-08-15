import 'package:onebit/core/logger/log_filter.dart';
import 'package:onebit/core/logger/log_level.dart';
import 'package:onebit/core/logger/log_output.dart';
import 'package:onebit/core/logger/log_record.dart';

/// Application-wide logging facade.
///
/// Every subsystem obtains a [AppLogger] through dependency injection
/// (usually the Riverpod `appLoggerProvider`); subsystems never print on
/// their own. The facade is a thin, type-safe wrapper around an output
/// pipeline: filter → output.
///
/// Usage:
/// ```dart
/// logger.info(tags.mesh, 'Central connected');
/// logger.error(tags.storage, 'Write failed', error: failure);
/// ```
class AppLogger {
  AppLogger({required this.filter, required this.output});

  /// Applied before the record is handed to the output.
  final LogFilter filter;

  /// Final destination of accepted records.
  final LogOutput output;

  /// Emits a record without severity checks (fast path for hot loops).
  void log(LogRecord record) {
    if (filter.accepts(record)) {
      output.write(record);
    }
  }

  /// Records a message at [level].
  void write(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      LogRecord(
        level: level,
        message: message,
        time: DateTime.now(),
        tag: tag,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  /// Deep diagnostics, rarely enabled.
  void trace(String message, {String? tag}) =>
      write(LogLevel.trace, message, tag: tag);

  /// Flow detail for debugging a feature.
  void debug(String message, {String? tag}) =>
      write(LogLevel.debug, message, tag: tag);

  /// Normal operational events.
  void info(String message, {String? tag}) =>
      write(LogLevel.info, message, tag: tag);

  /// Notable, non-fatal conditions.
  void warning(String message, {String? tag, Object? error}) =>
      write(LogLevel.warning, message, tag: tag, error: error);

  /// A failure was handled by the failure framework.
  void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) => write(
    LogLevel.error,
    message,
    tag: tag,
    error: error,
    stackTrace: stackTrace,
  );

  /// A failure that ended a workflow.
  void fatal(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) => write(
    LogLevel.fatal,
    message,
    tag: tag,
    error: error,
    stackTrace: stackTrace,
  );
}

/// A logger whose [tag] is fixed, reducing call-site noise.
final class TaggedLogger {
  TaggedLogger(this.logger, this.tag);

  final AppLogger logger;
  final String tag;

  void info(String message) => logger.info(message, tag: tag);

  void debug(String message) => logger.debug(message, tag: tag);

  void warning(String message, {Object? error}) =>
      logger.warning(message, tag: tag, error: error);

  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      logger.error(message, tag: tag, error: error, stackTrace: stackTrace);
}
