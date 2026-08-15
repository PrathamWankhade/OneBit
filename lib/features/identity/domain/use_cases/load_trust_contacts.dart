import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/trust_contact.dart';
import 'package:onebit/features/identity/domain/trust_contact_repository.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Loads all known trust contacts.
final class LoadTrustContacts
    extends UseCase<NoParams, Result<List<TrustContact>>> {
  const LoadTrustContacts(this._repository);

  final TrustContactRepository _repository;

  @override
  Future<Result<List<TrustContact>>> call(NoParams params) {
    return _repository.loadContacts();
  }
}
