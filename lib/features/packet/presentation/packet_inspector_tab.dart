import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/packet/crc/crc32.dart';
import 'package:onebit/features/packet/domain/packet.dart';
import 'package:onebit/features/packet/domain/packet_payload.dart';
import 'package:onebit/features/packet/domain/packet_priority.dart';
import 'package:onebit/features/packet/domain/packet_type.dart';
import 'package:onebit/features/packet/engine/packet_engine.dart';
import 'package:onebit/features/packet/fragmentation/packet_fragmenter.dart';
import 'package:onebit/features/packet/presentation/packet_dev_widgets.dart';
import 'package:onebit/features/packet/presentation/packet_providers.dart';

/// Packet inspector: assemble a packet from the form, then view the
/// header fields, the payload, the full binary frame with its CRC, and a
/// fragmentation preview for a chosen MTU.
class PacketInspectorTab extends ConsumerStatefulWidget {
  const PacketInspectorTab({super.key});

  @override
  ConsumerState<PacketInspectorTab> createState() => _PacketInspectorTabState();
}

final class _PacketInspectorTabState extends ConsumerState<PacketInspectorTab> {
  final TextEditingController _destination = TextEditingController(
    text: 'node-b',
  );
  final TextEditingController _payload = TextEditingController(
    text: 'hello mesh',
  );
  final TextEditingController _mtu = TextEditingController(text: '185');
  PacketType _type = PacketType.message;
  PacketPriority _priority = PacketPriority.normal;
  bool _ackRequested = false;

  Packet? _built;
  List<int>? _frame;
  bool _decodedOk = false;
  PacketFraming? _framing;

  @override
  void dispose() {
    _destination.dispose();
    _payload.dispose();
    _mtu.dispose();
    super.dispose();
  }

  void _build() {
    final engine = ref.read(packetEngineProvider);
    final packet = _compose(engine);
    final encoded = engine.serializer.encode(packet);
    setState(() {
      _built = packet;
      _frame = encoded.isOk ? encoded.value : null;
      _decodedOk = false;
      if (_frame != null) {
        final decoded = engine.serializer.decode(_frame!);
        _decodedOk = decoded.isOk;
      }
    });
  }

  void _previewFragments() {
    final engine = ref.read(packetEngineProvider);
    final base = _built;
    final packet = base ?? _compose(engine);
    final mtu = int.tryParse(_mtu.text) ?? 185;
    final framing = engine.framesFor(packet, mtu: mtu);
    setState(() => _framing = framing.isOk ? framing.value : null);
  }

  Packet _compose(PacketEngine engine) {
    return engine.createMessage(
      destination: _destination.text.trim(),
      payload: PacketPayload.utf8(_payload.text),
      type: _type,
      priority: _priority,
      ackRequested: _ackRequested,
    );
  }

  @override
  Widget build(BuildContext context) {
    final built = _built;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        PacketDevSection(
          title: 'Compose',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _destination,
                decoration: const InputDecoration(
                  labelText: 'Destination node id (empty = broadcast)',
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
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _mtu,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'MTU budget (fragment preview)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  DropdownButton<PacketType>(
                    value: _type,
                    items: [
                      for (final type in PacketType.values)
                        DropdownMenuItem(value: type, child: Text(type.name)),
                    ],
                    onChanged: (value) => setState(() => _type = value!),
                  ),
                  DropdownButton<PacketPriority>(
                    value: _priority,
                    items: [
                      for (final priority in PacketPriority.values)
                        DropdownMenuItem(
                          value: priority,
                          child: Text(priority.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _priority = value!),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Switch(
                    value: _ackRequested,
                    onChanged: (value) => setState(() => _ackRequested = value),
                  ),
                  const Text('ack requested'),
                  FilledButton.tonal(
                    onPressed: _build,
                    child: const Text('Build + encode'),
                  ),
                  FilledButton.tonal(
                    onPressed: _previewFragments,
                    child: const Text('Fragment preview'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (built != null) ...<Widget>[
          const SizedBox(height: 12),
          PacketDevSection(
            title: 'Header ($_headerLabel)',
            child: _HeaderView(packet: built),
          ),
          const SizedBox(height: 12),
          PacketDevSection(
            title: 'Payload',
            child: _PayloadView(packet: built),
          ),
          const SizedBox(height: 12),
          PacketDevSection(
            title: 'Binary + CRC checker',
            child: _frame == null
                ? const Text('Encode failed.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      PacketHexDump(bytes: _frame!),
                      const SizedBox(height: 8),
                      PacketFieldRow(
                        label: 'Frame size',
                        value: '${_frame!.length} bytes',
                      ),
                      PacketFieldRow(
                        label: 'CRC-32/IEEE (frame minus trailer)',
                        value: '0x$_frameCrcHex',
                      ),
                      if (_frame != null)
                        PacketFieldRow(
                          label: 'Re-decoded',
                          value: _decodedOk
                              ? '✓ valid frame'
                              : '✗ decode failed',
                        ),
                    ],
                  ),
          ),
        ],
        if (_framing != null) ...<Widget>[
          const SizedBox(height: 12),
          PacketDevSection(
            title: 'Fragment preview (${_framing!.frames.length} frames)',
            child: _FragmentPreview(framing: _framing!),
          ),
        ],
      ],
    );
  }

  String get _headerLabel => _frame == null ? 'build only' : 'round-trip ✓';

  String get _frameCrcHex {
    final frame = _frame;
    if (frame == null) return '—';
    final crc = Crc32.compute(frame.sublist(0, frame.length - 4));
    return crc.toRadixString(16).padLeft(8, '0');
  }
}

final class _HeaderView extends StatelessWidget {
  const _HeaderView({required this.packet});

  final Packet packet;

  @override
  Widget build(BuildContext context) {
    final header = packet.header;
    final flags = header.flags.map((flag) => flag.name).join(', ');
    final destination = header.destination.isEmpty
        ? '*broadcast*'
        : header.destination;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PacketFieldRow(label: 'Version', value: header.version.toString()),
        PacketFieldRow(label: 'Type', value: header.type.name),
        PacketFieldRow(label: 'Priority', value: header.priority.name),
        PacketFieldRow(label: 'Flags', value: flags.isEmpty ? 'none' : flags),
        PacketFieldRow(
          label: 'Compatibility flags',
          value: '0x${header.compatibilityFlags.toRadixString(16)}',
        ),
        PacketFieldRow(label: 'Sequence', value: '${header.sequence}'),
        PacketFieldRow(
          label: 'From → to',
          value: '${header.source} → $destination',
        ),
        PacketFieldRow(
          label: 'TTL / hops',
          value: '${header.ttl} / ${header.hopCount}',
        ),
        PacketFieldRow(
          label: 'Fragment',
          value:
              '${header.fragmentIndex}/${header.fragmentCount} '
              '(run ${header.fragmentId})',
        ),
        PacketFieldRow(
          label: 'Created at',
          value: header.createdAt.toIso8601String(),
        ),
        PacketFieldRow(
          label: 'Signature',
          value: '${packet.signature.length} bytes',
        ),
      ],
    );
  }
}

final class _PayloadView extends StatelessWidget {
  const _PayloadView({required this.packet});

  final Packet packet;

  @override
  Widget build(BuildContext context) {
    final payload = packet.payload;
    final text = payload.utf8Text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PacketFieldRow(label: 'Type', value: payload.type.name),
        PacketFieldRow(label: 'Size', value: '${payload.bytes.length} bytes'),
        if (payload.uncompressedSize != null)
          PacketFieldRow(
            label: 'Uncompressed size',
            value: '${payload.uncompressedSize}',
          ),
        if (text != null)
          Text(
            'text: $text',
            style: const TextStyle(fontSize: 12),
            softWrap: true,
          ),
        const SizedBox(height: 4),
        PacketHexDump(bytes: payload.bytes, maxLines: 4),
      ],
    );
  }
}

final class _FragmentPreview extends StatelessWidget {
  const _FragmentPreview({required this.framing});

  final PacketFraming framing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PacketFieldRow(
          label: 'Fragmented',
          value: framing.fragmented ? 'yes' : 'no',
        ),
        for (final frame in framing.frames)
          PacketFieldRow(
            label: 'Fragment ${frame.packet.header.fragmentIndex}',
            value:
                '${frame.packet.payload.bytes.length} payload bytes '
                '· ${frame.bytes.length} frame bytes',
          ),
      ],
    );
  }
}
