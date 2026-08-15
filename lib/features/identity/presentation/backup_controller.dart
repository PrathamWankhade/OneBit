import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/identity/domain/use_cases/export_backup.dart';
import 'package:onebit/features/identity/domain/use_cases/import_backup.dart';
import 'package:onebit/features/identity/presentation/identity_controller.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';

/// Owns backup export/import lifecycle.
///
/// State:
/// - `null` ⇒ idle,
/// - a non-null string ⇒ the latest encrypted backup document (safe to show
///   for saving; it contains no plaintext).
final AsyncNotifierProvider<BackupController, String?>
backupControllerProvider = AsyncNotifierProvider<BackupController, String?>(
  BackupController.new,
);

final class BackupController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  /// Generates an encrypted backup document for [passphrase].
  Future<void> export({required String passphrase}) async {
    final result = await ref
        .read(exportBackupProvider)
        .call(ExportBackupParams(passphrase));
    if (result.isErr) {
      throw result.failure!;
    }
    state = AsyncData(result.value);
  }

  /// Restores the identity from [document]; returns the node id.
  ///
  /// On success the identity controller is invalidated so the UI picks up
  /// the restored identity.
  Future<String> import({
    required String passphrase,
    required String document,
  }) async {
    final result = await ref
        .read(importBackupProvider)
        .call(ImportBackupParams(passphrase: passphrase, document: document));
    if (result.isErr) {
      throw result.failure!;
    }
    final nodeId = result.value!.nodeId.value;
    ref.invalidate(identityControllerProvider);
    return nodeId;
  }

  /// Discards any generated document from state.
  void clear() => state = const AsyncData(null);
}
