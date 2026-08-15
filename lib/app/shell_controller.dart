import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence keys for shell navigation state.
///
/// Only non-sensitive UI state is stored here (current tab). Identity and
/// messaging data never flow through this namespace.
abstract final class ShellNavigationKeys {
  /// Last active tab path, restored on the next launch.
  static const String lastTabPath = 'onebit.navigation.lastTabPath';

  const ShellNavigationKeys._();
}

/// The tab to land on after splash, restored from the previous session.
///
/// Resolves asynchronously so the boot redirect can wait for it before
/// leaving the splash screen (see `AppRouter`).
final FutureProvider<String> restoredTabPathProvider = FutureProvider<String>((
  ref,
) async {
  final prefs = SharedPreferencesAsync();
  return await prefs.getString(ShellNavigationKeys.lastTabPath) ??
      AppRoutePaths.channels;
});

/// Persists the currently active tab.
///
/// Fire-and-forget: the write is best-effort and never blocks navigation.
Future<void> persistLastTabPath(String path) async {
  final prefs = SharedPreferencesAsync();
  await prefs.setString(ShellNavigationKeys.lastTabPath, path);
}
