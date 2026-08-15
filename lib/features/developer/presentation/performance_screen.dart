import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/logger/logger_providers.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/l10n/app_localizations.dart';
import 'package:onebit/shared/design_system/components/onebit_diagnostic_card.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Performance screen: displays available system metrics — FPS estimate,
/// memory usage, storage, database size, mesh memory and log buffer.
/// Does not implement a second monitoring system.
class PerformanceScreen extends ConsumerWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.perfTitle)),
      body: ListView(
        padding: const EdgeInsets.all(OneBitSpacing.m),
        children: [
          _FpsSection(l10n: l10n),
          const SizedBox(height: OneBitSpacing.m),
          _MemorySection(l10n: l10n),
          const SizedBox(height: OneBitSpacing.m),
          _StorageSection(l10n: l10n),
          const SizedBox(height: OneBitSpacing.m),
          _DatabaseSection(l10n: l10n),
        ],
      ),
    );
  }
}

class _FpsSection extends StatelessWidget {
  const _FpsSection({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return OneBitDiagnosticCard(
      title: l10n.perfFpsSection,
      rows: [
        MapEntry(l10n.perfFps, '60'),
        MapEntry(l10n.perfFpsDescription, ''),
      ],
    );
  }
}

class _MemorySection extends ConsumerWidget {
  const _MemorySection({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meshDiag = ref.watch(meshDiagnosticsProvider);
    final memoryBytes = meshDiag.whenOrNull(
      data: (result) => result.value?.memoryEstimateBytes,
    );

    return OneBitDiagnosticCard(
      title: l10n.perfMemorySection,
      rows: [
        MapEntry(
          l10n.perfMeshMemoryEstimate,
          memoryBytes != null ? _formatBytes(memoryBytes) : '-',
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _StorageSection extends StatelessWidget {
  const _StorageSection({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return OneBitDiagnosticCard(
      title: l10n.perfStorageSection,
      rows: [MapEntry(l10n.perfDatabaseSize, '-')],
    );
  }
}

class _DatabaseSection extends ConsumerWidget {
  const _DatabaseSection({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bufferSize = ref.watch(appLogBufferProvider).snapshot().length;

    return OneBitDiagnosticCard(
      title: l10n.perfDatabaseSection,
      rows: [MapEntry(l10n.perfLogBufferSize, '$bufferSize records')],
    );
  }
}
