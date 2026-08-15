/// Contract for a single unit of domain work.
///
/// Use cases encapsulate one business action and are the only thing a
/// controller may call into the domain layer for. Keep them small, pure and
/// fully unit-testable (no Flutter, no platform).
///
/// ```dart
/// final class FetchMeshStatus extends UseCase<NoParams, HomeStatus> {
///   FetchMeshStatus(this._repository);
///   final MeshStatusRepository _repository;
///   @override
///   Future<HomeStatus> call(NoParams params) => _repository.loadStatus();
/// }
/// ```
abstract class UseCase<Params, Output> {
  const UseCase();

  /// Executes the business action.
  Future<Output> call(Params params);
}

/// Marker for use cases that accept no arguments.
final class NoParams {
  const NoParams();

  /// Shared singleton value.
  static const NoParams instance = NoParams();
}
