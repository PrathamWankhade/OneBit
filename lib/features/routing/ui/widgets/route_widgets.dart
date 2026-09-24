import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/routing/providers/routing_diagnostics_provider.dart';
import 'package:onebit/features/routing/route.dart';

class RouteTableViewer extends StatelessWidget {
  const RouteTableViewer({super.key, required this.snapshot});

  final DiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final routes = snapshot.routes;

    if (routes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.route_outlined, size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: AppTheme.space16),
              Text('No Routes',
                  style: AppTheme.titleMedium.copyWith(color: AppTheme.textPrimary)),
              const SizedBox(height: AppTheme.space8),
              Text('No routes in the routing table.',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Text(
            'Routes (${routes.length})',
            style: AppTheme.titleMedium.copyWith(color: AppTheme.textPrimary),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: routes.length,
            itemBuilder: (context, index) {
              return RouteTile(route: routes[index]);
            },
          ),
        ),
      ],
    );
  }
}

class RouteTile extends StatelessWidget {
  const RouteTile({super.key, required this.route});

  final RouteDiagnostics route;

  @override
  Widget build(BuildContext context) {
    final destShort = route.destinationPeerId.length > 8
        ? route.destinationPeerId.substring(0, 8)
        : route.destinationPeerId;
    final nextShort = route.nextHopPeerId.length > 8
        ? route.nextHopPeerId.substring(0, 8)
        : route.nextHopPeerId;

    final statusColor = route.state == RouteState.active
        ? AppTheme.trust
        : route.state == RouteState.stale
            ? AppTheme.warning
            : AppTheme.danger;

    final statusText = route.state.name;

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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(Icons.circle, color: statusColor, size: 10),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u2192 $destShort...',
                  style: AppTheme.technicalBody.copyWith(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'via $nextShort... \u00b7 metric ${route.metric}',
                  style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusText,
              style: AppTheme.technicalSmall.copyWith(color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}

class RouteInspector extends StatelessWidget {
  const RouteInspector({super.key, required this.route});

  final RouteDiagnostics route;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: AppTheme.bgBase,
        title: Text(
          'Route Inspector',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Route Details',
                    style: AppTheme.labelMedium
                        .copyWith(color: AppTheme.textPrimary)),
                const SizedBox(height: AppTheme.space12),
                _DetailRow('Destination', route.destinationPeerId),
                _DetailRow('Next Hop', route.nextHopPeerId),
                _DetailRow('Metric', '${route.metric}'),
                _DetailRow('State', route.state.name),
                _DetailRow('Source', route.source.name),
                if (route.expiresAt != null)
                  _DetailRow('Expires', route.expiresAt.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: AppTheme.caption.copyWith(color: AppTheme.textTertiary)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: AppTheme.technicalBody.copyWith(color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class ExpirationMonitor extends StatelessWidget {
  const ExpirationMonitor({super.key, required this.snapshot});

  final DiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final expiringRoutes = snapshot.routes
        .where((r) => r.expiresAt != null)
        .toList()
      ..sort((a, b) => a.expiresAt!.compareTo(b.expiresAt!));

    if (expiringRoutes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: AppTheme.space16),
              Text('No Expiring Routes',
                  style: AppTheme.titleMedium.copyWith(color: AppTheme.textPrimary)),
              const SizedBox(height: AppTheme.space8),
              Text('No routes with expiration set.',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Text(
            'Expiration Monitor (${expiringRoutes.length})',
            style: AppTheme.titleMedium.copyWith(color: AppTheme.textPrimary),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: expiringRoutes.length,
            itemBuilder: (context, index) {
              final route = expiringRoutes[index];
              final remaining = route.expiresAt!.difference(now);
              final isExpired = remaining.isNegative;
              final isWarning = !isExpired && remaining.inSeconds < 30;

              final destShort = route.destinationPeerId.length > 8
                  ? route.destinationPeerId.substring(0, 8)
                  : route.destinationPeerId;
              final nextShort = route.nextHopPeerId.length > 8
                  ? route.nextHopPeerId.substring(0, 8)
                  : route.nextHopPeerId;

              final color = isExpired
                  ? AppTheme.danger
                  : isWarning
                      ? AppTheme.warning
                      : AppTheme.trust;

              final statusText =
                  isExpired ? 'Expired' : isWarning ? 'Warning' : 'Healthy';

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
                    Icon(
                      isExpired
                          ? Icons.error
                          : isWarning
                              ? Icons.warning
                              : Icons.check_circle,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$destShort... via $nextShort...',
                            style: AppTheme.technicalBody
                                .copyWith(color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isExpired
                                ? 'Expired'
                                : 'Expires in ${remaining.inSeconds}s',
                            style: AppTheme.caption
                                .copyWith(color: AppTheme.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: AppTheme.technicalSmall.copyWith(color: color),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
