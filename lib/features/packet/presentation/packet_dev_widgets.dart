import 'package:flutter/material.dart';

/// Section card used by every packet developer tab.
class PacketDevSection extends StatelessWidget {
  const PacketDevSection({required this.title, required this.child, super.key});

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

/// A label/value row for the header viewers.
class PacketFieldRow extends StatelessWidget {
  const PacketFieldRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders [bytes] as a hex dump with an ASCII gutter, 16 bytes per line.
class PacketHexDump extends StatelessWidget {
  const PacketHexDump({required this.bytes, this.maxLines = 8, super.key});

  final List<int> bytes;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[];
    for (var offset = 0; offset < bytes.length; offset += 16) {
      if (lines.length >= maxLines) break;
      final chunk = bytes.sublist(
        offset,
        offset + 16 > bytes.length ? bytes.length : offset + 16,
      );
      final hex = chunk
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      final ascii = chunk
          .map((b) => b >= 0x20 && b <= 0x7E ? String.fromCharCode(b) : '.')
          .join();
      lines.add('${offset.toRadixString(16).padLeft(4, '0')}  $hex  $ascii');
    }
    if (lines.isEmpty) lines.add('(empty)');
    return SelectableText(
      lines.join('\n'),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
    );
  }
}

/// Formats [bytes] as a compact hex string.
String packetBytesToHex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
}
