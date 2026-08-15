import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/errors/exception_mapper.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/logger/logger_providers.dart';

/// Base class for feature controllers.
///
/// A controller owns one feature slice of UI state as an [AsyncValue]. It
/// must not know about widgets, but it knows how to route failures to the
/// failure framework and logger.
///
/// Extend and implement `build()` like a plain `AsyncNotifier`:
/// ```dart
/// final class HomeController extends BaseStateController<HomeStatus> {
///   @override
///   Future<HomeStatus> build() async { ... }
/// }
/// ```
abstract class BaseStateController<T> extends AsyncNotifier<T> {
  /// Emits [error] through the failure framework and rethrows it as an
  /// [Exception] so the widget layer's AsyncValue shows the error state.
  Never fail(
    Object error, {
    String message = 'Controller failure',
    String? tag,
  }) {
    final failure = ExceptionMapper.map(error);
    ref
        .read(appLoggerProvider)
        .error(message, tag: tag ?? LogTags.app, error: failure);
    throw error;
  }
}

/// Shorthand for the AsyncNotifier type a feature controller extends.
typedef StateController<T> = BaseStateController<T>;
