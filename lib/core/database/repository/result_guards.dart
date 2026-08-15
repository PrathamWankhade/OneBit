import 'dart:async';

import 'package:onebit/core/errors/exception_mapper.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';

/// Shared edge-guarding for repository operations.
///
/// Every repository method runs through [guard] so DAO/Drift exceptions are
/// captured exactly once, mapped to a [StorageFailure] tagged with the
/// offending operation, and logged with `LogTags.storage`.
abstract final class ResultGuards {
  const ResultGuards._();

  /// Runs [body] and folds any thrown exception into `Err(StorageFailure)`.
  static Future<Result<T>> guard<T>(
    AppLogger logger,
    String operation,
    Future<T> Function() body,
  ) async {
    try {
      return Ok(await body());
    } catch (error, stackTrace) {
      final failure = toStorageFailure(operation, error, stackTrace);
      logger.error('$operation failed', tag: LogTags.storage, error: failure);
      return Err(failure);
    }
  }

  /// Wraps a drift watch stream so it never throws.
  ///
  /// A query failure emits `Err(...)` and the stream stays open until the
  /// underlying query closes it.
  static Stream<Result<T>> guardWatch<T>(
    AppLogger logger,
    String operation,
    Stream<T> source,
  ) => Stream.multi((controller) {
    late final StreamSubscription<T> subscription;
    subscription = source.listen(
      (value) => controller.add(Ok(value)),
      onError: (Object error, StackTrace stackTrace) {
        final failure = toStorageFailure(operation, error, stackTrace);
        logger.error(
          '$operation watch failed',
          tag: LogTags.storage,
          error: failure,
        );
        controller.add(Err(failure));
      },
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  });

  /// Maps any exception to [StorageFailure], preserving the mapped detail.
  static StorageFailure toStorageFailure(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    final base = ExceptionMapper.map(error, stackTrace);
    return StorageFailure(
      message: base.message,
      cause: error,
      stackTrace: stackTrace,
      operation: operation,
    );
  }
}
