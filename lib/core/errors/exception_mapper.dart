import 'package:onebit/core/errors/failure.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

/// Converts platform/data-boundary exceptions into domain [Failure] values.
///
/// This is the single place where raw `Exception`/`Error` objects cross into
/// domain code. Use it inside bridge and repository implementations at the
/// exact point a native or IO call throws, then carry the resulting
/// [Failure] inside a `Result`.
abstract final class ExceptionMapper {
  const ExceptionMapper._();

  /// Maps [error] to a [Failure].
  ///
  /// Known SDK exception types are mapped to precise failure kinds; anything
  /// else degrades to [UnexpectedFailure] while preserving the cause and
  /// stack trace so nothing is lost.
  static Failure map(Object error, [StackTrace? stackTrace]) {
    final trace = stackTrace ?? _captureTrace();
    final message = _describe(error);
    return switch (error) {
      FormatException() => SerializationFailure(
        message: message,
        cause: error,
        stackTrace: trace,
        source: 'format',
      ),
      ArgumentError() => ConfigurationFailure(
        message: message,
        cause: error,
        stackTrace: trace,
      ),
      UnsupportedError() => UnsupportedOperationFailure(
        message: message,
        cause: error,
        stackTrace: trace,
      ),
      SqliteException() => StorageFailure(
        message: message,
        cause: error,
        stackTrace: trace,
        operation: 'sqlite',
      ),
      StateError() => UnexpectedFailure(
        message: message,
        cause: error,
        stackTrace: trace,
      ),
      _ => UnexpectedFailure(message: message, cause: error, stackTrace: trace),
    };
  }

  /// Produces a bounded diagnostic string for [error].
  static String _describe(Object error) {
    final text = error.toString();
    const maxLength = 160;
    return text.length > maxLength ? '${text.substring(0, maxLength)}…' : text;
  }

  /// Captures the trace where the conversion happened, used as a fallback
  /// when the caller did not supply one.
  static StackTrace _captureTrace() {
    try {
      throw const _TraceProbe();
    } on _TraceProbe catch (_, stackTrace) {
      return stackTrace;
    }
  }
}

/// Private sentinel used only to harvest a stack trace.
final class _TraceProbe implements Exception {
  const _TraceProbe();
}

/// Convenience conversion for raw errors thrown inside data/bridge layers.
extension ObjectToFailureX on Object {
  /// Converts this thrown object into a [Failure] via [ExceptionMapper].
  Failure asFailure([StackTrace? stackTrace]) =>
      ExceptionMapper.map(this, stackTrace);
}
