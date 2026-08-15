import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/identity/domain/trust_contact.dart';
import 'package:onebit/features/identity/domain/trust_level.dart';
import 'package:onebit/features/identity/domain/use_cases/remove_trust_contact.dart';
import 'package:onebit/features/identity/domain/use_cases/update_trust_contact.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Owns the known contacts list.
final AsyncNotifierProvider<TrustContactsController, List<TrustContact>>
trustContactsControllerProvider =
    AsyncNotifierProvider<TrustContactsController, List<TrustContact>>(
      TrustContactsController.new,
    );

final class TrustContactsController extends AsyncNotifier<List<TrustContact>> {
  @override
  Future<List<TrustContact>> build() async {
    final result = await ref
        .watch(loadTrustContactsProvider)
        .call(NoParams.instance);
    if (result.isErr) {
      throw result.failure!;
    }
    return result.value!;
  }

  /// Adds or refreshes a contact (e.g. from a scanned identity card).
  Future<void> add(TrustContact contact) async {
    final result = await ref.read(addTrustContactProvider).call(contact);
    if (result.isErr) {
      throw result.failure!;
    }
    await _reload();
  }

  /// Applies a new trust posture to [nodeId].
  Future<void> setTrustLevel(String nodeId, TrustLevel level) async {
    final result = await ref
        .read(updateTrustContactProvider)
        .call(UpdateTrustContactParams(nodeId: nodeId, trustLevel: level));
    if (result.isErr) {
      throw result.failure!;
    }
    await _reload();
  }

  /// Removes [nodeId] from the contact list.
  Future<void> remove(String nodeId) async {
    final result = await ref
        .read(removeTrustContactProvider)
        .call(RemoveTrustContactParams(nodeId));
    if (result.isErr) {
      throw result.failure!;
    }
    await _reload();
  }

  Future<void> _reload() async {
    final result = await ref
        .read(loadTrustContactsProvider)
        .call(NoParams.instance);
    if (result.isErr) {
      throw result.failure!;
    }
    state = AsyncData(result.value!);
  }
}
