import 'package:onebit/features/launch/domain/first_run_state.dart';

/// Resolved outcome of the launch gate.
///
/// Mirrors the first-run state machine:
///
/// ```
/// Unknown → NewInstallation → Intro → DisplayNameRequired
///   → Initializing → Ready (completed)
/// ExistingInstallation → Ready
/// ```
final class LaunchFlowResolution {
  const LaunchFlowResolution({required this.state, required this.ready});

  /// The resolved persistent state (never `null` after resolution).
  final FirstRunState state;

  /// Whether first-run setup has fully completed (Ready).
  final bool ready;
}

/// Pure resolution of the launch destination.
///
/// Takes the persisted first-run state and the presence of a local identity
/// and answers: is setup complete, and where should the launch animation
/// send the user? This is the single place where the state machine lives —
/// navigation logic never re-implements it.
///
/// Rules:
/// * Identity present + `completed` (or nothing stored — legacy install)
///   ⇒ Ready.
/// * Identity present + a pending setup stage ⇒ the display name is already
///   persisted; only initialization remains ⇒ `initializing`.
/// * No identity ⇒ resume the persisted stage, or `newInstallation` when
///   nothing is stored. A persisted `initializing` without an identity is
///   treated as `displayNameRequired` (the identity was lost; the name must
///   be (re)entered before initialization can run). A persisted `completed`
///   without an identity is treated as `newInstallation` — setup is no
///   longer valid once the identity it produced is gone.
abstract final class LaunchFlowResolver {
  const LaunchFlowResolver._();

  static LaunchFlowResolution resolve({
    required bool hasIdentity,
    required FirstRunState? persisted,
  }) {
    if (hasIdentity) {
      final ready = persisted == null || persisted == FirstRunState.completed;
      return LaunchFlowResolution(
        state: ready ? FirstRunState.completed : FirstRunState.initializing,
        ready: ready,
      );
    }
    final state = switch (persisted) {
      FirstRunState.initializing => FirstRunState.displayNameRequired,
      FirstRunState.completed => FirstRunState.newInstallation,
      null => FirstRunState.newInstallation,
      _ => persisted,
    };
    return LaunchFlowResolution(state: state, ready: false);
  }
}
