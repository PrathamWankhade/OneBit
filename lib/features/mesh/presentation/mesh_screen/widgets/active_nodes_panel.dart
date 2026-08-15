import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_neighbor.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Active nodes panel showing discovered neighbors.
final class ActiveNodesPanel extends ConsumerWidget {
  const ActiveNodesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final neighborsAsync = ref.watch(meshNeighborsProvider);

    return neighborsAsync.when(
      loading: () => const OneBitCard(child: OneBitLoadingIndicator(label: '')),
      error: (e, _) => OneBitCard(
        child: Text(l10n.commonError, style: context.textTheme.bodyMedium),
      ),
      data: (result) {
        if (result.isErr) {
          return OneBitCard(
            child: Text(
              l10n.meshEmptyNodes,
              style: context.textTheme.bodyMedium,
            ),
          );
        }
        final neighbors = result.value ?? [];
        if (neighbors.isEmpty) {
          return OneBitCard(
            child: OneBitEmptyState(
              icon: OneBitIcons.node,
              title: l10n.meshEmptyNodes,
              message: l10n.meshEmptyNodesMessage,
            ),
          );
        }
        return ActiveNodesList(neighbors: neighbors);
      },
    );
  }
}

/// List of active neighbor nodes.
final class ActiveNodesList extends StatelessWidget {
  const ActiveNodesList({required this.neighbors, super.key});

  final List<MeshNeighbor> neighbors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return OneBitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.meshActiveNodesTitle,
                  style: context.textTheme.titleMedium,
                ),
              ),
              Text(
                '${neighbors.length}',
                style: OneBitTypography.technicalStyle(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: OneBitSpacing.s),
          for (final neighbor in neighbors) ...[
            NodeRow(neighbor: neighbor),
            if (neighbor != neighbors.last)
              const SizedBox(height: OneBitSpacing.s),
          ],
        ],
      ),
    );
  }
}

/// A single node row in the neighbor list.
final class NodeRow extends StatelessWidget {
  const NodeRow({required this.neighbor, super.key});

  final MeshNeighbor neighbor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final connectionPreset = switch (neighbor.connectionState) {
      MeshLinkState.connected => OneBitStatusPreset.online,
      MeshLinkState.advertising => OneBitStatusPreset.nearby,
      MeshLinkState.connecting => OneBitStatusPreset.pending,
      MeshLinkState.disconnecting => OneBitStatusPreset.pending,
      MeshLinkState.disconnected => OneBitStatusPreset.offline,
    };

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                neighbor.nodeId,
                style: OneBitTypography.technicalStyle(color: scheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${neighbor.hopEstimate} ${neighbor.hopEstimate == 1 ? 'hop' : 'hops'}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        OneBitStatusChip.preset(connectionPreset),
        const SizedBox(width: OneBitSpacing.s),
        Text(
          '${neighbor.smoothedRssiDb.round()} dBm',
          style: OneBitTypography.technicalStyle(
            fontSize: OneBitTypography.caption,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
