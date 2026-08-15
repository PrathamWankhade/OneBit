import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/dtn/domain/dtn_queue_snapshot.dart';
import 'package:onebit/features/dtn/domain/dtn_statistics.dart';
import 'package:onebit/features/dtn/dtn_providers.dart';
import 'package:onebit/features/dtn/queue/queue_manager.dart';

/// Queue depth panel.
final class QueuePanel extends ConsumerWidget {
  const QueuePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot =
        ref.watch(dtnQueueSnapshotProvider).value ?? DtnQueueSnapshot.empty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Queues', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _row(context, 'outgoing', snapshot.outgoing),
            _row(context, 'deferred (parked)', snapshot.deferred),
            _row(context, 'retrying', snapshot.retry),
            _row(context, 'incoming (at this node)', snapshot.incoming),
            _row(context, 'relaying', snapshot.relaying),
            _row(context, 'awaiting ack', snapshot.awaitingAck),
            const Divider(),
            _row(context, 'total live', snapshot.live, strong: true),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    int value, {
    bool strong = false,
  }) {
    final style = strong
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('$value', style: style),
        ],
      ),
    );
  }
}

/// Statistics panel.
final class StatisticsPanel extends ConsumerWidget {
  const StatisticsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats =
        ref.watch(dtnStatisticsSnapshotProvider).value ??
        DtnStatisticsSnapshot.empty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statistics', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'stored ${stats.stored} · delivered ${stats.delivered} · '
              'acked ${stats.acknowledged} · expired ${stats.expired}\n'
              'retried ${stats.retried} · relayed ${stats.relayed} · '
              'recovered ${stats.recovered} · parked ${stats.parked}\n'
              'deduplicated ${stats.deduplicated} · live ${stats.liveEnvelopes}',
            ),
            if (stats.avgDeliveryLatency != null)
              Text(
                'avg delivery latency '
                '${stats.avgDeliveryLatency!.toStringAsFixed(1)} s',
              ),
          ],
        ),
      ),
    );
  }
}

/// Retry queue panel.
final class RetryPanel extends ConsumerWidget {
  const RetryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(dtnEngineProvider);
    final retries = QueueManager(engine.storeForward).retrying;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Retry queue (${retries.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (retries.isEmpty)
              const Text('(no envelopes waiting on backoff)')
            else
              for (final p in retries.take(10))
                Text(
                  '${p.packetId} → ${p.destination} attempts=${p.attemptCount} '
                  'next=${devTime(p.nextAttemptAt ?? p.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
          ],
        ),
      ),
    );
  }
}

/// Diagnostics panel.
final class DiagnosticsPanel extends ConsumerWidget {
  const DiagnosticsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ring = ref.watch(dtnEngineProvider).diagnostics;
    final events = ring.events.take(12).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent diagnostics (${ring.total} total)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final event in events.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  '${devTime(event.when)} '
                  '${event.kind.name}'
                  '${event.packetId != null ? ' [${event.packetId}]' : ''}'
                  '${event.message != null ? ' — ${event.message}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact time formatting for dev logs.
String devTime(DateTime time) {
  final t = time.toIso8601String();
  return t.substring(11, 19);
}
