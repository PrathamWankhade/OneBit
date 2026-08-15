import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/packet/domain/packet_incoming.dart';
import 'package:onebit/features/packet/domain/packet_payload.dart';
import 'package:onebit/features/packet/presentation/packet_dev_widgets.dart';
import 'package:onebit/features/packet/presentation/packet_providers.dart';

/// Serialization tester: paste arbitrary hex to decode a frame into its
/// header fields, or run the engine's own sample round-trip. The "corrupt
/// byte" toggle flips a header byte so the CRC checker rejects the frame.
class PacketWireTab extends ConsumerStatefulWidget {
  const PacketWireTab({super.key});

  @override
  ConsumerState<PacketWireTab> createState() => _PacketWireTabState();
}

final class _PacketWireTabState extends ConsumerState<PacketWireTab> {
  final TextEditingController _hex = TextEditingController();
  final TextEditingController _sample = TextEditingController(
    text: 'wire cabin',
  );
  bool _corruptByte = false;
  String? _outcome;
  List<int>? _sampleFrame;

  @override
  void dispose() {
    _hex.dispose();
    _sample.dispose();
    super.dispose();
  }

  void _decode() {
    final bytes = _parseHex(_hex.text);
    if (bytes == null) {
      setState(
        () => _outcome = 'invalid hex input (expected pairs of hex nibbles)',
      );
      return;
    }
    if (_corruptByte && bytes.length > 20) {
      final flipped = List<int>.of(bytes);
      flipped[20] = flipped[20] ^ 0x40;
      _runBytes(flipped);
      return;
    }
    _runBytes(bytes);
  }

  void _runBytes(List<int> bytes) {
    final engine = ref.read(packetEngineProvider);
    final outcome = engine.decode(bytes);
    final summary = switch (outcome) {
      PacketDelivered(:final packet) =>
        'delivered: ${packet.header.type.name}, '
            '${packet.payload.bytes.length} payload bytes, '
            'from ${packet.header.source}',
      PacketFragmentBuffered(:final fragmentsPresent, :final fragmentCount) =>
        'buffered fragment $fragmentsPresent/$fragmentCount',
      PacketRejected(:final failure) => 'rejected: ${failure.toString()}',
    };
    setState(() => _outcome = summary);
    ref.read(packetWireLogProvider.notifier).add(summary);
  }

  void _roundTrip() {
    final engine = ref.read(packetEngineProvider);
    final packet = engine.createMessage(
      destination: 'node-z',
      payload: PacketPayload.utf8(_sample.text),
    );
    final encoded = engine.serializer.encode(packet);
    if (encoded.failure case final failure?) {
      setState(() => _outcome = 'encode failed: $failure');
      return;
    }
    final frame = encoded.value!;
    final decoded = engine.serializer.decode(frame).value;
    setState(() {
      _sampleFrame = frame;
      _outcome = decoded == null
          ? 'round-trip failed: ${engine.serializer.decode(frame).failure}'
          : 'round-trip ok: ${decoded.header.type.name} → '
                '${decoded.payload.type} '
                '(${decoded.payload.bytes.length} bytes)';
    });
  }

  static List<int>? _parseHex(String text) {
    final cleaned = text.replaceAll(RegExp(r'[\s,]+'), '');
    if (cleaned.isEmpty || cleaned.length.isOdd) return null;
    final bytes = <int>[];
    for (var i = 0; i < cleaned.length; i += 2) {
      final byte = int.tryParse(cleaned.substring(i, i + 2), radix: 16);
      if (byte == null) return null;
      bytes.add(byte);
    }
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(packetWireLogProvider);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        PacketDevSection(
          title: 'Decode raw hex frame',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _hex,
                decoration: const InputDecoration(
                  labelText: 'Hex bytes (paste from the inspector)',
                  isDense: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  FilledButton.tonal(
                    onPressed: _decode,
                    child: const Text('Decode'),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: _corruptByte,
                    onChanged: (value) => setState(() => _corruptByte = value),
                  ),
                  const Text('corrupt byte 20'),
                ],
              ),
            ],
          ),
        ),
        if (_outcome != null) ...<Widget>[
          const SizedBox(height: 12),
          PacketDevSection(
            title: 'Outcome',
            child: Text(_outcome!, style: const TextStyle(fontSize: 12)),
          ),
        ],
        const SizedBox(height: 12),
        PacketDevSection(
          title: 'Engine round-trip',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _sample,
                decoration: const InputDecoration(
                  labelText: 'Sample payload text',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _roundTrip,
                child: const Text('Encode → decode'),
              ),
              if (_sampleFrame != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  '${_sampleFrame!.length} bytes',
                  style: const TextStyle(fontSize: 11),
                ),
                PacketHexDump(bytes: _sampleFrame!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        PacketDevSection(
          title: 'Serialization log',
          child: log.isEmpty
              ? const Text('No round-trips yet.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in log)
                      Text(line, style: const TextStyle(fontSize: 11)),
                  ],
                ),
        ),
      ],
    );
  }
}
