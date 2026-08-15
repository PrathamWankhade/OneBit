import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/features/mesh/domain/mesh_network_status.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

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
          return OneBitCard(
            child: Text(
              l10n.meshEmptyTopology,
              style: context.textTheme.bodyMedium,
            ),
          );
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
          const SizedBox(height: OneBitSpacing.m),
          HealthRow(
            label: l10n.meshNeighborsLabel,
            value: '${status.activeNeighborCount}',
          ),
          HealthRow(
            label: l10n.meshKnownNodesLabel,
            value: '${status.knownNodeCount}',
          ),
          HealthRow(
            label: l10n.meshPartitionsLabel,
            value: '${status.partitionCount}',
          ),
          HealthRow(
            label: l10n.meshQualityLabel,
            value: '${(status.connectionQuality * 100).round()}%',
          ),
          HealthRow(
            label: l10n.meshStabilityLabel,
            value: '${(status.meshStability * 100).round()}%',
          ),
          if (status.averageRssiDb != null)
            HealthRow(
              label: l10n.meshRssiTitle,
              value: '${status.averageRssiDb!.round()} dBm',
            ),
          if (status.averageHopCount != null)
            HealthRow(
              label: l10n.meshRouteHopCount,
              value: status.averageHopCount!.toStringAsFixed(1),
            ),
          HealthRow(
            label: l10n.meshRelayRateLabel,
            value:
                '${status.relayedPacketsPerMinute} ${l10n.meshPacketsPerMinute}',
          ),
          if (status.packetSuccessRate != null)
            HealthRow(
              label: l10n.meshPacketSuccessLabel,
              value: '${(status.packetSuccessRate! * 100).round()}%',
            ),
        ],
      ),
    );
  }
}

/// A single label/value row used across health and stats panels.
final class HealthRow extends StatelessWidget {
  const HealthRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OneBitSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: OneBitTypography.technicalStyle(color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}
