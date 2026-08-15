/// Persistent first-run setup state of the local application.
///
/// This is NOT an account or an identity state: it only tracks how far the
/// local first-run presentation flow has progressed. The canonical technical
/// identity (cryptographic Node ID) lives in the identity feature; the
/// display name is presentation metadata stored through the identity
/// repository.
///
/// States form the state machine:
///
/// ```
/// Unknown (fresh install)
///   → newInstallation → intro → displayNameRequired
///     → initializing → completed (Ready)
/// ExistingInstallation → completed (Ready)
/// Failure: any state → error → retry → previous state
/// ```
enum FirstRunState {
  /// Fresh install — nothing has been shown yet.
  newInstallation,

  /// The intro screen is (or was) visible.
  intro,

  /// The display-name setup screen is (or was) visible.
  displayNameRequired,

  /// Local initialization is in progress.
  initializing,

  /// First-run setup finished successfully. The app is Ready.
  completed,
}

/// Persistence contract for the first-run state machine.
///
/// Values are plain application metadata (never secret material) persisted
/// with the existing local settings/preferences mechanism. `null` means
/// "unknown" — resolved against the identity by the launch flow.
abstract interface class FirstRunRepository {
  /// The stored state, or `null` when nothing has been stored yet.
  Future<FirstRunState?> load();

  /// Persists [state] atomically.
  Future<void> save(FirstRunState state);
}

/// First-run persistence keys.
abstract final class FirstRunKeys {
  /// Preference key holding the serialized [FirstRunState].
  static const String state = 'onebit.firstRun.state';

  const FirstRunKeys._();
}
