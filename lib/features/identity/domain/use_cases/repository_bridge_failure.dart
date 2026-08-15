import 'package:onebit/core/errors/failure.dart';

/// Adapter that carries a [Failure] out of a callback-based crypto seam
/// (signing, ECDH providers) which cannot return a `Result` directly.
///
/// Throw this inside the callback and catch it in the use case to convert
/// back into the failure framework without losing the original error.
final class RepositoryBridgeFailure implements Exception {
  const RepositoryBridgeFailure(this.failure);

  /// The underlying [Failure], e.g. `PlatformFailure` from the vault.
  final Failure failure;

  @override
  String toString() => 'RepositoryBridgeFailure($failure)';
}
