import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_neighbor.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
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
          return const SizedBox.shrink();
        }
        final neighbors = result.value ?? [];
        if (neighbors.isEmpty) {
          return const SizedBox.shrink();
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
                style: OneBitTypography.oneBitNumeric(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: OneBitSpacing.xs),
          for (final neighbor in neighbors) ...[
            NodeRow(neighbor: neighbor),
            if (neighbor != neighbors.last)
              const SizedBox(height: OneBitSpacing.xxs),
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
                style: OneBitTypography.oneBitNumeric(color: scheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
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
          style: OneBitTypography.oneBitCaption(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
