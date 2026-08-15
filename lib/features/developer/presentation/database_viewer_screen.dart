import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/database/database_providers.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Database viewer: read-only presentation of table row counts and storage
/// diagnostics. Never exposes private keys, message plaintext, or secrets.
class DatabaseViewerScreen extends ConsumerWidget {
  const DatabaseViewerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.dbViewerTitle)),
      body: FutureBuilder(
        future: ref.read(statisticsRepositoryProvider).snapshot(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: OneBitLoadingIndicator());
          }

          final result = snapshot.data;
          if (result == null || result.isErr) {
            return Center(
              child: OneBitCard(
                child: Text(
                  l10n.dbViewerEmpty,
                  style: context.textTheme.bodyMedium,
                ),
              ),
            );
          }

          final stats = result.value!;
          final rows = <_TableRowData>[
            _TableRowData(l10n.dbViewerTableMessages, stats.messages),
            _TableRowData(l10n.dbViewerTablePackets, stats.packets),
            _TableRowData(l10n.dbViewerTableRoutes, stats.routes),
            _TableRowData(l10n.dbViewerTableNeighbors, stats.neighbors),
            _TableRowData(l10n.dbViewerTableTrustedNodes, stats.trustedNodes),
            _TableRowData(l10n.dbViewerTableSessions, stats.sessions),
            _TableRowData(l10n.dbViewerTableLogs, stats.logs),
            _TableRowData(l10n.dbViewerTableStats, stats.stats),
          ];

          final total = rows.fold<int>(0, (sum, r) => sum + r.count);

          return ListView(
            padding: const EdgeInsets.all(OneBitSpacing.m),
            children: [
              OneBitCard(
                child: Row(
                  children: [
                    Text(
                      l10n.dbViewerTotalRows,
                      style: context.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text('$total', style: context.textTheme.headlineSmall),
                  ],
                ),
              ),
              const SizedBox(height: OneBitSpacing.m),
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: OneBitSpacing.s),
                  child: OneBitCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.label,
                            style: context.textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          '${row.count}',
                          style: context.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TableRowData {
  const _TableRowData(this.label, this.count);
  final String label;
  final int count;
}
