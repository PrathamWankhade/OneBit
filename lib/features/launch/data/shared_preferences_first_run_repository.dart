import 'package:onebit/features/launch/domain/first_run_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [FirstRunRepository] backed by the existing local preferences mechanism.
///
/// OneBit already persists non-secret application metadata in
/// `SharedPreferences` (navigation state in `shell_controller.dart`, public
/// identity metadata in `IdentityRepositoryImpl`) — this repository follows
/// the same storage architecture instead of inventing a new one.
final class SharedPreferencesFirstRunRepository implements FirstRunRepository {
  const SharedPreferencesFirstRunRepository(this._prefs);

  final SharedPreferencesAsync _prefs;

  @override
  Future<FirstRunState?> load() async {
    final raw = await _prefs.getString(FirstRunKeys.state);
    if (raw == null) {
      return null;
    }
    for (final state in FirstRunState.values) {
      if (state.name == raw) {
        return state;
      }
    }
    // Unknown serialized value: treat as an untouched installation rather
    // than crashing or inventing a state.
    return null;
  }

  @override
  Future<void> save(FirstRunState state) async {
    await _prefs.setString(FirstRunKeys.state, state.name);
  }
}
