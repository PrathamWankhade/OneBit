import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';
import 'package:onebit/features/dtn/domain/dtn_priority.dart';
import 'package:onebit/features/dtn/dtn_providers.dart';
import 'package:onebit/features/dtn/presentation/dtn_dev_screen/widgets/dtn_more_panels.dart';
import 'package:onebit/features/dtn/presentation/dtn_dev_screen/widgets/dtn_panels.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';

/// Developer dashboard for the DTN (store-and-forward) layer.
///
/// Not a product screen: it exercises envelope persistence, queueing,
/// delivery, retry and acknowledgements, and renders the streams the future
/// messaging UI will consume.
class DtnDevScreen extends ConsumerStatefulWidget {
  const DtnDevScreen({super.key});

  @override
  ConsumerState<DtnDevScreen> createState() => _DtnDevScreenState();
}

final class _DtnDevScreenState extends ConsumerState<DtnDevScreen> {
  final List<String> _eventLog = [];

  @override
  void initState() {
    super.initState();
    _subscribeEvents();
  }

  void _subscribeEvents() {
    final engine = ref.read(dtnEngineProvider);
    engine.statisticsSnapshots().listen((stats) {
      if (!mounted) return;
      final log = StringBuffer()
        ..write(
          'stats: delivered=${stats.delivered} '
          'stored=${stats.stored} expired=${stats.expired} '
          'retried=${stats.retried} parked=${stats.parked}',
        )
        ..write(' live=${stats.liveEnvelopes}');
      if (stats.avgDeliveryLatency != null) {
        log.write(' avgLat=${stats.avgDeliveryLatency!.toStringAsFixed(1)}s');
      }
      _pushLog(log.toString());
    });
  }

  void _pushLog(String entry) {
    if (!mounted) return;
    setState(() {
      _eventLog.insert(0, entry);
      if (_eventLog.length > 60) _eventLog.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return OneBitScaffold(
      appBar: AppBar(title: const Text('DTN Engine')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          OneBitScrollClearance.bottom(context),
        ),
        children: [
          const ConnectivityPanel(),
          const SizedBox(height: 12),
          const _StorePanel(),
          const SizedBox(height: 12),
          const AckPanel(),
          const SizedBox(height: 12),
          const QueuePanel(),
          const SizedBox(height: 12),
          const StatisticsPanel(),
          const SizedBox(height: 12),
          const RetryPanel(),
          const SizedBox(height: 12),
          const ForwardingPanel(),
          const SizedBox(height: 12),
          const AckMonitorPanel(),
          const SizedBox(height: 12),
          const LifetimePanel(),
          const SizedBox(height: 12),
          const DiagnosticsPanel(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event log',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_eventLog.isEmpty)
                    const Text('(no events yet)')
                  else
                    for (final entry in _eventLog)
                      Text(entry, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Create envelopes (store) and control acks.
final class _StorePanel extends ConsumerStatefulWidget {
  const _StorePanel();

  @override
  ConsumerState<_StorePanel> createState() => _StorePanelState();
}

final class _StorePanelState extends ConsumerState<_StorePanel> {
  final TextEditingController _id = TextEditingController();
  final TextEditingController _destination = TextEditingController();
  final TextEditingController _ttl = TextEditingController(text: '3600');
  DtnPriority _priority = DtnPriority.normal;

  @override
  void dispose() {
    _id.dispose();
    _destination.dispose();
    _ttl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Store a packet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _id,
              decoration: const InputDecoration(labelText: 'packet id'),
            ),
            TextField(
              controller: _destination,
              decoration: const InputDecoration(labelText: 'destination node'),
            ),
            TextField(
              controller: _ttl,
              decoration: const InputDecoration(labelText: 'ttl (seconds)'),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<DtnPriority>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'priority'),
              items: DtnPriority.values
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                  .toList(),
              onChanged: (p) =>
                  setState(() => _priority = p ?? DtnPriority.normal),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(onPressed: _store, child: const Text('Store')),
                OutlinedButton(onPressed: _status, child: const Text('Status')),
                OutlinedButton(onPressed: _cancel, child: const Text('Cancel')),
                OutlinedButton(onPressed: _ack, child: const Text('Ack')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _store() async {
    final id = _id.text.trim();
    final destination = _destination.text.trim();
    if (id.isEmpty || destination.isEmpty) return;
    final ttl = int.tryParse(_ttl.text) ?? 3600;
    final now = DateTime.now();
    final engine = ref.read(dtnEngineProvider);
    await engine.store(
      DtnPacket(
        packetId: id,
        source: 'local',
        destination: destination,
        payload: 'dev payload'.codeUnits,
        priority: _priority,
        direction: DtnDirection.outbound,
        ttlSeconds: ttl,
        createdAt: now,
        expiresAt: now.add(Duration(seconds: ttl)),
      ),
    );
  }

  Future<void> _status() async {
    final id = _id.text.trim();
    if (id.isEmpty) return;
    final packet = await ref.read(dtnEngineProvider).statusOf(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          packet == null
              ? '$id: not found'
              : '$id: ${packet.state.name} (${packet.attemptCount} attempts)',
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    final id = _id.text.trim();
    if (id.isEmpty) return;
    await ref.read(dtnEngineProvider).cancel(id);
  }

  Future<void> _ack() async {
    final id = _id.text.trim();
    if (id.isEmpty) return;
    ref.read(dtnEngineProvider).acknowledge(id, by: 'dev');
  }
}
