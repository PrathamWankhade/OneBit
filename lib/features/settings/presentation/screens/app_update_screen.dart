import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/core/version/app_version.dart';
import 'package:onebit/features/settings/application/app_update_providers.dart';
import 'package:onebit/features/settings/application/app_update_service.dart';
import 'package:onebit/features/settings/data/settings_providers.dart';
import 'package:onebit/features/settings/presentation/widgets/settings_section.dart';
import 'package:onebit/features/settings/presentation/widgets/settings_tile.dart';
import 'package:onebit/features/settings/presentation/widgets/settings_toggle.dart';
import 'package:url_launcher/url_launcher.dart';

/// F8 — App update screen.
///
/// Holds the auto-update toggle and a manual check against the project's
/// GitHub repository. When auto-update is on and a newer build exists, the
/// check performed on opening this screen also raises a notification.
///
/// A release that carries an APK can be installed from here without leaving
/// the app; one that does not opens the release page instead.
class AppUpdateScreen extends ConsumerStatefulWidget {
  const AppUpdateScreen({super.key});

  @override
  ConsumerState<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends ConsumerState<AppUpdateScreen> {
  bool _checking = false;
  bool _checked = false;
  String? _error;
  List<AppUpdateInfo>? _updates;

  bool _installing = false;
  int _received = 0;
  int _total = 0;
  String? _installError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdates());
  }

  AppUpdateInfo? get _newest {
    final available = _updates ?? const <AppUpdateInfo>[];
    return available.isEmpty ? null : available.first;
  }

  Future<void> _checkForUpdates() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });

    List<AppUpdateInfo>? updates;
    try {
      updates = await ref.read(appUpdateServiceProvider).checkForUpdates();
    } on Exception catch (e) {
      AppLogger.warning('AppUpdate: update check failed: $e');
    }

    if (!mounted) return;
    setState(() {
      _checking = false;
      _checked = true;
      _updates = updates;
      _error = updates == null ? 'Could not check for updates.' : null;
    });

    final newest = updates == null || updates.isEmpty ? null : updates.first;
    if (newest != null && ref.read(settingsAutoUpdateProvider)) {
      _announce(newest);
    }
  }

  /// Downloads the newest release and hands it to the system installer.
  ///
  /// The permission gate comes first on purpose: Android will not let an
  /// app install a package until the user has flipped its switch, so
  /// downloading first would only produce a file that cannot be used and a
  /// second tap that starts the whole download again.
  Future<void> _installUpdate() async {
    final update = _newest;
    if (update == null || _installing) return;

    final installer = ref.read(appUpdateInstallerProvider);
    setState(() {
      _installing = true;
      _installError = null;
      _received = 0;
      _total = 0;
    });

    try {
      if (!await installer.canInstall()) {
        final opened = await installer.openInstallPermission();
        if (!mounted) return;
        setState(() {
          _installError = opened
              ? 'Allow OneBit to install apps, then tap Install update again.'
              : 'This device will not let OneBit install updates.';
        });
        return;
      }

      final file = await installer.download(
        update,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total;
          });
        },
      );

      if (file == null) {
        // A tag published without an attached APK: the browser is the only
        // honest route, and pretending otherwise would fail at the end.
        if (mounted) setState(() => _installing = false);
        await _openUpdate(update);
        return;
      }

      if (!mounted) return;
      await installer.install(file);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _installError = '$e');
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  void _announce(AppUpdateInfo update) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('OneBit ${update.version} is available.'),
          action: SnackBarAction(
            label: 'UPDATE',
            onPressed: () => _openUpdate(update),
          ),
        ),
      );
  }

  Future<void> _openUpdate(AppUpdateInfo update) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(update.releaseUrl),
        mode: LaunchMode.externalApplication,
      );
    } on Exception catch (e) {
      AppLogger.warning(
        'AppUpdate: could not open ${update.releaseUrl}: $e',
      );
    }
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the update page.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final autoUpdate = ref.watch(settingsAutoUpdateProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: AppTheme.bgBase,
        title: Text(
          'App update',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SettingsSection(
            title: 'AUTOMATIC',
            children: [
              SettingsToggle(
                icon: Icons.system_update,
                title: 'Auto-update',
                description:
                    'Look for new OneBit builds and tell me when one is '
                    'ready to install.',
                value: autoUpdate,
                onChanged: (value) {
                  ref.read(settingsAutoUpdateProvider.notifier).state = value;
                  ref
                      .read(settingsRepositoryProvider)
                      .setAutoUpdateEnabled(value);
                },
              ),
            ],
          ),
          SettingsSection(
            title: 'VERSION',
            children: [
              SettingsTile(
                icon: Icons.smartphone,
                title: 'Current version',
                value: 'v${AppVersion.current}',
              ),
              SettingsTile(
                icon: Icons.update,
                title: 'Check for updates',
                value: _checking ? 'Checking…' : null,
                onTap: _checking ? null : _checkForUpdates,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
            child: _StatusMessage(
              checking: _checking,
              checked: _checked,
              error: _error,
              updates: _updates,
              installing: _installing,
              received: _received,
              total: _total,
              installError: _installError,
              onInstall: _installUpdate,
              onOpen: _openUpdate,
            ),
          ),
        ],
      ),
    );
  }
}

/// The result of the last update check, shown under the version section.
class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.checking,
    required this.checked,
    required this.error,
    required this.updates,
    required this.installing,
    required this.received,
    required this.total,
    required this.installError,
    required this.onInstall,
    required this.onOpen,
  });

  final bool checking;
  final bool checked;
  final String? error;
  final List<AppUpdateInfo>? updates;
  final bool installing;
  final int received;
  final int total;
  final String? installError;
  final VoidCallback onInstall;
  final ValueChanged<AppUpdateInfo> onOpen;

  AppUpdateInfo? get _newest {
    final available = updates ?? const <AppUpdateInfo>[];
    return available.isEmpty ? null : available.first;
  }

  @override
  Widget build(BuildContext context) {
    final body = _body();
    if (body == null && installError == null) return const SizedBox.shrink();
    final newest = _newest;

    return Column(
      children: [
        if (body != null)
          Text(
            body,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        if (installError != null) ...[
          const SizedBox(height: 8),
          Text(
            installError!,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
        if (installing) ...[
          const SizedBox(height: 12),
          _DownloadProgress(received: received, total: total),
        ] else if (newest != null) ...[
          if (newest.apkUrl != null) ...[
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onInstall,
              child: const Text('INSTALL UPDATE'),
            ),
          ],
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => onOpen(newest),
            child: const Text('UPDATE NOW'),
          ),
        ],
      ],
    );
  }

  String? _body() {
    if (checking) return 'Checking for updates…';
    if (error != null) return error;

    final newest = _newest;
    if (newest == null) {
      if (!checked) return null;
      return 'You are running the latest version.';
    }

    final available = updates ?? const <AppUpdateInfo>[];
    final message = StringBuffer('OneBit ${newest.version} is available.');
    if (available.length > 1) {
      message.write(' ${available.length} updates waiting.');
    }
    return message.toString();
  }
}

/// Download progress, falling back to a byte count when the release did not
/// declare a length — GitHub streams from its object store, and the length
/// is not always there to be had.
class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.received, required this.total});

  final int received;
  final int total;

  @override
  Widget build(BuildContext context) {
    final label = total > 0
        ? '${(received / total * 100).clamp(0, 100).toStringAsFixed(0)}%'
        : '${(received / 1024).toStringAsFixed(0)} KB';

    return Column(
      children: [
        // Only drawn when the length is known: an indeterminate bar is a
        // perpetual animation, and every test that reaches this state would
        // then hang on pumpAndSettle waiting for it to stop.
        if (total > 0)
          LinearProgressIndicator(value: (received / total).clamp(0.0, 1.0)),
        const SizedBox(height: 6),
        Text(
          'Downloading… $label',
          style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
        ),
      ],
    );
  }
}
