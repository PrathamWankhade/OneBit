import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/dtn/dtn_providers.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_diagnostic_card.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Diagnostics screen: engine state, radio health, neighbor/route counts,
/// mesh memory, uptime, connection quality and diagnostic probes.
class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.devDiagnosticsTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          OneBitSpacing.m,
          OneBitSpacing.m,
          OneBitSpacing.m,
          OneBitScrollClearance.bottom(context),
        ),
        children: [
          const _EngineDiagnostics(),
          const SizedBox(height: OneBitSpacing.m),
          const _MeshDiagnostics(),
          const SizedBox(height: OneBitSpacing.m),
          const _DtnDiagnostics(),
        ],
      ),
    );
  }
}

class _EngineDiagnostics extends ConsumerWidget {
  const _EngineDiagnostics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stateAsync = ref.watch(meshStateProvider);
    final statusAsync = ref.watch(meshNetworkStatusProvider);

    final engineState = stateAsync.whenOrNull(data: (result) => result.value);
    final status = statusAsync.whenOrNull(data: (result) => result.value);

    return OneBitDiagnosticCard(
      title: l10n.diagEngineState,
      rows: [
        MapEntry(
          l10n.diagEngineState,
          engineState?.name ?? MeshEngineState.stopped.name,
        ),
        MapEntry(
          l10n.diagActiveNeighbors,
          '${status?.activeNeighborCount ?? 0}',
        ),
        MapEntry(l10n.diagKnownNodes, '${status?.knownNodeCount ?? 0}'),
        MapEntry(
          l10n.diagConnectionQuality,
          status != null
              ? '${(status.connectionQuality * 100).toStringAsFixed(1)}%'
              : '-',
        ),
        MapEntry(
          l10n.diagMeshStability,
          status != null
              ? '${(status.meshStability * 100).toStringAsFixed(1)}%'
              : '-',
        ),
        MapEntry(
          l10n.diagPacketsPerMinute,
          '${status?.relayedPacketsPerMinute ?? 0}',
        ),
      ],
    );
  }
}

class _MeshDiagnostics extends ConsumerWidget {
  const _MeshDiagnostics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final diagAsync = ref.watch(meshDiagnosticsProvider);

    return diagAsync.when(
      data: (result) {
        final diag = result.value;
        if (diag == null) {
          return OneBitCard(
            child: Text(
              l10n.devDiagnosticsTitle,
              style: context.textTheme.titleMedium,
            ),
          );
        }
        return OneBitDiagnosticCard(
          title: l10n.devDiagnosticsTitle,
          rows: [
            MapEntry(l10n.diagEngineState, diag.engineState.name),
            MapEntry(l10n.diagRadioState, diag.radioState.name),
            MapEntry(
              l10n.diagMemoryEstimate,
              _formatBytes(diag.memoryEstimateBytes),
            ),
            MapEntry(l10n.diagRoutes, '${diag.routeSummary.length} routes'),
          ],
        );
      },
      loading: () => const Center(child: OneBitLoadingIndicator()),
      error: (_, _) => OneBitCard(
        child: Text(
          l10n.devDiagnosticsTitle,
          style: context.textTheme.titleMedium,
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _DtnDiagnostics extends ConsumerWidget {
  const _DtnDiagnostics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final queueAsync = ref.watch(dtnQueueSnapshotProvider);

    return queueAsync.when(
      data: (queue) {
        return OneBitDiagnosticCard(
          title: l10n.diagDtnQueueDepth,
          rows: [
            MapEntry(
              l10n.diagDtnQueueDepth,
              '${queue.outgoing + queue.deferred + queue.retry + queue.incoming + queue.relaying}',
            ),
          ],
        );
      },
      loading: () => OneBitCard(
        child: Text(
          l10n.diagDtnQueueDepth,
          style: context.textTheme.titleMedium,
        ),
      ),
      error: (_, _) => OneBitCard(
        child: Text(
          l10n.diagDtnQueueDepth,
          style: context.textTheme.titleMedium,
        ),
      ),
    );
  }
}
