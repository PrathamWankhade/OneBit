import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/identity_repository.dart';
import 'package:onebit/features/identity/domain/node_identity.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Loads the node's identity, or `null` when none exists yet.
final class LoadIdentity extends UseCase<NoParams, Result<NodeIdentity?>> {
  const LoadIdentity(this._repository);

  final IdentityRepository _repository;

  @override
  Future<Result<NodeIdentity?>> call(NoParams params) {
    return _repository.loadIdentity();
  }
}
