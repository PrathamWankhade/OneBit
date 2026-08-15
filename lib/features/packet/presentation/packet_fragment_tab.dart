import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/packet/domain/packet_incoming.dart';
import 'package:onebit/features/packet/domain/packet_reassembly_state.dart';
import 'package:onebit/features/packet/presentation/packet_controllers.dart';
import 'package:onebit/features/packet/presentation/packet_dev_widgets.dart';
import 'package:onebit/features/packet/presentation/packet_providers.dart';

/// Fragment viewer: sends payloads through the repository (fragmented by the
/// transport MTU), shows the live reassembly queue, the received packets and
/// the typed rejections.
class PacketFragmentTab extends ConsumerStatefulWidget {
  const PacketFragmentTab({super.key});

  @override
  ConsumerState<PacketFragmentTab> createState() => _PacketFragmentTabState();
}

final class _PacketFragmentTabState extends ConsumerState<PacketFragmentTab> {
  final TextEditingController _destination = TextEditingController(
    text: 'node-b',
  );
  final TextEditingController _payload = TextEditingController(
    text:
        'The quick brown fox jumps over the lazy dog. '
        'This payload splits across several BLE frames because every '
        'frame must stay within the negotiated MTU budget.',
  );

  String? _sendNote;

  @override
  void dispose() {
    _destination.dispose();
    _payload.dispose();
    super.dispose();
  }

  Future<void> _send(BuildContext context) async {
    final destination = _destination.text.trim();
    final text = _payload.text;
    if (destination.isEmpty || text.isEmpty) return;
    final result = await ref
        .read(packetRepositoryProvider)
        .send(destination: destination, payload: text.codeUnits);
    if (!mounted) return;
    setState(() {
      _sendNote = result.isOk
          ? 'sent: ${text.length} bytes to $destination'
          : 'rejected: ${result.failure}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(packetFragmentQueueControllerProvider);
    final state = ref.watch(packetStateProvider);
    final outcome = state.value;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        PacketDevSection(
          title: 'Send (repository path with MTU fragmentation)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _destination,
                decoration: const InputDecoration(
                  labelText: 'Destination node id',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _payload,
                decoration: const InputDecoration(
                  labelText: 'Payload (utf-8 text)',
                  isDense: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => _send(context),
                child: const Text('Send'),
              ),
              if (_sendNote != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(_sendNote!, style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        PacketDevSection(
          title: 'Fragment queue (${sessions.length} sessions)',
          child: sessions.isEmpty
              ? const Text('No active reassembly sessions.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final session in sessions)
                      _SessionRow(session: session),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        PacketDevSection(
          title: 'Latest decode outcome',
          child: outcome == null
              ? const Text('No frames processed yet.')
              : Text(_describe(outcome), style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  static String _describe(PacketDecodeOutcome outcome) {
    return switch (outcome) {
      PacketDelivered(:final packet) =>
        'delivered: ${packet.header.type.name} '
            '(${packet.payload.type}, ${packet.payload.bytes.length} bytes)',
      PacketFragmentBuffered(:final fragmentsPresent, :final fragmentCount) =>
        'fragment buffered: $fragmentsPresent/$fragmentCount',
      PacketRejected(:final failure) => 'rejected: ${failure.toString()}',
    };
  }
}

final class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final ReassemblySession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PacketFieldRow(
          label: session.packetId.value,
          value: 'run ${session.fragmentId}',
        ),
        PacketFieldRow(
          label: 'Progress',
          value: '${session.fragmentsPresent}/${session.fragmentCount}',
        ),
        PacketFieldRow(
          label: 'Expires',
          value: session.expiresAt.toIso8601String(),
        ),
      ],
    );
  }
}
