import 'package:onebit/core/errors/exception_mapper.dart';
import 'package:onebit/core/errors/failure.dart';

/// Monadic wrapper around a computation that either produced a [value] of
/// type [T] or failed with a [Failure].
///
/// [Result] is the primary vehicle for domain-layer communication. Business
/// logic returns `Future<Result<T>>` instead of throwing, forcing every call
/// site to handle both outcomes explicitly and keeping control flow visible.
///
/// Example:
/// ```dart
/// final result = await repository.load();
/// switch (result) {
///   case Ok(:final value):   // value: T
///   case Err(:final failure): // failure: Failure
/// }
/// ```
sealed class Result<T> {
  const Result({this.value, this.failure});

  /// The produced value when this is [Ok], otherwise `null`.
  final T? value;

  /// The failure when this is [Err], otherwise `null`.
  final Failure? failure;

  /// True when the computation succeeded.
  bool get isOk => failure == null;

  /// True when the computation failed.
  bool get isErr => failure != null;

  /// Returns the value, or [fallback] when this is an [Err].
  T unwrapOr(T fallback) => value ?? fallback;

  /// Shorthand "unwrap or else compute".
  T unwrapOrElse(T Function(Failure failure) onErr) =>
      failure == null ? value as T : onErr(failure!);

  /// Flattens both outcomes into a single value.
  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) =>
      failure == null ? onOk(value as T) : onErr(failure!);

  /// Maps an [Ok] payload with [onOk]; an [Err] passes through untouched.
  Result<U> map<U>(U Function(T value) onOk) =>
      failure == null ? Ok(onOk(value as T)) : Err(failure!);

  /// Captures a throwing synchronous computation into a [Result].
  static Result<T> capture<T>(T Function() body) {
    try {
      return Ok(body());
    } catch (error, stackTrace) {
      return Err(ExceptionMapper.map(error, stackTrace));
    }
  }

  /// Captures a throwing asynchronous computation into a `Future<Result>`.
  static Future<Result<T>> captureAsync<T>(Future<T> Function() body) async {
    try {
      return Ok(await body());
    } catch (error, stackTrace) {
      return Err(ExceptionMapper.map(error, stackTrace));
    }
  }
}

/// Successful [Result] carrying a concrete [value].
final class Ok<T> extends Result<T> {
  const Ok(T value) : super(value: value);

  @override
  String toString() => 'Ok($value)';
}

/// Failed [Result] carrying the [Failure] that stopped the computation.
final class Err<T> extends Result<T> {
  const Err(Failure failure) : super(failure: failure);

  @override
  String toString() => 'Err(${failure!.kind})';
}

/// Capture utilities for asynchronous operations returning [Result].
extension FutureToResultX<T> on Future<T> {
  /// Runs the future and returns a [Result]; the result never throws.
  Future<Result<T>> toResult() async {
    try {
      return Ok(await this);
    } catch (error, stackTrace) {
      return Err(ExceptionMapper.map(error, stackTrace));
    }
  }
}
