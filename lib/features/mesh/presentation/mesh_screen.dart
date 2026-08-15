import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/features/mesh/presentation/mesh_screen/widgets/active_nodes_panel.dart';
import 'package:onebit/features/mesh/presentation/mesh_screen/widgets/network_health_panel.dart';
import 'package:onebit/features/mesh/presentation/mesh_screen/widgets/routes_panel.dart';
import 'package:onebit/features/mesh/presentation/mesh_screen/widgets/stats_panel.dart';
import 'package:onebit/features/mesh/presentation/mesh_screen/widgets/topology_panel.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/responsive/onebit_master_detail.dart';
import 'package:onebit/shared/design_system/responsive/onebit_responsive.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Mesh overview tab: network health, topology visualization, active nodes,
/// routes, and statistics — all wired to the live mesh engine providers.
class MeshScreen extends ConsumerWidget {
  const MeshScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stateAsync = ref.watch(meshStateProvider);

    return OneBitScaffold(
      appBar: AppBar(
        title: Text(l10n.meshTitle),
        actions: [
          OneBitIconButton(
            icon: OneBitIcons.shellSettings,
            tooltip: l10n.settingsTitle,
            onPressed: () => context.push(AppRoutePaths.settings),
          ),
        ],
      ),
      body: stateAsync.when(
        loading: () => const OneBitLoadingIndicator(label: ''),
        error: (e, _) => OneBitErrorState(
          message: l10n.commonError,
          detail: e.toString(),
          retryLabel: l10n.commonRetry,
          onRetry: () => ref.invalidate(meshStateProvider),
        ),
        data: (result) {
          if (result.isErr) {
            return OneBitErrorState(
              message: l10n.commonError,
              detail: result.failure.toString(),
              retryLabel: l10n.commonRetry,
              onRetry: () => ref.invalidate(meshStateProvider),
            );
          }
          final engineState = result.value ?? MeshEngineState.stopped;
          return _MeshBody(engineState: engineState);
        },
      ),
    );
  }
}

class _MeshBody extends ConsumerWidget {
  const _MeshBody({required this.engineState});

  final MeshEngineState engineState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return context.isTablet
        ? _TabletMeshLayout(engineState: engineState)
        : ListView(
            padding: const EdgeInsets.all(OneBitSpacing.m),
            children: [
              _EnginePanel(engineState: engineState),
              const SizedBox(height: OneBitSpacing.m),
              const NetworkHealthPanel(),
              const SizedBox(height: OneBitSpacing.m),
              const TopologyVisualizationPanel(),
              const SizedBox(height: OneBitSpacing.m),
              const ActiveNodesPanel(),
              const SizedBox(height: OneBitSpacing.m),
              const RoutesPanel(),
              const SizedBox(height: OneBitSpacing.m),
              const StatsPanel(),
            ],
          );
  }
}

// ---------------------------------------------------------------------------
// Engine lifecycle
// ---------------------------------------------------------------------------

class _EnginePanel extends ConsumerWidget {
  const _EnginePanel({required this.engineState});

  final MeshEngineState engineState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    final preset = switch (engineState) {
      MeshEngineState.running => OneBitStatusPreset.online,
      MeshEngineState.starting => OneBitStatusPreset.pending,
      MeshEngineState.degraded => OneBitStatusPreset.pending,
      MeshEngineState.stopped => OneBitStatusPreset.offline,
    };

    return OneBitCard(
      semanticLabel: 'Mesh engine ${engineState.name}',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.meshEngineState,
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: OneBitSpacing.xs),
                OneBitStatusChip.preset(preset, label: engineState.name),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: engineState == MeshEngineState.stopped
                ? () =>
                      ref.read(meshLifecycleControllerProvider.notifier).start()
                : engineState == MeshEngineState.running
                ? () =>
                      ref.read(meshLifecycleControllerProvider.notifier).stop()
                : null,
            child: Text(
              engineState == MeshEngineState.stopped
                  ? l10n.meshEngineStart
                  : l10n.meshEngineStop,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tablet-optimized mesh layout with two-column grid.
class _TabletMeshLayout extends StatelessWidget {
  const _TabletMeshLayout({required this.engineState});

  final MeshEngineState engineState;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(OneBitSpacing.m),
      child: Column(
        children: [
          _EnginePanel(engineState: engineState),
          const SizedBox(height: OneBitSpacing.m),
          const Expanded(
            child: OneBitResponsiveGrid(
              compactColumns: 1,
              mediumColumns: 2,
              expandedColumns: 2,
              children: [
                NetworkHealthPanel(),
                TopologyVisualizationPanel(),
                ActiveNodesPanel(),
                RoutesPanel(),
                StatsPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
