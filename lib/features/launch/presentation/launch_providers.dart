import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/identity/presentation/identity_controller.dart';
import 'package:onebit/features/launch/data/shared_preferences_first_run_repository.dart';
import 'package:onebit/features/launch/domain/first_run_state.dart';
import 'package:onebit/features/launch/domain/launch_flow_resolver.dart';
import 'package:onebit/features/launch/domain/local_initializer.dart';
import 'package:onebit/features/launch/presentation/launch_controller.dart';
import 'package:onebit/features/launch/presentation/riverpod_local_initializer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The persisted first-run state machine (overridable in tests).
final Provider<FirstRunRepository> firstRunRepositoryProvider =
    Provider<FirstRunRepository>((ref) {
      return SharedPreferencesFirstRunRepository(SharedPreferencesAsync());
    });

/// The real local initializer (overridable in tests).
final Provider<LocalInitializer> localInitializerProvider =
    Provider<LocalInitializer>(RiverpodLocalInitializer.new);

/// The resolved launch gate: identity + persisted first-run state.
///
/// Recomputes whenever the identity changes (create, update, delete), which
/// is how the router and the opening screen stay in sync with the state
/// machine.
final FutureProvider<LaunchFlowResolution> launchFlowProvider =
    FutureProvider<LaunchFlowResolution>((ref) async {
      final identity = await ref.watch(identityControllerProvider.future);
      final persisted = await ref.watch(firstRunRepositoryProvider).load();
      return LaunchFlowResolver.resolve(
        hasIdentity: identity != null,
        persisted: persisted,
      );
    });

/// Transient launch state (initialization progress).
final NotifierProvider<LaunchController, LaunchInitializationState>
launchControllerProvider =
    NotifierProvider<LaunchController, LaunchInitializationState>(
      LaunchController.new,
    );
