import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/settings/application/app_update_installer.dart';
import 'package:onebit/features/settings/application/app_update_service.dart';
import 'package:onebit/features/settings/data/settings_providers.dart';

/// The shared [AppUpdateService].
///
/// The underlying `HttpClient` is released when this provider is disposed.
final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  final service = AppUpdateService();
  ref.onDispose(service.dispose);
  return service;
});

/// The shared [AppUpdateInstaller].
///
/// Stateless apart from the method channel, so there is nothing to dispose.
final appUpdateInstallerProvider = Provider<AppUpdateInstaller>((ref) {
  return AppUpdateInstaller();
});

/// The newest upstream build waiting to be installed, or `null`.
///
/// Seeded from storage rather than from the network, so the tile offering
/// the update is already there on the first frame after a restart instead
/// of appearing a request later. [AppUpdateWatcher] writes it whenever a
/// check finds something and clears it once this build is current.
final pendingAppUpdateProvider = StateProvider<AppUpdateInfo?>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  final version = repo.pendingUpdateVersion;
  if (version == null || version.isEmpty) return null;
  return AppUpdateInfo(
    version: version,
    releaseUrl: repo.pendingUpdateUrl ?? AppUpdateService.repoReleasesUrl,
  );
}, dependencies: [settingsRepositoryProvider]);
