import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/trust_contact.dart';
import 'package:onebit/features/identity/domain/trust_contact_repository.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Adds a peer discovered from a verified identity card as a contact.
final class AddTrustContact
    extends UseCase<TrustContact, Result<TrustContact>> {
  const AddTrustContact(this._repository);

  final TrustContactRepository _repository;

  @override
  Future<Result<TrustContact>> call(TrustContact params) {
    return _repository.upsert(params);
  }
}
