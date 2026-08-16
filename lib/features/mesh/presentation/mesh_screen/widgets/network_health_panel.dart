import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/features/mesh/domain/mesh_network_status.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_metric_row.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Network health overview panel.
final class NetworkHealthPanel extends ConsumerWidget {
  const NetworkHealthPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final healthAsync = ref.watch(meshNetworkStatusProvider);

    return healthAsync.when(
      loading: () => const OneBitCard(child: OneBitLoadingIndicator(label: '')),
      error: (e, _) => OneBitCard(
        child: Text(l10n.commonError, style: context.textTheme.bodyMedium),
      ),
        data: (result) {
          if (result.isErr || result.value == null) {
            return const SizedBox.shrink();
          }
          final status = result.value!;
          return NetworkHealthCard(status: status);
        },
    );
  }
}

/// Displays network health metrics.
final class NetworkHealthCard extends StatelessWidget {
  const NetworkHealthCard({required this.status, super.key});

  final MeshNetworkStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final qualityPreset = status.connectionQuality >= 0.7
        ? OneBitStatusPreset.online
        : status.connectionQuality >= 0.4
        ? OneBitStatusPreset.pending
        : OneBitStatusPreset.offline;

    return OneBitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.meshNetworkHealthTitle,
                  style: context.textTheme.titleMedium,
                ),
              ),
              OneBitStatusChip.preset(qualityPreset),
            ],
          ),
          const SizedBox(height: OneBitSpacing.s),
          OneBitMetricRow(
            label: l10n.meshNeighborsLabel,
            value: '${status.activeNeighborCount}',
            dense: true,
          ),
          OneBitMetricRow(
            label: l10n.meshKnownNodesLabel,
            value: '${status.knownNodeCount}',
            dense: true,
          ),
          OneBitMetricRow(
            label: l10n.meshPartitionsLabel,
            value: '${status.partitionCount}',
            dense: true,
          ),
          const SizedBox(height: OneBitSpacing.xxs),
          OneBitMetricRow(
            label: l10n.meshQualityLabel,
            value: '${(status.connectionQuality * 100).round()}%',
            dense: true,
          ),
          OneBitMetricRow(
            label: l10n.meshStabilityLabel,
            value: '${(status.meshStability * 100).round()}%',
            dense: true,
          ),
          if (status.averageRssiDb != null)
            OneBitMetricRow(
              label: l10n.meshRssiTitle,
              value: '${status.averageRssiDb!.round()} dBm',
              dense: true,
            ),
          if (status.averageHopCount != null)
            OneBitMetricRow(
              label: l10n.meshRouteHopCount,
              value: status.averageHopCount!.toStringAsFixed(1),
              dense: true,
            ),
          const SizedBox(height: OneBitSpacing.xxs),
          OneBitMetricRow(
            label: l10n.meshRelayRateLabel,
            value:
                '${status.relayedPacketsPerMinute} ${l10n.meshPacketsPerMinute}',
            dense: true,
          ),
          if (status.packetSuccessRate != null)
            OneBitMetricRow(
              label: l10n.meshPacketSuccessLabel,
              value: '${(status.packetSuccessRate! * 100).round()}%',
              dense: true,
            ),
        ],
      ),
    );
  }
}
