import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/identity/domain/node_identity.dart';
import 'package:onebit/features/identity/domain/use_cases/create_identity.dart';
import 'package:onebit/features/identity/domain/user_profile.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Owns the node identity lifecycle.
///
/// - `null` state ⇒ no identity yet (first-run onboarding should call
///   [create]).
/// - Loaded ⇒ public identity material (no secrets).
final AsyncNotifierProvider<IdentityController, NodeIdentity?>
identityControllerProvider =
    AsyncNotifierProvider<IdentityController, NodeIdentity?>(
      IdentityController.new,
    );

final class IdentityController extends AsyncNotifier<NodeIdentity?> {
  @override
  Future<NodeIdentity?> build() async {
    final result = await ref
        .watch(loadIdentityProvider)
        .call(NoParams.instance);
    if (result.isErr) {
      throw result.failure!;
    }
    return result.value;
  }

  /// Creates the identity on first launch.
  Future<void> create({
    required String displayName,
    required int avatarColor,
  }) async {
    final result = await ref
        .read(createIdentityProvider)
        .call(
          CreateIdentityParams(
            displayName: displayName,
            avatarColor: avatarColor,
          ),
        );
    if (result.isErr) {
      throw result.failure!;
    }
    state = AsyncData(result.value);
  }

  /// Persists a profile change and reflects it in state.
  Future<void> updateProfile(UserProfile profile) async {
    final result = await ref.read(updateProfileProvider).call(profile);
    if (result.isErr) {
      throw result.failure!;
    }
    state = AsyncData(result.value);
  }

  /// Permanently deletes the identity from this device.
  Future<void> delete() async {
    final result = await ref
        .read(deleteIdentityProvider)
        .call(NoParams.instance);
    if (result.isErr) {
      throw result.failure!;
    }
    state = const AsyncData(null);
  }
}
