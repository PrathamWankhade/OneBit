import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/logger/log_record.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/logger/logger_providers.dart';
import 'package:onebit/features/packet/presentation/packet_dev_widgets.dart';

/// Developer logs: the in-memory ring buffer filtered to packet-protocol
/// records (`LogTags.packet`), refreshed once a second like the other
/// developer panels.
class PacketLogsTab extends ConsumerStatefulWidget {
  const PacketLogsTab({super.key});

  @override
  ConsumerState<PacketLogsTab> createState() => _PacketLogsTabState();
}

final class _PacketLogsTabState extends ConsumerState<PacketLogsTab> {
  Timer? _timer;
  List<LogRecord> _records = const [];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final snapshot = ref
          .read(appLogBufferProvider)
          .snapshot()
          .where((record) => record.tag == LogTags.packet)
          .toList()
          .reversed
          .take(60)
          .toList();
      setState(() => _records = snapshot);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        PacketDevSection(
          title: 'Packet log lines (log buffer)',
          child: _records.isEmpty
              ? const Text('No packet log lines yet.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final record in _records)
                      SelectableText(
                        record.toLine(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
