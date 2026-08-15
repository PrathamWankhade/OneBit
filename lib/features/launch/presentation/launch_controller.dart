import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/app/shell_controller.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/navigation/app_router_provider.dart';
import 'package:onebit/features/identity/domain/user_profile.dart';
import 'package:onebit/features/identity/presentation/identity_controller.dart';
import 'package:onebit/features/launch/domain/display_name_validator.dart';
import 'package:onebit/features/launch/domain/first_run_state.dart';
import 'package:onebit/features/launch/domain/launch_flow_resolver.dart';
import 'package:onebit/features/launch/domain/local_initializer.dart';
import 'package:onebit/features/launch/presentation/launch_providers.dart';

/// Transient state of the local initialization step.
///
/// Mirrors exactly what happened: every completed check is kept (so the
/// screen renders real status lines), and a failure is reported once.
final class LaunchInitializationState {
  const LaunchInitializationState({
    this.running = false,
    this.checks = const [],
    this.error,
  });

  /// Whether initialization is currently running.
  final bool running;

  /// Completed checks, in run order (including a failed one, if any).
  final List<LocalInitOutcome> checks;

  /// The failure that stopped initialization (null while running/ok).
  final Object? error;

  /// Whether initialization stopped on a failure.
  bool get failed => error != null;
}

/// Drives the first-run launch experience.
///
/// The launch area (`/launch`, `/intro`, `/setup/*`) is the only place that
/// can transition the state machine, and every transition happens here —
/// screens never touch the router, so the machine stays in one location.
final class LaunchController extends Notifier<LaunchInitializationState> {
  @override
  LaunchInitializationState build() => const LaunchInitializationState();

  FirstRunRepository get _repository => ref.read(firstRunRepositoryProvider);

  /// The setup route matching [state] (used by the route guard too).
  static String setupDestination(FirstRunState state) => switch (state) {
    FirstRunState.newInstallation || FirstRunState.intro => AppRoutePaths.intro,
    FirstRunState.displayNameRequired => AppRoutePaths.displayNameSetup,
    FirstRunState.initializing => AppRoutePaths.initializing,
    FirstRunState.completed => AppRoutePaths.channels,
  };

  /// The opening animation finished — leave the launch area.
  ///
  /// Ready installs land on the restored tab; fresh installs enter the
  /// resolved setup stage.
  Future<void> finishOpening(LaunchFlowResolution resolution) async {
    final router = ref.read(goRouterProvider);
    if (resolution.ready) {
      final restored = await ref.read(restoredTabPathProvider.future);
      router.go(restored);
      return;
    }
    router.go(setupDestination(resolution.state));
  }

  /// Intro → display-name setup.
  Future<void> proceedFromIntro() async {
    await _repository.save(FirstRunState.displayNameRequired);
    ref.read(goRouterProvider).go(AppRoutePaths.displayNameSetup);
  }

  /// Display-name setup → intro (system back gesture).
  Future<void> returnToIntro() async {
    await _repository.save(FirstRunState.intro);
    ref.read(goRouterProvider).go(AppRoutePaths.intro);
  }

  /// Validates and persists the display name, then moves to initialization.
  ///
  /// Returns the validation issue, or `null` when the name was accepted.
  /// Storage failures surface as exceptions (the screen renders them).
  Future<DisplayNameIssue?> submitDisplayName(String raw) async {
    final validation = DisplayNameValidator.validate(raw);
    if (!validation.isValid) {
      return validation.issue;
    }

    final identity = await ref.read(identityControllerProvider.future);
    if (identity == null) {
      // Fresh node: creating the identity persists the display name with it.
      await ref
          .read(identityControllerProvider.notifier)
          .create(displayName: validation.normalized, avatarColor: 0);
    } else {
      // Identity already exists (e.g. name was lost): keep the Node ID and
      // keys, only update the profile.
      await ref
          .read(identityControllerProvider.notifier)
          .updateProfile(
            UserProfile(
              displayName: validation.normalized,
              avatarColor: identity.profile.avatarColor,
            ),
          );
    }

    await _repository.save(FirstRunState.initializing);
    ref.read(goRouterProvider).go(AppRoutePaths.initializing);
    return null;
  }

  /// Runs the real local initialization, one check at a time.
  Future<void> runInitialization() async {
    if (state.running) return;
    state = const LaunchInitializationState(running: true);
    try {
      await for (final outcome
          in ref.read(localInitializerProvider).initialize()) {
        final checks = [...state.checks, outcome];
        state = LaunchInitializationState(running: true, checks: checks);
        if (!outcome.ok) {
          state = LaunchInitializationState(
            running: false,
            checks: checks,
            error: outcome.error,
          );
          return;
        }
      }
      // All checks passed: only now is first-run setup complete.
      await _repository.save(FirstRunState.completed);
      state = const LaunchInitializationState();
      ref.read(goRouterProvider).go(AppRoutePaths.channels);
    } on Object catch (error) {
      state = LaunchInitializationState(
        running: false,
        checks: state.checks,
        error: error,
      );
    }
  }

  /// Re-runs initialization after a failure.
  Future<void> retryInitialization() async {
    state = const LaunchInitializationState();
    await runInitialization();
  }
}
