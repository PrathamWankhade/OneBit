import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/packet/presentation/packet_dev_widgets.dart';
import 'package:onebit/features/packet/presentation/packet_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';

/// Protocol statistics: the engine counters, the active protocol version,
/// the validation configuration and the compression policy in effect.
class PacketStatisticsTab extends ConsumerWidget {
  const PacketStatisticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(packetStatisticsProvider).value;
    final version = ref.watch(packetProtocolVersionProvider);
    final validator = ref.watch(packetValidatorProvider);
    final compression = ref.watch(packetCompressionPolicyProvider);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        OneBitScrollClearance.bottom(context),
      ),
      children: <Widget>[
        PacketDevSection(
          title: 'Counters',
          child: stats == null
              ? const Text('Waiting for the first snapshot…')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    PacketFieldRow(
                      label: 'Packets created',
                      value: '${stats.packetsCreated}',
                    ),
                    PacketFieldRow(
                      label: 'Frames handed to mesh',
                      value: '${stats.packetsSent}',
                    ),
                    PacketFieldRow(
                      label: 'Bytes sent',
                      value: '${stats.bytesSent}',
                    ),
                    PacketFieldRow(
                      label: 'Delivered',
                      value: '${stats.packetsDelivered}',
                    ),
                    PacketFieldRow(
                      label: 'Rejected',
                      value: '${stats.packetsRejected}',
                    ),
                    PacketFieldRow(
                      label: 'Fragments accepted',
                      value: '${stats.fragmentsAccepted}',
                    ),
                    PacketFieldRow(
                      label: 'Runs completed',
                      value: '${stats.fragmentsCompleted}',
                    ),
                    PacketFieldRow(
                      label: 'Runs expired',
                      value: '${stats.fragmentsExpired}',
                    ),
                    PacketFieldRow(
                      label: 'Active assemblies',
                      value: '${stats.activeAssemblies}',
                    ),
                    PacketFieldRow(
                      label: 'Errors logged',
                      value: '${stats.errorsLogged}',
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        PacketDevSection(
          title: 'Protocol',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PacketFieldRow(
                label: 'Version',
                value:
                    'transport ${version.transport} · '
                    'major ${version.major} · revision ${version.revision}',
              ),
              PacketFieldRow(
                label: 'Max fragments per run',
                value: '${validator.maxFragments}',
              ),
              PacketFieldRow(
                label: 'Compression strategy',
                value: compression.enabled ? 'zlib (fast)' : 'none',
              ),
              PacketFieldRow(
                label: 'Compression threshold',
                value: '${compression.threshold} bytes',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
