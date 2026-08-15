import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/identity_repository.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Permanently removes the node's identity from this device.
///
/// Idempotent: deleting a non-existent identity succeeds.
final class DeleteIdentity extends UseCase<NoParams, Result<void>> {
  const DeleteIdentity(this._repository);

  final IdentityRepository _repository;

  @override
  Future<Result<void>> call(NoParams params) {
    return _repository.deleteIdentity();
  }
}
