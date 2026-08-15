import 'package:meta/meta.dart';
import 'package:onebit/core/logger/log_level.dart';

/// A single immutable log entry produced by [AppLogger].
@immutable
final class LogRecord {
  const LogRecord({
    required this.level,
    required this.message,
    required this.time,
    this.tag,
    this.error,
    this.stackTrace,
  });

  /// Severity of this entry.
  final LogLevel level;

  /// Human-readable message (already interpolated by the caller).
  final String message;

  /// Microsecond timestamp captured when the record was created.
  final DateTime time;

  /// Logical component that produced the record (e.g. `ble.central`).
  final String? tag;

  /// Optional thrown error attached to the record.
  final Object? error;

  /// Optional stack trace when [error] is set.
  final StackTrace? stackTrace;

  /// Formats the record into a single-line, terminal-safe string.
  ///
  /// Example: `INFO 12:01:02.345 [mesh.central] connection opened`.
  String toLine() {
    final timestamp = time.toIso8601String();
    final tagPart = tag == null ? '' : ' [$tag]';
    final errorPart = error == null
        ? ''
        : ' — ${_describeError(error!)}'
              '${stackTrace == null ? '' : '\n${stackTrace!}'}';
    return '${level.label} $timestamp$tagPart $message$errorPart';
  }

  static String _describeError(Object error) {
    if (error is Error) return error.toString();
    final message = error.toString();
    return message.isEmpty ? '${error.runtimeType}' : message;
  }
}
