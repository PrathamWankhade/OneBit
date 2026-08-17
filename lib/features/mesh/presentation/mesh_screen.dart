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
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_page_header.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/responsive/onebit_responsive.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';

/// Mesh overview tab: network health, topology visualization, active nodes,
/// routes, and statistics — all wired to the live mesh engine providers.
class MeshScreen extends ConsumerWidget {
  const MeshScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stateAsync = ref.watch(meshStateProvider);

    return OneBitScaffold(
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
    final colors = context.oneBitColors;
    return context.isTablet
        ? _TabletMeshLayout(engineState: engineState)
        : Column(
            children: [
              OneBitPageHeader.status(
                title: context.l10n.meshTitle,
                status: engineState.name,
                statusColor: switch (engineState) {
                  MeshEngineState.running => colors.success,
                  MeshEngineState.starting => colors.warning,
                  MeshEngineState.degraded => colors.warning,
                  MeshEngineState.stopped => colors.textMuted,
                },
                actions: [
                  OneBitIconButton(
                    icon: OneBitIcons.shellSettings,
                    tooltip: context.l10n.settingsTitle,
                    onPressed: () => context.go(AppRoutePaths.meshSettings),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    OneBitSpacing.lg,
                    OneBitSpacing.sm,
                    OneBitSpacing.lg,
                    OneBitScrollClearance.bottom(context),
                  ),
                  children: [
                    _EnginePanel(engineState: engineState),
                    const SizedBox(height: OneBitSpacing.md),
                    const NetworkHealthPanel(),
                    const SizedBox(height: OneBitSpacing.md),
                    const TopologyVisualizationPanel(),
                    const SizedBox(height: OneBitSpacing.md),
                    const ActiveNodesPanel(),
                    const SizedBox(height: OneBitSpacing.md),
                    const RoutesPanel(),
                    const SizedBox(height: OneBitSpacing.md),
                    const StatsPanel(),
                  ],
                ),
              ),
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
          OneBitButton(
            label: engineState == MeshEngineState.stopped
                ? l10n.meshEngineStart
                : l10n.meshEngineStop,
            variant: OneBitButtonVariant.tonal,
            onPressed: engineState == MeshEngineState.stopped
                ? () =>
                      ref.read(meshLifecycleControllerProvider.notifier).start()
                : engineState == MeshEngineState.running
                ? () =>
                      ref.read(meshLifecycleControllerProvider.notifier).stop()
                : null,
          ),
        ],
      ),
    );
  }
}

/// Tablet-optimized mesh layout with summary + topology side-by-side.
class _TabletMeshLayout extends StatelessWidget {
  const _TabletMeshLayout({required this.engineState});

  final MeshEngineState engineState;

  @override
  Widget build(BuildContext context) {
    final colors = context.oneBitColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OneBitSpacing.lg,
        0,
        OneBitSpacing.lg,
        0,
      ),
      child: Column(
        children: [
          OneBitPageHeader.status(
            title: context.l10n.meshTitle,
            status: engineState.name,
            statusColor: switch (engineState) {
              MeshEngineState.running => colors.success,
              MeshEngineState.starting => colors.warning,
              MeshEngineState.degraded => colors.warning,
              MeshEngineState.stopped => colors.textMuted,
            },
            actions: [
              OneBitIconButton(
                icon: OneBitIcons.shellSettings,
                tooltip: context.l10n.settingsTitle,
                onPressed: () => context.go(AppRoutePaths.meshSettings),
              ),
            ],
          ),
          const SizedBox(height: OneBitSpacing.md),
          _EnginePanel(engineState: engineState),
          const SizedBox(height: OneBitSpacing.md),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      0,
                      0,
                      OneBitScrollClearance.bottom(context),
                    ),
                    children: const [
                      NetworkHealthPanel(),
                      SizedBox(height: OneBitSpacing.md),
                      StatsPanel(),
                    ],
                  ),
                ),
                const SizedBox(width: OneBitSpacing.md),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      0,
                      0,
                      OneBitScrollClearance.bottom(context),
                    ),
                    children: const [
                      TopologyVisualizationPanel(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: OneBitSpacing.md),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: ActiveNodesPanel()),
              SizedBox(width: OneBitSpacing.md),
              Expanded(child: RoutesPanel()),
            ],
          ),
          const SizedBox(height: OneBitSpacing.xxxl),
        ],
      ),
    );
  }
}
