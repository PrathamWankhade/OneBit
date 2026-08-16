import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/features/mesh/domain/mesh_statistics.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_metric_row.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';

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

/// Displays mesh statistics grouped into packet and cache sections.
final class StatsCard extends StatelessWidget {
  const StatsCard({required this.stats, super.key});

  final MeshStatistics stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.oneBitColors;

    return OneBitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.meshStatsTitle, style: context.textTheme.titleMedium),
          const SizedBox(height: OneBitSpacing.s),
          OneBitMetricRow(label: l10n.meshPacketSeen, value: '${stats.packetsSeen}', dense: true),
          OneBitMetricRow(
            label: l10n.meshPacketForwarded,
            value: '${stats.packetsForwarded}',
            dense: true,
          ),
          OneBitMetricRow(
            label: l10n.meshPacketDeliveredUp,
            value: '${stats.packetsDeliveredUp}',
            dense: true,
          ),
          OneBitMetricRow(label: l10n.meshPacketDrops, value: '${stats.totalDrops}', dense: true),
          OneBitMetricRow(
            label: l10n.meshPacketDuplicates,
            value: '${stats.duplicatesDropped}',
            dense: true,
          ),
          if (stats.packetSuccessRate != null)
            OneBitMetricRow(
              label: l10n.meshPacketSuccessRate,
              value: '${(stats.packetSuccessRate! * 100).round()}%',
              dense: true,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: OneBitSpacing.sm),
            child: Divider(
              height: 1,
              color: colors.border,
            ),
          ),
          Text(
            l10n.meshDuplicateCache,
            style: context.textTheme.titleSmall?.copyWith(
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: OneBitSpacing.xxs),
          OneBitMetricRow(
            label: l10n.meshDuplicateCacheCapacity,
            value: '${stats.duplicateCacheCapacity}',
            dense: true,
          ),
          OneBitMetricRow(
            label: l10n.meshDuplicateCacheEntries,
            value: '${stats.duplicateCacheSize}',
            dense: true,
          ),
          OneBitMetricRow(
            label: l10n.meshDuplicateCacheHits,
            value: '${stats.duplicateCacheHits}',
            dense: true,
          ),
          OneBitMetricRow(
            label: l10n.meshDuplicateCacheEvictions,
            value: '${stats.duplicateCacheEvictions}',
            dense: true,
          ),
        ],
      ),
    );
  }
}
