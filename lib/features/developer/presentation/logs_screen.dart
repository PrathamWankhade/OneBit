import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/logger/log_level.dart';
import 'package:onebit/core/logger/log_record.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/logger/logger_providers.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/shared/design_system/colors/onebit_color_schemes.dart';
import 'package:onebit/shared/design_system/components/onebit_snackbar.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Log viewer: displays the in-memory ring buffer with search, level filter,
/// subsystem filter, and copy support. Auto-refreshes every second.
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

final class _LogsScreenState extends ConsumerState<LogsScreen> {
  Timer? _timer;
  List<LogRecord> _records = const [];
  String _searchQuery = '';
  LogLevel? _filterLevel;
  String? _filterSubsystem;
  bool _autoRefresh = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _refreshLogs();
    });
  }

  void _refreshLogs() {
    final buffer = ref.read(appLogBufferProvider);
    var records = buffer.snapshot().reversed.toList();

    if (_filterLevel != null) {
      records = records
          .where((r) => r.level.index >= _filterLevel!.index)
          .toList();
    }

    if (_filterSubsystem != null) {
      final tag = _subsystemTag(_filterSubsystem!);
      records = records.where((r) => r.tag == tag).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      records = records
          .where((r) => r.message.toLowerCase().contains(query))
          .toList();
    }

    setState(() => _records = records);
  }

  String? _subsystemTag(String subsystem) => switch (subsystem) {
    'BLE' => LogTags.mesh,
    'MESH' => LogTags.mesh,
    'DTN' => LogTags.dtn,
    'PACKET' => LogTags.packet,
    'IDENTITY' => LogTags.identity,
    'MEDIA' => LogTags.media,
    _ => null,
  };

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return OneBitScaffold(
      appBar: AppBar(
        title: Text(l10n.logsTitle),
        actions: [
          IconButton(
            icon: const Icon(OneBitIcons.delete),
            tooltip: l10n.commonClear,
            onPressed: _clearLogs,
          ),
          IconButton(
            icon: Icon(_autoRefresh ? OneBitIcons.pause : OneBitIcons.play),
            tooltip: l10n.logsAutoRefresh,
            onPressed: () {
              setState(() => _autoRefresh = !_autoRefresh);
              if (_autoRefresh) {
                _startTimer();
              } else {
                _timer?.cancel();
              }
            },
          ),
          IconButton(
            icon: const Icon(OneBitIcons.copy),
            tooltip: l10n.logsCopy,
            onPressed: _copyLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(OneBitSpacing.m),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: l10n.logsSearchHint,
                    prefixIcon: const Icon(OneBitIcons.search),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _searchQuery = value;
                    _refreshLogs();
                  },
                ),
                const SizedBox(height: OneBitSpacing.s),
                _LevelFilter(
                  selected: _filterLevel,
                  onSelected: (level) {
                    setState(() => _filterLevel = level);
                    _refreshLogs();
                  },
                ),
                const SizedBox(height: OneBitSpacing.s),
                _SubsystemFilter(
                  selected: _filterSubsystem,
                  onSelected: (subsystem) {
                    setState(() => _filterSubsystem = subsystem);
                    _refreshLogs();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _records.isEmpty
                ? Center(
                    child: Text(
                      l10n.logsEmpty,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(OneBitSpacing.s),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return _LogRow(record: record);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _clearLogs() {
    ref.read(appLogBufferProvider).clear();
    _refreshLogs();
  }

  void _copyLogs() {
    final text = _records.map((r) => r.toLine()).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    OneBitSnackBars.success(context, message: context.l10n.logsCopied);
  }
}

class _LevelFilter extends StatelessWidget {
  const _LevelFilter({required this.selected, required this.onSelected});

  final LogLevel? selected;
  final ValueChanged<LogLevel?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<LogLevel?>(
      segments: [
        ButtonSegment(value: null, label: Text(l10n.logsAllLevels)),
        ...LogLevel.values.map(
          (level) => ButtonSegment(
            value: level,
            label: Text(level.name.toUpperCase()),
          ),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (selection) => onSelected(selection.first),
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _SubsystemFilter extends StatelessWidget {
  const _SubsystemFilter({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  static const List<String> _subsystems = [
    'ALL',
    'BLE',
    'MESH',
    'DTN',
    'PACKET',
    'IDENTITY',
    'MEDIA',
  ];

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: [
        for (final s in _subsystems) ButtonSegment(value: s, label: Text(s)),
      ],
      selected: {selected ?? 'ALL'},
      onSelectionChanged: (selection) {
        final value = selection.first;
        onSelected(value == 'ALL' ? null : value);
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.record});

  final LogRecord record;

  @override
  Widget build(BuildContext context) {
    final colors = context.oneBitColors;
    final levelColor = switch (record.level) {
      LogLevel.trace || LogLevel.debug => colors.textMuted,
      LogLevel.info => colors.textPrimary,
      LogLevel.warning => colors.warning,
      LogLevel.error || LogLevel.fatal => colors.ansiRed,
    };

    final tagPrefix = _tagPrefix(record.tag);
    final tagColor = _tagColor(record.tag, colors);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tagPrefix != null) ...[
            Text(
              '[$tagPrefix]',
              style: OneBitTypography.technicalStyle(
                fontSize: OneBitTypography.technical,
                color: tagColor,
                weight: OneBitTypography.semibold,
              ),
            ),
            const SizedBox(width: OneBitSpacing.s),
          ],
          Expanded(
            child: Text(
              _formatMessage(record),
              style: OneBitTypography.technicalStyle(
                fontSize: OneBitTypography.technical,
                color: levelColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessage(LogRecord record) {
    final timestamp = record.time;
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms ${record.level.label} ${record.message}';
  }

  String? _tagPrefix(String? tag) {
    if (tag == null) return null;
    if (tag.startsWith('ble') || tag == 'bluetooth') return 'BLE';
    if (tag.startsWith('mesh')) return 'MESH';
    if (tag.startsWith('dtn')) return 'DTN';
    if (tag.startsWith('packet')) return 'PKT';
    if (tag.startsWith('identity')) return 'ID';
    if (tag.startsWith('media')) return 'MEDIA';
    return tag.toUpperCase();
  }

  Color _tagColor(String? tag, OneBitThemeExtension colors) {
    if (tag == null) return colors.textMuted;
    if (tag.startsWith('ble') || tag == 'bluetooth') return colors.info;
    if (tag.startsWith('mesh')) return colors.success;
    if (tag.startsWith('dtn')) return colors.pending;
    if (tag.startsWith('packet')) return colors.ansiCyan;
    if (tag.startsWith('identity')) return colors.identity;
    if (tag.startsWith('media')) return colors.relay;
    return colors.textMuted;
  }
}
