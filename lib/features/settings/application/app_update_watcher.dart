import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/core/version/app_version.dart';
import 'package:onebit/features/settings/application/app_update_providers.dart';
import 'package:onebit/features/settings/application/app_update_service.dart';
import 'package:onebit/features/settings/data/settings_providers.dart';

/// Checks for a newer build on the two moments a user could hear about a
/// release without opening Settings: shortly after launch, and whenever the
/// app comes back from the background.
///
/// Neither trigger is allowed to fire unthrottled. Launching is cheap for
/// the user and expensive for the API, and resuming happens after phone
/// calls, so [interval] is what keeps the two from turning into a poll.
///
/// [scaffoldMessengerKey] belongs to the [MaterialApp] this widget wraps,
/// which is the only place a SnackBar can be raised without reaching down
/// into the Navigator. [onOpenUpdate] is injected for the same reason: the
/// route lives below this widget, and a callback is simpler than handing
/// it a context from the wrong scope.
class AppUpdateWatcher extends ConsumerStatefulWidget {
  const AppUpdateWatcher({
    super.key,
    required this.scaffoldMessengerKey,
    required this.onOpenUpdate,
    required this.child,
  });

  /// The shortest gap between two checks that reached the network.
  static const Duration interval = Duration(hours: 6);

  /// How long launch waits before the first check.
  ///
  /// The router, the settings repository and the platform plugins all
  /// settle during the first frame; starting earlier would race every one
  /// of them, and nothing is lost by waiting — the tile already shows a
  /// previously found update from storage.
  static const Duration startupDelay = Duration(seconds: 3);

  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  /// Opens the App update screen. Called by the SnackBar's action.
  final VoidCallback onOpenUpdate;

  final Widget child;

  @override
  ConsumerState<AppUpdateWatcher> createState() => _AppUpdateWatcherState();
}

class _AppUpdateWatcherState extends ConsumerState<AppUpdateWatcher>
    with WidgetsBindingObserver {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.delayed(AppUpdateWatcher.startupDelay, _check);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!mounted || _checking) return;

    final repo = ref.read(settingsRepositoryProvider);
    if (!repo.autoUpdateEnabled) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - repo.lastUpdateCheckAt < AppUpdateWatcher.interval.inMilliseconds) {
      return;
    }

    _checking = true;
    try {
      // Prefer the version stamped into this binary over the pubspec
      // fallback: comparing against a constant that has fallen behind is
      // how a build ends up being told forever that it is out of date.
      await AppVersion.load();
      if (!mounted) return;

      final updates = await ref.read(appUpdateServiceProvider).checkForUpdates();
      // `null` means neither source answered. Leaving the timestamp alone
      // keeps the window honest: a check that never ran has not been made,
      // so a launch in a tunnel does not push the next one six hours out.
      if (updates == null) return;
      await repo.setLastUpdateCheckAt(now);
      if (!mounted) return;
      await _publish(updates.isEmpty ? null : updates.first);
    } on Exception catch (e) {
      AppLogger.warning('AppUpdate: automatic check failed: $e');
    } finally {
      _checking = false;
    }
  }

  /// Hands [update] to storage, the provider and the user, in that order.
  Future<void> _publish(AppUpdateInfo? update) async {
    final repo = ref.read(settingsRepositoryProvider);

    if (update == null) {
      // This build is current, so retire whatever the last check left.
      await repo.setPendingUpdate(version: null, url: null);
      if (!mounted) return;
      ref.read(pendingAppUpdateProvider.notifier).state = null;
      return;
    }

    await repo.setPendingUpdate(
      version: update.version,
      url: update.releaseUrl,
    );
    if (!mounted) return;
    ref.read(pendingAppUpdateProvider.notifier).state = update;
    _announce(update);
  }

  void _announce(AppUpdateInfo update) {
    final messenger = widget.scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('OneBit ${update.version} is available.'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'UPDATE',
            onPressed: widget.onOpenUpdate,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
