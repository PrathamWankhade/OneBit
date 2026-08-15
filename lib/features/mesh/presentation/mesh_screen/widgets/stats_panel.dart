import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/features/mesh/domain/mesh_statistics.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/features/mesh/presentation/mesh_screen/widgets/network_health_panel.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Statistics panel showing mesh packet statistics.
final class StatsPanel extends ConsumerWidget {
  const StatsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final statsAsync = ref.watch(meshStatisticsProvider);

    return statsAsync.when(
      loading: () => const OneBitCard(child: OneBitLoadingIndicator(label: '')),
      error: (e, _) => OneBitCard(
        child: Text(l10n.commonError, style: context.textTheme.bodyMedium),
      ),
      data: (result) {
        if (result.isErr || result.value == null) {
          return const SizedBox.shrink();
        }
        return StatsCard(stats: result.value!);
      },
    );
  }
}

/// Displays mesh statistics.
final class StatsCard extends StatelessWidget {
  const StatsCard({required this.stats, super.key});

  final MeshStatistics stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return OneBitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.meshStatsTitle, style: context.textTheme.titleMedium),
          const SizedBox(height: OneBitSpacing.m),
          HealthRow(label: l10n.meshPacketSeen, value: '${stats.packetsSeen}'),
          HealthRow(
            label: l10n.meshPacketForwarded,
            value: '${stats.packetsForwarded}',
          ),
          HealthRow(
            label: l10n.meshPacketDeliveredUp,
            value: '${stats.packetsDeliveredUp}',
          ),
          HealthRow(label: l10n.meshPacketDrops, value: '${stats.totalDrops}'),
          HealthRow(
            label: l10n.meshPacketDuplicates,
            value: '${stats.duplicatesDropped}',
          ),
          if (stats.packetSuccessRate != null)
            HealthRow(
              label: l10n.meshPacketSuccessRate,
              value: '${(stats.packetSuccessRate! * 100).round()}%',
            ),
          const SizedBox(height: OneBitSpacing.s),
          Text(
            l10n.meshDuplicateCache,
            style: context.textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: OneBitSpacing.xs),
          HealthRow(
            label: l10n.meshDuplicateCacheCapacity,
            value: '${stats.duplicateCacheCapacity}',
          ),
          HealthRow(
            label: l10n.meshDuplicateCacheEntries,
            value: '${stats.duplicateCacheSize}',
          ),
          HealthRow(
            label: l10n.meshDuplicateCacheHits,
            value: '${stats.duplicateCacheHits}',
          ),
          HealthRow(
            label: l10n.meshDuplicateCacheEvictions,
            value: '${stats.duplicateCacheEvictions}',
          ),
        ],
      ),
    );
  }
}
