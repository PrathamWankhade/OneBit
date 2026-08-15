import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/dtn/dtn_providers.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/features/packet/presentation/packet_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_diagnostic_card.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Statistics screen: displays packet, mesh, DTN and storage counters.
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.statsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(OneBitSpacing.m),
        children: [
          const _PacketStats(),
          const SizedBox(height: OneBitSpacing.m),
          const _MeshStats(),
          const SizedBox(height: OneBitSpacing.m),
          const _DtnStats(),
          const SizedBox(height: OneBitSpacing.m),
          const _StorageStats(),
        ],
      ),
    );
  }
}

class _PacketStats extends ConsumerWidget {
  const _PacketStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final statsAsync = ref.watch(packetStatisticsProvider);

    return statsAsync.when(
      data: (stats) {
        return OneBitDiagnosticCard(
          title: l10n.statsPacketSection,
          rows: [
            MapEntry(l10n.statsPacketsCreated, '${stats.packetsCreated}'),
            MapEntry(l10n.statsPacketsSent, '${stats.packetsSent}'),
            MapEntry(l10n.statsPacketsDelivered, '${stats.packetsDelivered}'),
            MapEntry(l10n.statsPacketsRejected, '${stats.packetsRejected}'),
            MapEntry(l10n.statsBytesSent, '${stats.bytesSent}'),
            MapEntry(l10n.statsFragmentsAccepted, '${stats.fragmentsAccepted}'),
            MapEntry(
              l10n.statsFragmentsCompleted,
              '${stats.fragmentsCompleted}',
            ),
            MapEntry(l10n.statsFragmentsExpired, '${stats.fragmentsExpired}'),
            MapEntry(l10n.statsActiveAssemblies, '${stats.activeAssemblies}'),
          ],
        );
      },
      loading: () => OneBitCard(
        child: Text(
          l10n.statsPacketSection,
          style: context.textTheme.titleMedium,
        ),
      ),
      error: (_, _) => OneBitCard(
        child: Text(
          l10n.statsPacketSection,
          style: context.textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _MeshStats extends ConsumerWidget {
  const _MeshStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final statsAsync = ref.watch(meshStatisticsProvider);

    return statsAsync.when(
      data: (result) {
        final stats = result.value;
        if (stats == null) {
          return OneBitCard(
            child: Text(
              l10n.statsMeshSection,
              style: context.textTheme.titleMedium,
            ),
          );
        }
        return OneBitDiagnosticCard(
          title: l10n.statsMeshSection,
          rows: [
            MapEntry(l10n.statsMeshPacketsSeen, '${stats.packetsSeen}'),
            MapEntry(
              l10n.statsMeshPacketsForwarded,
              '${stats.packetsForwarded}',
            ),
            MapEntry(
              l10n.statsMeshPacketsDeliveredUp,
              '${stats.packetsDeliveredUp}',
            ),
            MapEntry(l10n.statsMeshDrops, '${stats.totalDrops}'),
            MapEntry(l10n.statsMeshDuplicates, '${stats.duplicatesDropped}'),
            MapEntry(
              l10n.statsMeshPacketSuccessRate,
              '${((stats.packetSuccessRate ?? 0) * 100).toStringAsFixed(1)}%',
            ),
            MapEntry(
              l10n.statsMeshRoutesLearned,
              '${stats.routeDiscoveriesLearned}',
            ),
            MapEntry(l10n.statsMeshRouteSwitches, '${stats.routeSwitches}'),
          ],
        );
      },
      loading: () => OneBitCard(
        child: Text(
          l10n.statsMeshSection,
          style: context.textTheme.titleMedium,
        ),
      ),
      error: (_, _) => OneBitCard(
        child: Text(
          l10n.statsMeshSection,
          style: context.textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _DtnStats extends ConsumerWidget {
  const _DtnStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final statsAsync = ref.watch(dtnStatisticsSnapshotProvider);

    return statsAsync.when(
      data: (stats) {
        return OneBitDiagnosticCard(
          title: l10n.statsDtnSection,
          rows: [
            MapEntry(l10n.statsDtnStored, '${stats.stored}'),
            MapEntry(l10n.statsDtnDelivered, '${stats.delivered}'),
            MapEntry(l10n.statsDtnAcknowledged, '${stats.acknowledged}'),
            MapEntry(l10n.statsDtnExpired, '${stats.expired}'),
            MapEntry(l10n.statsDtnRetried, '${stats.retried}'),
            MapEntry(l10n.statsDtnRelayed, '${stats.relayed}'),
            MapEntry(l10n.statsDtnParked, '${stats.parked}'),
            MapEntry(
              l10n.statsDtnAvgLatency,
              '${(stats.avgDeliveryLatency ?? 0).toStringAsFixed(1)}s',
            ),
          ],
        );
      },
      loading: () => OneBitCard(
        child: Text(l10n.statsDtnSection, style: context.textTheme.titleMedium),
      ),
      error: (_, _) => OneBitCard(
        child: Text(l10n.statsDtnSection, style: context.textTheme.titleMedium),
      ),
    );
  }
}

class _StorageStats extends StatelessWidget {
  const _StorageStats();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return OneBitDiagnosticCard(
      title: l10n.statsStorageSection,
      rows: [
        MapEntry(l10n.statsMessages, '-'),
        MapEntry(l10n.statsStorageRoot, '-'),
        MapEntry(l10n.statsStorageFree, '-'),
        MapEntry(l10n.statsStoragePayload, '-'),
        MapEntry(l10n.statsStorageTemp, '-'),
        MapEntry(l10n.statsStorageCache, '-'),
        MapEntry(l10n.statsStorageAttachments, '-'),
      ],
    );
  }
}
