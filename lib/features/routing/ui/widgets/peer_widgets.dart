import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/routing/providers/routing_diagnostics_provider.dart';
import 'package:onebit/features/routing/reachability_reason.dart';
import 'package:onebit/features/routing/routing_security.dart';

class NeighborDiagnosticsView extends StatelessWidget {
  const NeighborDiagnosticsView({super.key, required this.snapshot});

  final DiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final neighbors = snapshot.neighbors;

    if (neighbors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline, size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: AppTheme.space16),
              Text('No Neighbors',
                  style: AppTheme.titleMedium.copyWith(color: AppTheme.textPrimary)),
              const SizedBox(height: AppTheme.space8),
              Text('No routing neighbors detected.',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.space8),
      itemCount: neighbors.length,
      itemBuilder: (context, index) {
        return NeighborCard(neighbor: neighbors[index]);
      },
    );
  }
}

class NeighborCard extends StatelessWidget {
  const NeighborCard({super.key, required this.neighbor});

  final NeighborDiagnostics neighbor;

  @override
  Widget build(BuildContext context) {
    final shortId = neighbor.peerId.length > 12
        ? neighbor.peerId.substring(0, 12)
        : neighbor.peerId;

    final statusColor = neighbor.isReachable
        ? AppTheme.trust
        : neighbor.isActive
            ? AppTheme.warning
            : AppTheme.danger;

    final statusText = neighbor.isReachable
        ? 'Reachable'
        : neighbor.isActive
            ? 'Active (unreachable)'
            : 'Inactive';

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.space8,
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
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(Icons.circle, color: statusColor, size: 12),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Peer $shortId...',
                  style: AppTheme.technicalBody.copyWith(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '$statusText \u00b7 ${_reasonText(neighbor.reachabilityReason)}',
                  style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          Icon(
            neighbor.isReachable ? Icons.check_circle : Icons.warning,
            color: statusColor,
            size: 20,
          ),
        ],
      ),
    );
  }

  String _reasonText(ReachabilityReason reason) {
    switch (reason) {
      case ReachabilityReason.reachable:
        return 'All criteria met';
      case ReachabilityReason.unknownPeer:
        return 'Unknown peer';
      case ReachabilityReason.notConnected:
        return 'Not connected';
      case ReachabilityReason.staleConnection:
        return 'Stale connection';
      case ReachabilityReason.notNeighbor:
        return 'Not a neighbor';
      case ReachabilityReason.missingContext:
        return 'Missing context';
    }
  }
}

class PeerInspector extends StatelessWidget {
  const PeerInspector({super.key, required this.peerId, required this.snapshot});

  final String peerId;
  final DiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final neighbor =
        snapshot.neighbors.where((n) => n.peerId == peerId).firstOrNull;
    final peerRoutes = snapshot.routes
        .where((r) => r.destinationPeerId == peerId || r.nextHopPeerId == peerId)
        .toList();
    final securityEvents = snapshot.securityEvents
        .where((e) => e.peerId == peerId)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: AppTheme.bgBase,
        title: Text(
          'Peer ${peerId.length > 8 ? peerId.substring(0, 8) : peerId}...',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InspectorSection(
            title: 'Status',
            child: neighbor != null
                ? Column(
                    children: [
                      _InfoRow('Active', neighbor.isActive ? 'Yes' : 'No'),
                      _InfoRow('Reachable', neighbor.isReachable ? 'Yes' : 'No'),
                      _InfoRow('Reason', _reasonText(neighbor.reachabilityReason)),
                    ],
                  )
                : Text('Not a neighbor',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary)),
          ),
          const SizedBox(height: AppTheme.space12),
          _InspectorSection(
            title: 'Routes (${peerRoutes.length})',
            child: peerRoutes.isEmpty
                ? Text('No routes involving this peer',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary))
                : Column(
                    children: peerRoutes
                        .map((r) => _InfoRow(
                              '${r.destinationPeerId.substring(0, 6)}...',
                              'via ${r.nextHopPeerId.substring(0, 6)}... (metric ${r.metric})',
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: AppTheme.space12),
          _InspectorSection(
            title: 'Security Events (${securityEvents.length})',
            child: securityEvents.isEmpty
                ? Text('No security events',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary))
                : Column(
                    children: securityEvents
                        .map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    _securityIcon(e.event),
                                    color: _securityColor(e.event),
                                    size: 18,
                                  ),
                                  const SizedBox(width: AppTheme.space8),
                                  Text(e.event.name,
                                      style: AppTheme.bodyMedium
                                          .copyWith(color: AppTheme.textPrimary)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  String _reasonText(ReachabilityReason reason) {
    switch (reason) {
      case ReachabilityReason.reachable:
        return 'All criteria met';
      case ReachabilityReason.unknownPeer:
        return 'Unknown peer';
      case ReachabilityReason.notConnected:
        return 'Not connected';
      case ReachabilityReason.staleConnection:
        return 'Stale connection';
      case ReachabilityReason.notNeighbor:
        return 'Not a neighbor';
      case ReachabilityReason.missingContext:
        return 'Missing context';
    }
  }

  IconData _securityIcon(RoutingSecurityEvent event) {
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

  Color _securityColor(RoutingSecurityEvent event) {
    switch (event) {
      case RoutingSecurityEvent.validationPassed:
        return AppTheme.trust;
      case RoutingSecurityEvent.duplicateNeighborsNormalized:
        return AppTheme.warning;
      default:
        return AppTheme.danger;
    }
  }
}

class _InspectorSection extends StatelessWidget {
  const _InspectorSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTheme.labelMedium.copyWith(color: AppTheme.textPrimary)),
          const SizedBox(height: AppTheme.space8),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          Text(value, style: AppTheme.technicalSmall.copyWith(color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

class PeerTimeline extends StatelessWidget {
  const PeerTimeline({super.key, required this.snapshot});

  final DiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (snapshot.securityEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timeline, size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: AppTheme.space16),
              Text('No Events',
                  style: AppTheme.titleMedium.copyWith(color: AppTheme.textPrimary)),
              const SizedBox(height: AppTheme.space8),
              Text('No peer events recorded yet.',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.space16),
      itemCount: snapshot.securityEvents.length,
      itemBuilder: (context, index) {
        final event = snapshot.securityEvents[index];
        final shortId = event.peerId.length > 8
            ? event.peerId.substring(0, 8)
            : event.peerId;

        final color = _eventColor(event.event);

        return Container(
          margin: const EdgeInsets.only(bottom: AppTheme.space4),
          padding: const EdgeInsets.all(AppTheme.space12),
          decoration: BoxDecoration(
            color: AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(_eventIcon(event.event), color: color, size: 18),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.event.name,
                        style: AppTheme.bodyMedium
                            .copyWith(color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Peer $shortId...',
                        style: AppTheme.technicalSmall
                            .copyWith(color: AppTheme.textTertiary)),
                  ],
                ),
              ),
            ],
          ),
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

  Color _eventColor(RoutingSecurityEvent event) {
    switch (event) {
      case RoutingSecurityEvent.validationPassed:
        return AppTheme.trust;
      case RoutingSecurityEvent.duplicateNeighborsNormalized:
        return AppTheme.warning;
      default:
        return AppTheme.danger;
    }
  }
}
