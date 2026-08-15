import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/theme/theme_preference.dart';

/// Owns the currently selected [ThemePreference].
///
/// The shell watches this provider and rebuilds `MaterialApp` with the light
/// and dark identities plus `preference.themeMode`. Persistence of the
/// choice arrives with the settings repository in a later phase; until then
/// the selection is process-local and defaults to following the system.
final NotifierProvider<ThemePreferenceController, ThemePreference>
themePreferenceProvider =
    NotifierProvider<ThemePreferenceController, ThemePreference>(
      ThemePreferenceController.new,
    );

final class ThemePreferenceController extends Notifier<ThemePreference> {
  @override
  ThemePreference build() => ThemePreference.system;

  /// Applies [preference] and returns it (for chaining).
  ThemePreference setTheme(ThemePreference preference) {
    state = preference;
    return preference;
  }

  /// Cycles through system → light → dark → system.
  void cycleTheme() {
    final index = ThemePreference.values.indexOf(state);
    state = ThemePreference.values[(index + 1) % ThemePreference.values.length];
  }
}
