import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/identity_repository.dart';
import 'package:onebit/features/identity/domain/node_identity.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for [ImportBackup].
final class ImportBackupParams {
  const ImportBackupParams({required this.passphrase, required this.document});

  /// Password used when the document was exported.
  final String passphrase;

  /// The backup document string (base64url).
  final String document;
}

/// Restores an identity from an encrypted backup document.
///
/// The document's seeds are re-wrapped into the Keystore vault; an existing
/// identity on this device is replaced only after successful authentication.
final class ImportBackup
    extends UseCase<ImportBackupParams, Result<NodeIdentity>> {
  const ImportBackup(this._repository);

  final IdentityRepository _repository;

  @override
  Future<Result<NodeIdentity>> call(ImportBackupParams params) {
    return _repository.importBackup(
      passphrase: params.passphrase,
      document: params.document,
    );
  }
}
