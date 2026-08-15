import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/trust_contact.dart';
import 'package:onebit/features/identity/domain/trust_contact_repository.dart';
import 'package:onebit/features/identity/domain/trust_level.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for [UpdateTrustContact].
final class UpdateTrustContactParams {
  const UpdateTrustContactParams({
    required this.nodeId,
    this.trustLevel,
    this.note,
  });

  /// `NODE-XXXX-XXXX` of the contact to update.
  final String nodeId;

  /// New trust posture to apply (when set).
  final TrustLevel? trustLevel;

  /// New note text (when set).
  final String? note;
}

/// Changes a contact's trust level or note.
final class UpdateTrustContact
    extends UseCase<UpdateTrustContactParams, Result<TrustContact>> {
  const UpdateTrustContact(this._repository);

  final TrustContactRepository _repository;

  @override
  Future<Result<TrustContact>> call(UpdateTrustContactParams params) async {
    final found = await _repository.find(params.nodeId);
    if (found.isErr) {
      return Err(found.failure!);
    }
    final contact = found.value;
    if (contact == null) {
      return _missing(params.nodeId);
    }
    final level = params.trustLevel;
    if (level != null) {
      return _repository.setTrustLevel(nodeId: params.nodeId, level: level);
    }
    if (params.note != null) {
      return _repository.upsert(contact.copyWith(note: params.note));
    }
    return Ok(contact);
  }

  Result<TrustContact> _missing(String nodeId) {
    return Err(
      IdentityFailure(
        code: 'contact_not_found',
        message: 'No contact with node id $nodeId',
      ),
    );
  }
}
