import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';

/// Section wrapper card.
final class Section extends StatelessWidget {
  const Section({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// Network health panel.
final class HealthPanel extends ConsumerWidget {
  const HealthPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(meshNetworkStatusProvider).value;
    final status = result?.value;
    final stats = ref.watch(meshStatisticsProvider).value?.value;
    return Section(
      title: 'Network health',
      child: status == null
          ? const Text('Waiting for first snapshot…')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _healthRow('Active neighbors', '${status.activeNeighborCount}'),
                _healthRow('Partitions', '${status.partitionCount}'),
                _healthRow(
                  'Stability',
                  '${(status.meshStability * 100).round()}%',
                ),
                _healthRow(
                  'Relayed / min',
                  '${status.relayedPacketsPerMinute}',
                ),
                if (status.packetSuccessRate != null)
                  _healthRow(
                    'Packet success',
                    '${(status.packetSuccessRate! * 100).round()}%',
                  ),
                if (stats != null)
                  _healthRow(
                    'Drops',
                    '${stats.totalDrops} '
                        '(seen ${stats.packetsSeen}, '
                        'fwd ${stats.packetsForwarded})',
                  ),
              ],
            ),
    );
  }

  Widget _healthRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value)],
      ),
    );
  }
}

/// Topology panel.
final class TopologyPanel extends ConsumerWidget {
  const TopologyPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(meshTopologyProvider).value;
    final topology = result?.value;
    return Section(
      title: 'Topology',
      child: topology == null
          ? const Text('No topology yet.')
          : Text(
              '${topology.nodes.length} nodes, '
              '${topology.links.length} links, '
              '${topology.partitions} partitions\n'
              '${topology.nodes.map((n) => n.nodeId).join('  ·  ')}',
            ),
    );
  }
}

/// Relay log panel.
final class RelayLogPanel extends StatelessWidget {
  const RelayLogPanel({required this.events, super.key});

  final List<dynamic> events;

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'Relay log',
      child: events.isEmpty
          ? const Text('No relay activity yet.')
          : Column(
              children: [
                for (final event in events)
                  Text(
                    '${event.kind.name} '
                    '${event.source}→${event.destination} '
                    '(seq ${event.sequence}, hop ${event.hopCount}, '
                    'ttl ${event.ttl})'
                    '${event.nextHop == null ? '' : ' via ${event.nextHop}'}'
                    '${event.dropReason == null ? '' : ' [${event.dropReason}]'}',
                    style: const TextStyle(fontSize: 11),
                  ),
              ],
            ),
    );
  }
}

/// Diagnostics panel.
final class DiagnosticsPanel extends ConsumerWidget {
  const DiagnosticsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(meshDiagnosticsProvider).value;
    final diagnostics = result?.value;
    return Section(
      title: 'Diagnostics',
      child: diagnostics == null
          ? const Text('Waiting…')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in diagnostics.lines)
                  Text(line, style: const TextStyle(fontSize: 11)),
              ],
            ),
    );
  }
}
