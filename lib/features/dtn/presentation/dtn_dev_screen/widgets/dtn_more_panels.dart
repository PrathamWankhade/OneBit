import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/dtn/delivery/simulated_mesh_gateway.dart';
import 'package:onebit/features/dtn/domain/dtn_statistics.dart';
import 'package:onebit/features/dtn/dtn_providers.dart';
import 'package:onebit/features/dtn/presentation/dtn_dev_screen/widgets/dtn_panels.dart';
import 'package:onebit/features/dtn/queue/queue_manager.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';

/// Connectivity gate + simulated mesh toggle.
final class ConnectivityPanel extends ConsumerWidget {
  const ConnectivityPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(dtnEngineProvider);
    final snapshot = engine.connectivity;
    final gateway = ref.watch(dtnGatewayProvider);
    final reachable = snapshot.reachable;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connectivity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  reachable ? Icons.wifi : Icons.wifi_off,
                  color: reachable
                      ? context.oneBitColors.success
                      : context.oneBitColors.statusDotError,
                ),
                const SizedBox(width: 8),
                Text('${snapshot.linkName}: ${snapshot.toString()}'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Transmitted by gateway: '
              '${gateway is SimulatedMeshGateway ? gateway.transmittedCount : 0}',
            ),
            if (gateway is SimulatedMeshGateway)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Simulated mesh reachable'),
                subtitle: const Text(
                  'When off, the engine parks envelopes instead of transmitting',
                ),
                value: reachable,
                onChanged: (value) {
                  gateway.reachable = value;
                  ref
                      .read(dtnEngineProvider)
                      .setConnectivity(gateway.connectivity());
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Delivery behaviour info.
final class AckPanel extends ConsumerWidget {
  const AckPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Behaviour', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Delivery triggers: store(), connectivity change, ACK, '
              'topology change, retry windows, and a 5 s floor tick.\n'
              'Critical envelopes are never parked by the connectivity gate.\n'
              'Envelopes expire by TTL even while offline.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Forwarding statistics: relayed/forwarded counters.
final class ForwardingPanel extends ConsumerWidget {
  const ForwardingPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats =
        ref.watch(dtnStatisticsSnapshotProvider).value ??
        DtnStatisticsSnapshot.empty;
    final engine = ref.watch(dtnEngineProvider);
    final relaying = QueueManager(engine.storeForward).relaying;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Forwarding / relay',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('relayed ${stats.relayed} · relaying now ${relaying.length}'),
            if (relaying.isNotEmpty)
              for (final p in relaying.take(5))
                Text(
                  '  ${p.packetId} → ${p.destination} (hop ${p.hopCount})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
          ],
        ),
      ),
    );
  }
}

/// ACK monitor: envelopes waiting for their logical acknowledgment.
final class AckMonitorPanel extends ConsumerWidget {
  const AckMonitorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(dtnEngineProvider);
    final awaiting = QueueManager(engine.storeForward).awaitingAck;
    final stats =
        ref.watch(dtnStatisticsSnapshotProvider).value ??
        DtnStatisticsSnapshot.empty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ACK monitor', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'acked ${stats.acknowledged} · deduplicated '
              '${stats.deduplicated} · awaiting ${awaiting.length}',
            ),
            if (awaiting.isEmpty)
              const Text('(no envelopes awaiting ack)')
            else
              for (final p in awaiting.take(6))
                Text(
                  '  ${p.packetId} deadline '
                  '${devTime(p.ackDeadlineAt ?? p.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
          ],
        ),
      ),
    );
  }
}

/// Packet lifetime / delivery timeline: per-envelope traceability.
final class LifetimePanel extends ConsumerWidget {
  const LifetimePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(dtnEngineProvider);
    final byAge = QueueManager(engine.storeForward).byPriority.take(8).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Packet lifetimes (oldest live first)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (byAge.isEmpty)
              const Text('(no live envelopes)')
            else
              for (final p in byAge)
                Text(
                  '${p.packetId} [${p.priority.name}] created '
                  '${devTime(p.createdAt)} · expires '
                  '${devTime(p.expiresAt)} · ${p.state.name}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
          ],
        ),
      ),
    );
  }
}
