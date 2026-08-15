import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/identity_repository.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for [ExportBackup].
final class ExportBackupParams {
  const ExportBackupParams(this.passphrase);

  /// User-chosen password protecting the document.
  final String passphrase;
}

/// Produces the encrypted backup document for this identity.
final class ExportBackup extends UseCase<ExportBackupParams, Result<String>> {
  const ExportBackup(this._repository);

  final IdentityRepository _repository;

  @override
  Future<Result<String>> call(ExportBackupParams params) {
    return _repository.exportBackup(passphrase: params.passphrase);
  }
}
