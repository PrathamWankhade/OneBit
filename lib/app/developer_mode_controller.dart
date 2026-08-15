import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns developer mode.
///
/// Hidden by default; unlocked by tapping the version row in About
/// [DeveloperModeController.versionTapsRequired] times within
/// [DeveloperModeController.versionTapWindow]. The flag is a non-sensitive
/// UI preference, so it is persisted in `SharedPreferences`.
final AsyncNotifierProvider<DeveloperModeController, bool>
developerModeProvider = AsyncNotifierProvider<DeveloperModeController, bool>(
  DeveloperModeController.new,
);

final class DeveloperModeController extends AsyncNotifier<bool> {
  /// Taps on the version row required to unlock developer mode.
  static const int versionTapsRequired = 7;

  /// Maximum gap between two taps of one unlocking sequence.
  static const Duration versionTapWindow = Duration(seconds: 3);

  static const String _prefsKey = 'onebit.navigation.developerMode';

  int _tapCount = 0;
  DateTime _lastTapAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<bool> build() async {
    final prefs = SharedPreferencesAsync();
    return await prefs.getBool(_prefsKey) ?? false;
  }

  /// Registers one tap on the version row.
  ///
  /// Returns `true` when the sequence just completed and developer mode is
  /// now enabled (callers show the confirmation toast then).
  bool registerVersionTap() {
    final now = clock.now();
    if (now.difference(_lastTapAt) > versionTapWindow) {
      _tapCount = 0;
    }
    _lastTapAt = now;
    _tapCount += 1;
    if (_tapCount < versionTapsRequired) {
      return false;
    }
    _tapCount = 0;
    unawaited(enable());
    return true;
  }

  /// Unlocks developer mode and persists the choice.
  Future<void> enable() async {
    final prefs = SharedPreferencesAsync();
    await prefs.setBool(_prefsKey, true);
    state = const AsyncData(true);
  }

  /// Locks developer mode again and persists the choice.
  Future<void> disable() async {
    final prefs = SharedPreferencesAsync();
    await prefs.setBool(_prefsKey, false);
    state = const AsyncData(false);
  }
}
