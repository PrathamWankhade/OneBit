import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/routing/providers/routing_diagnostics_provider.dart';

/// Dashboard overview showing routing health summary.
class DashboardOverview extends StatelessWidget {
  const DashboardOverview({super.key, required this.snapshot});

  final DiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Routing Health', style: AppTheme.titleMedium),
        const SizedBox(height: AppTheme.space12),
        _SummaryCard(
          icon: Icons.people_outline,
          label: 'Neighbors',
          value: '${snapshot.neighborCount}',
          color: AppTheme.accent,
          description: 'Directly connected peers',
        ),
        _SummaryCard(
          icon: Icons.wifi_tethering,
          label: 'Reachable Peers',
          value: '${snapshot.reachablePeerCount}',
          color: AppTheme.trust,
          description: 'Peers accessible via mesh',
        ),
        _SummaryCard(
          icon: Icons.hub,
          label: 'Topology Sources',
          value: '${snapshot.topologySourceCount}',
          color: AppTheme.mesh,
          description: 'Known mesh topology',
        ),
        _SummaryCard(
          icon: Icons.route,
          label: 'Active Routes',
          value: '${snapshot.activeRouteCount}',
          color: AppTheme.accent,
          description: 'Routing table entries',
        ),
        _SummaryCard(
          icon: Icons.shield_outlined,
          label: 'Security Events',
          value: '${snapshot.securityEventCount}',
          color: snapshot.securityEventCount > 0 ? AppTheme.danger : AppTheme.trust,
          description: snapshot.securityEventCount > 0
              ? 'Requires attention'
              : 'All clear',
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.description,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                ),
                if (description != null)
                  Text(
                    description!,
                    style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: AppTheme.titleLarge.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
