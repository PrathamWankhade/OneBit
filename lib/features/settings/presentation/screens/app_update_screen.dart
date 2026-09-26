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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdates());
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
              const SettingsTile(
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
    required this.onOpen,
  });

  final bool checking;
  final bool checked;
  final String? error;
  final List<AppUpdateInfo>? updates;
  final ValueChanged<AppUpdateInfo> onOpen;

  @override
  Widget build(BuildContext context) {
    final body = _body();
    if (body == null) return const SizedBox.shrink();
    final newest = _newest;

    return Column(
      children: [
        Text(
          body,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        if (newest != null) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => onOpen(newest),
            child: const Text('UPDATE NOW'),
          ),
        ],
      ],
    );
  }

  AppUpdateInfo? get _newest {
    final available = updates ?? const <AppUpdateInfo>[];
    return available.isEmpty ? null : available.first;
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
