import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/trust_contact_repository.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for [RemoveTrustContact].
final class RemoveTrustContactParams {
  const RemoveTrustContactParams(this.nodeId);

  /// `NODE-XXXX-XXXX` of the contact to remove.
  final String nodeId;
}

/// Removes a contact from this device. Idempotent.
final class RemoveTrustContact
    extends UseCase<RemoveTrustContactParams, Result<void>> {
  const RemoveTrustContact(this._repository);

  final TrustContactRepository _repository;

  @override
  Future<Result<void>> call(RemoveTrustContactParams params) async {
    final removed = await _repository.remove(params.nodeId);
    return removed.map((_) {});
  }
}
