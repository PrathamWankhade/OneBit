import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/identity_repository.dart';
import 'package:onebit/features/identity/domain/node_identity.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for [CreateIdentity].
final class CreateIdentityParams {
  const CreateIdentityParams({
    required this.displayName,
    required this.avatarColor,
  });

  /// Initial display name.
  final String displayName;

  /// Initial avatar accent index.
  final int avatarColor;
}

/// Generates the node's identity on first launch.
final class CreateIdentity
    extends UseCase<CreateIdentityParams, Result<NodeIdentity>> {
  const CreateIdentity(this._repository);

  final IdentityRepository _repository;

  @override
  Future<Result<NodeIdentity>> call(CreateIdentityParams params) {
    return _repository.createIdentity(
      displayName: params.displayName,
      avatarColor: params.avatarColor,
    );
  }
}
