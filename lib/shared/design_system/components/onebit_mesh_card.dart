import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Mesh network summary card.
///
/// Strictly presentation-only: all counters are pre-rendered strings or
/// numbers supplied by the caller. No mesh state is read or derived here.
class OneBitMeshCard extends StatelessWidget {
  const OneBitMeshCard({
    required this.networkStatus,
    this.activeNodes,
    this.routes,
    this.rssi,
    this.latency,
    this.packets,
    this.onTap,
    super.key,
  });

  /// Overall network status preset chip.
  final OneBitStatusPreset networkStatus;

  /// Number of active nodes; `null` hides the stat.
  final int? activeNodes;

  /// Number of known routes; `null` hides the stat.
  final int? routes;

  /// Median link quality in dBm; `null` hides the stat.
  final int? rssi;

  /// Preformatted latency (e.g. "38 ms"); `null` hides the stat.
  final String? latency;

  /// Preformatted packet figure (e.g. "1.2k pkts"); `null` hides it.
  final String? packets;

  /// Tap action; `null` renders the card non-interactive.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return OneBitCard(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Mesh', style: textTheme.titleMedium)),
              OneBitStatusChip.preset(networkStatus),
            ],
          ),
          const SizedBox(height: OneBitSpacing.m),
          Row(
            children: [
              _Stat(label: 'Nodes', value: '${activeNodes ?? '—'}'),
              _Stat(label: 'Routes', value: '${routes ?? '—'}'),
              _Stat(label: 'dBm', value: '${rssi ?? '—'}'),
              _Stat(label: 'Latency', value: latency ?? '—'),
              _Stat(label: 'Packets', value: packets ?? '—'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Single statistic within a [OneBitMeshCard].
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;

  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: OneBitTypography.technicalStyle(color: scheme.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: OneBitSpacing.xs),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
