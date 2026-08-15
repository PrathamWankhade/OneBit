import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/identity_repository.dart';
import 'package:onebit/features/identity/domain/node_identity.dart';
import 'package:onebit/features/identity/domain/user_profile.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Updates the user-editable profile.
final class UpdateProfile extends UseCase<UserProfile, Result<NodeIdentity>> {
  const UpdateProfile(this._repository);

  final IdentityRepository _repository;

  @override
  Future<Result<NodeIdentity>> call(UserProfile params) {
    return _repository.updateProfile(params);
  }
}
