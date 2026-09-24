import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/settings/data/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError(
    'settingsRepositoryProvider must be overridden at app startup',
  );
});

// ── Appearance ──

final settingsThemeProvider = StateProvider<int>(
  (ref) {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.themeModeIndex;
  },
  dependencies: [settingsRepositoryProvider],
);

final settingsAccentColorProvider = StateProvider<int>(
  (ref) {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.accentColorIndex;
  },
  dependencies: [settingsRepositoryProvider],
);

final settingsFontSizeProvider = StateProvider<int>(
  (ref) {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.fontSizeIndex;
  },
  dependencies: [settingsRepositoryProvider],
);

final settingsShowTimestampsProvider = StateProvider<bool>(
  (ref) {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.showTimestamps;
  },
  dependencies: [settingsRepositoryProvider],
);

final settingsCompactModeProvider = StateProvider<bool>(
  (ref) {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.compactMode;
  },
  dependencies: [settingsRepositoryProvider],
);

final settingsReducedMotionProvider = StateProvider<bool>(
  (ref) {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.reducedMotion;
  },
  dependencies: [settingsRepositoryProvider],
);

// ── Notifications ──

final settingsNotificationsEnabledProvider = StateProvider<bool>(
  (ref) {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.notificationsEnabled;
  },
  dependencies: [settingsRepositoryProvider],
);

final settingsNotificationSoundProvider = StateProvider<bool>(
  (ref) {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.notificationSound;
  },
  dependencies: [settingsRepositoryProvider],
);

final settingsNotificationVibrationProvider = StateProvider<bool>(
  (ref) {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.notificationVibration;
  },
  dependencies: [settingsRepositoryProvider],
);

// ── Mesh ──

final settingsDiscoveryEnabledProvider = StateProvider<bool>(
  (ref) {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.discoveryEnabled;
  },
  dependencies: [settingsRepositoryProvider],
);

final settingsRelayEnabledProvider = StateProvider<bool>(
  (ref) {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.relayEnabled;
  },
  dependencies: [settingsRepositoryProvider],
);
