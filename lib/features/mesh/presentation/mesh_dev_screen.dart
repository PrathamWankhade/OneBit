import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_events.dart';
import 'package:onebit/features/mesh/domain/mesh_neighbor.dart';
import 'package:onebit/features/mesh/domain/mesh_repository.dart';
import 'package:onebit/features/mesh/domain/mesh_route.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/features/mesh/presentation/mesh_dev_screen/widgets/mesh_dev_panels.dart';

/// Developer dashboard for the mesh engine.
///
/// Not a product screen: it exercises discovery, routing, relay and the
/// engine lifecycle, and renders the diagnostics the future product UI
/// will consume.
class MeshDevScreen extends ConsumerStatefulWidget {
  const MeshDevScreen({super.key});

  @override
  ConsumerState<MeshDevScreen> createState() => _MeshDevScreenState();
}

final class _MeshDevScreenState extends ConsumerState<MeshDevScreen> {
  final List<MeshRelayEvent> _relayLog = [];
  final TextEditingController _destination = TextEditingController();
  final TextEditingController _payload = TextEditingController();

  @override
  void dispose() {
    _destination.dispose();
    _payload.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(meshRelayEventsProvider, (previous, next) {
      final event = next.value;
      if (event == null || event.isErr) return;
      final relayEvent = event.value;
      if (relayEvent == null) return;
      setState(() {
        _relayLog.insert(0, relayEvent);
        if (_relayLog.length > 40) _relayLog.removeLast();
      });
    });

    final state = ref.watch(meshStateProvider).value;
    final engineState = state?.value ?? MeshEngineState.stopped;

    return OneBitScaffold(
      appBar: AppBar(title: const Text('Mesh Engine')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _LifecyclePanel(engineState: engineState),
          const SizedBox(height: 12),
          _SendPanel(
            destination: _destination,
            payload: _payload,
            enabled: engineState == MeshEngineState.running,
          ),
          const SizedBox(height: 12),
          const _NeighborsPanel(),
          const SizedBox(height: 12),
          const _RoutesPanel(),
          const SizedBox(height: 12),
          const HealthPanel(),
          const SizedBox(height: 12),
          const TopologyPanel(),
          const SizedBox(height: 12),
          RelayLogPanel(events: _relayLog),
          const SizedBox(height: 12),
          const DiagnosticsPanel(),
        ],
      ),
    );
  }
}

final class _LifecyclePanel extends ConsumerWidget {
  const _LifecyclePanel({required this.engineState});

  final MeshEngineState engineState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'State: ${engineState.name}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: engineState == MeshEngineState.stopped
                      ? () => ref
                            .read(meshLifecycleControllerProvider.notifier)
                            .start()
                      : null,
                  child: const Text('Start'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: engineState == MeshEngineState.stopped
                      ? null
                      : () => ref
                            .read(meshLifecycleControllerProvider.notifier)
                            .stop(),
                  child: const Text('Stop'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _SendPanel extends ConsumerWidget {
  const _SendPanel({
    required this.destination,
    required this.payload,
    required this.enabled,
  });

  final TextEditingController destination;
  final TextEditingController payload;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: destination,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'Destination node id',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: payload,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'Payload (text)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: enabled ? () => _send(context, ref) : null,
                  child: const Text('Send'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: enabled
                      ? () async {
                          final text = destination.text.trim();
                          if (text.isEmpty) return;
                          await ref
                              .read(meshRepositoryProvider)
                              .discoverRoute(text);
                        }
                      : null,
                  child: const Text('Discover route'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    final destinationId = destination.text.trim();
    if (destinationId.isEmpty) return;
    final bytes = payload.text.codeUnits;
    final result = await ref
        .read(meshRepositoryProvider)
        .send(destination: destinationId, payload: bytes);
    if (result.isOk) {
      if (!context.mounted) return;
      final outcome = result.value;
      if (outcome is MeshSendForwarded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Forwarded via ${outcome.nextHop}')),
        );
      } else if (outcome is MeshSendDeliveredLocally) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Delivered locally')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No route — discovery broadcast')),
        );
      }
    }
  }
}

final class _NeighborsPanel extends ConsumerWidget {
  const _NeighborsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(meshNeighborsProvider).value;
    final neighbors = result?.value ?? const <MeshNeighbor>[];
    return Section(
      title: 'Neighbors (${neighbors.length})',
      child: neighbors.isEmpty
          ? const Text('No neighbors observed yet.')
          : Column(
              children: [
                for (final neighbor in neighbors)
                  ListTile(
                    dense: true,
                    title: Text(neighbor.nodeId),
                    subtitle: Text(
                      'rssi ${neighbor.smoothedRssiDb.toStringAsFixed(1)} dBm '
                      '· quality ${(neighbor.linkQuality * 100).round()}% '
                      '· ${neighbor.connectionState.name}',
                    ),
                    trailing: Text(
                      neighbor.distanceEstimateMeters == null
                          ? '—'
                          : '${neighbor.distanceEstimateMeters!.toStringAsFixed(0)} m',
                    ),
                  ),
              ],
            ),
    );
  }
}

final class _RoutesPanel extends ConsumerWidget {
  const _RoutesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(meshRoutesProvider).value;
    final routes = result?.value ?? const <MeshRoute>[];
    return Section(
      title: 'Routes (${routes.length})',
      child: routes.isEmpty
          ? const Text('No routes learned yet.')
          : Column(
              children: [
                for (final route in routes)
                  ListTile(
                    dense: true,
                    title: Text('${route.destination} → ${route.nextHop}'),
                    subtitle: Text(
                      '${route.hopCount} hops · cost ${route.cost.toStringAsFixed(2)}',
                    ),
                  ),
              ],
            ),
    );
  }
}
