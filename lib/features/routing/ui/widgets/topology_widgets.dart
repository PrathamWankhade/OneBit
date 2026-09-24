import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/routing/providers/routing_diagnostics_provider.dart';

class TopologyListView extends StatelessWidget {
  const TopologyListView({super.key, required this.snapshot});

  final DiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final entries = snapshot.topologyEntries;

    if (entries.isEmpty) {
      return const _EmptyState(
        icon: Icons.hub_outlined,
        title: 'No Topology Data',
        description: 'No topology advertisements received yet.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Row(
            children: [
              Text(
                'Topology Sources (${entries.length})',
                style: AppTheme.titleMedium.copyWith(color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              return _TopologyEntryTile(entry: entries[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _TopologyEntryTile extends StatelessWidget {
  const _TopologyEntryTile({required this.entry});

  final TopologyEntryDiagnostics entry;

  @override
  Widget build(BuildContext context) {
    final shortId = entry.sourceIdentity.length > 8
        ? entry.sourceIdentity.substring(0, 8)
        : entry.sourceIdentity;

    final age = DateTime.now().difference(entry.receivedAt);
    final ageText = age.inSeconds < 60
        ? '${age.inSeconds}s ago'
        : age.inMinutes < 60
            ? '${age.inMinutes}m ago'
            : '${age.inHours}h ago';

    final isRecent = age.inMinutes < 5;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space4,
      ),
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isRecent ? AppTheme.trust : AppTheme.textTertiary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Center(
              child: Text(
                shortId.substring(0, 2).toUpperCase(),
                style: AppTheme.technicalSmall.copyWith(
                  color: isRecent ? AppTheme.trust : AppTheme.textTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Peer ${shortId.substring(0, 6)}...',
                  style: AppTheme.technicalBody
                      .copyWith(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.neighborCount} neighbors',
                  style: AppTheme.caption
                      .copyWith(color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Seq ${entry.sequence}',
                style: AppTheme.technicalSmall
                    .copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                ageText,
                style: AppTheme.caption
                    .copyWith(color: AppTheme.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ReachabilityMatrix extends StatelessWidget {
  const ReachabilityMatrix({super.key, required this.snapshot});

  final DiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final neighbors = snapshot.neighbors;

    if (neighbors.isEmpty) {
      return const _EmptyState(
        icon: Icons.grid_on_outlined,
        title: 'No Reachability Data',
        description: 'Add neighbors to see reachability matrix.',
      );
    }

    final peerIds = neighbors.map((n) => n.peerId).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Text(
            'Reachability Matrix',
            style: AppTheme.titleMedium
                .copyWith(color: AppTheme.textPrimary),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('')),
                  ...peerIds.map((id) {
                    final short = id.length > 6 ? id.substring(0, 6) : id;
                    return DataColumn(
                      label: Text(
                        short,
                        style: AppTheme.technicalSmall
                            .copyWith(color: AppTheme.textSecondary),
                      ),
                    );
                  }),
                ],
                rows: peerIds.map((rowId) {
                  final rowNeighbor =
                      neighbors.firstWhere((n) => n.peerId == rowId);
                  return DataRow(
                    cells: [
                      DataCell(Text(
                        rowId.length > 6 ? rowId.substring(0, 6) : rowId,
                        style: AppTheme.technicalBody
                            .copyWith(color: AppTheme.textPrimary),
                      )),
                      ...peerIds.map((colId) {
                        if (rowId == colId) {
                          return const DataCell(Text('\u2014',
                              style: TextStyle(
                                  color: AppTheme.textTertiary)));
                        }
                        final isReachable = rowNeighbor.isReachable;
                        return DataCell(
                          Icon(
                            isReachable
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: isReachable
                                ? AppTheme.trust
                                : AppTheme.danger,
                            size: 18,
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.textTertiary),
            const SizedBox(height: AppTheme.space16),
            Text(
              title,
              style: AppTheme.titleMedium
                  .copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              description,
              style: AppTheme.bodyMedium
                  .copyWith(color: AppTheme.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
