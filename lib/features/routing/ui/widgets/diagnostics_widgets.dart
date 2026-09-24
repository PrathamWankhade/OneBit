import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/routing/providers/routing_diagnostics_provider.dart';
import 'package:onebit/features/routing/routing_security.dart';

/// Recovery diagnostics showing current recovery operations.
class RecoveryDiagnosticsView extends StatelessWidget {
  const RecoveryDiagnosticsView({super.key, required this.snapshot});

  final DiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final recovering = snapshot.recoveringDestinations;

    if (recovering.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.build_outlined, size: 48),
              SizedBox(height: 16),
              Text('No Active Recovery'),
              SizedBox(height: 8),
              Text('No route recovery operations in progress.'),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: recovering.length,
      itemBuilder: (context, index) {
        final destId = recovering[index];
        final shortId = destId.length > 12 ? destId.substring(0, 12) : destId;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: const CircularProgressIndicator(strokeWidth: 2),
            title: Text('Recovering â†’ $shortId...'),
            subtitle: const Text('Discovery in progress'),
          ),
        );
      },
    );
  }
}

/// Security diagnostics showing security event log.
class SecurityDiagnosticsView extends StatelessWidget {
  const SecurityDiagnosticsView({super.key, required this.snapshot});

  final DiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final events = snapshot.securityEvents;

    if (events.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 48),
              SizedBox(height: 16),
              Text('No Security Events'),
              SizedBox(height: 8),
              Text('No routing security events recorded.'),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final shortId = event.peerId.length > 8
            ? event.peerId.substring(0, 8)
            : event.peerId;

        return ListTile(
          leading: Icon(
            _eventIcon(event.event),
            color: _eventColor(event.event, Theme.of(context).colorScheme),
          ),
          title: Text(_eventLabel(event.event)),
          subtitle: Text('Peer $shortId...'),
        );
      },
    );
  }

  IconData _eventIcon(RoutingSecurityEvent event) {
    switch (event) {
      case RoutingSecurityEvent.validationPassed:
        return Icons.check_circle;
      case RoutingSecurityEvent.senderIdentityMismatch:
      case RoutingSecurityEvent.senderNotAuthenticated:
      case RoutingSecurityEvent.structuralValidationFailed:
      case RoutingSecurityEvent.selfLoopDetected:
        return Icons.error;
      case RoutingSecurityEvent.duplicateNeighborsNormalized:
        return Icons.warning;
    }
  }

  Color _eventColor(RoutingSecurityEvent event, ColorScheme colorScheme) {
    switch (event) {
      case RoutingSecurityEvent.validationPassed:
        return AppTheme.trust;
      case RoutingSecurityEvent.duplicateNeighborsNormalized:
        return AppTheme.warning;
      default:
        return colorScheme.error;
    }
  }

  String _eventLabel(RoutingSecurityEvent event) {
    switch (event) {
      case RoutingSecurityEvent.validationPassed:
        return 'Validation Passed';
      case RoutingSecurityEvent.senderIdentityMismatch:
        return 'Sender Identity Mismatch';
      case RoutingSecurityEvent.senderNotAuthenticated:
        return 'Sender Not Authenticated';
      case RoutingSecurityEvent.structuralValidationFailed:
        return 'Structural Validation Failed';
      case RoutingSecurityEvent.selfLoopDetected:
        return 'Self-Loop Detected';
      case RoutingSecurityEvent.duplicateNeighborsNormalized:
        return 'Duplicates Normalized';
    }
  }
}

/// Performance panel showing routing metrics.
class PerformancePanel extends StatelessWidget {
  const PerformancePanel({super.key, required this.snapshot});

  final DiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Performance Metrics', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _MetricCard('Neighbors', '${snapshot.neighborCount}'),
        _MetricCard('Reachable Peers', '${snapshot.reachablePeerCount}'),
        _MetricCard('Topology Sources', '${snapshot.topologySourceCount}'),
        _MetricCard('Active Routes', '${snapshot.activeRouteCount}'),
        _MetricCard('Security Events', '${snapshot.securityEventCount}'),
        _MetricCard(
          'Total Peers Known',
          '${snapshot.topologyEntries.fold<int>(0, (sum, e) => sum + e.neighborCount)}',
        ),
        _MetricCard(
          'Snapshot Age',
          '${DateTime.now().difference(snapshot.generatedAt).inSeconds}s',
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTheme.bodyMedium),
            Text(
              value,
              style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Export diagnostics button.
class ExportDiagnosticsButton extends ConsumerWidget {
  const ExportDiagnosticsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      onPressed: () => _exportDiagnostics(context, ref),
      icon: const Icon(Icons.download),
      label: const Text('Export Diagnostics'),
    );
  }

  void _exportDiagnostics(BuildContext context, WidgetRef ref) {
    final snapshot = ref.read(routingDiagnosticsProvider);

    final export = {
      'generatedAt': snapshot.generatedAt.toIso8601String(),
      'summary': {
        'neighborCount': snapshot.neighborCount,
        'reachablePeerCount': snapshot.reachablePeerCount,
        'topologySourceCount': snapshot.topologySourceCount,
        'activeRouteCount': snapshot.activeRouteCount,
        'securityEventCount': snapshot.securityEventCount,
      },
      'neighbors': snapshot.neighbors
          .map((n) => {
                'peerId': n.peerId,
                'isActive': n.isActive,
                'isReachable': n.isReachable,
                'reason': n.reachabilityReason.name,
              })
          .toList(),
      'topology': snapshot.topologyEntries
          .map((t) => {
                'source': t.sourceIdentity,
                'neighbors': t.neighborCount,
                'sequence': t.sequence,
                'receivedAt': t.receivedAt.toIso8601String(),
              })
          .toList(),
      'routes': snapshot.routes
          .map((r) => {
                'destination': r.destinationPeerId,
                'nextHop': r.nextHopPeerId,
                'metric': r.metric,
                'state': r.state.name,
                'source': r.source.name,
              })
          .toList(),
      'securityEvents': snapshot.securityEvents
          .map((e) => {
                'peerId': e.peerId,
                'event': e.event.name,
              })
          .toList(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(export);

    Clipboard.setData(ClipboardData(text: json));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diagnostics exported to clipboard')),
    );
  }
}

/// Log viewer for routing events.
class LogViewer extends StatefulWidget {
  const LogViewer({super.key, required this.snapshot});

  final DiagnosticsSnapshot snapshot;

  @override
  State<LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<LogViewer> {
  String _filter = 'All';
  String _search = '';

  static const _categories = [
    'All',
    'Security',
    'Topology',
    'Recovery',
  ];

  @override
  Widget build(BuildContext context) {
    var events = widget.snapshot.securityEvents;

    if (_filter != 'All') {
      events = events.where((e) {
        switch (_filter) {
          case 'Security':
            return true;
          case 'Topology':
            return true;
          case 'Recovery':
            return true;
          default:
            return true;
        }
      }).toList();
    }

    if (_search.isNotEmpty) {
      events = events.where((e) {
        return e.peerId.toLowerCase().contains(_search.toLowerCase()) ||
            e.event.name.toLowerCase().contains(_search.toLowerCase());
      }).toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search logs...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = cat == _filter;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _filter = cat),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: events.isEmpty
              ? const Center(child: Text('No matching events'))
              : ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final shortId = event.peerId.length > 8
                        ? event.peerId.substring(0, 8)
                        : event.peerId;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        _logIcon(event.event),
                        size: 16,
                        color: _logColor(event.event, Theme.of(context).colorScheme),
                      ),
                      title: Text(event.event.name),
                      subtitle: Text('Peer $shortId...'),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _logIcon(RoutingSecurityEvent event) {
    switch (event) {
      case RoutingSecurityEvent.validationPassed:
        return Icons.check_circle;
      case RoutingSecurityEvent.senderIdentityMismatch:
      case RoutingSecurityEvent.senderNotAuthenticated:
      case RoutingSecurityEvent.structuralValidationFailed:
      case RoutingSecurityEvent.selfLoopDetected:
        return Icons.error;
      case RoutingSecurityEvent.duplicateNeighborsNormalized:
        return Icons.warning;
    }
  }

  Color _logColor(RoutingSecurityEvent event, ColorScheme colorScheme) {
    switch (event) {
      case RoutingSecurityEvent.validationPassed:
        return AppTheme.trust;
      case RoutingSecurityEvent.duplicateNeighborsNormalized:
        return AppTheme.warning;
      default:
        return colorScheme.error;
    }
  }
}

