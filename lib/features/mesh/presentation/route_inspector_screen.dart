import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/mesh/domain/mesh_route.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Route table inspector: detailed view of all learned routes with
/// quality, reliability, cost and hop information.
class RouteInspectorScreen extends ConsumerWidget {
  const RouteInspectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final routesAsync = ref.watch(meshRoutesProvider);

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.routeInspectorTitle)),
      body: routesAsync.when(
        loading: () => const OneBitLoadingIndicator(label: ''),
        error: (e, _) => OneBitErrorState(
          message: l10n.commonError,
          detail: e.toString(),
          retryLabel: l10n.commonRetry,
          onRetry: () => ref.invalidate(meshRoutesProvider),
        ),
        data: (result) {
          if (result.isErr) {
            return OneBitErrorState(
              message: l10n.commonError,
              detail: result.failure.toString(),
              retryLabel: l10n.commonRetry,
              onRetry: () => ref.invalidate(meshRoutesProvider),
            );
          }
          final routes = result.value ?? [];
          if (routes.isEmpty) {
            return OneBitEmptyState(
              icon: OneBitIcons.shellMesh,
              title: l10n.meshEmptyRoutes,
              message: l10n.meshEmptyRoutesMessage,
            );
          }
          return _RouteList(routes: routes);
        },
      ),
    );
  }
}

class _RouteList extends StatelessWidget {
  const _RouteList({required this.routes});

  final List<MeshRoute> routes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Separate primary and alternative routes.
    final primary = routes.where((r) => r.preferred).toList();
    final alternatives = routes.where((r) => !r.preferred).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        OneBitSpacing.m,
        OneBitSpacing.m,
        OneBitSpacing.m,
        OneBitScrollClearance.bottom(context),
      ),
      children: [
        if (primary.isNotEmpty) ...[
          OneBitSectionHeader(title: l10n.meshRoutePrimary),
          for (final route in primary) _RouteDetailCard(route: route),
          const SizedBox(height: OneBitSpacing.m),
        ],
        if (alternatives.isNotEmpty) ...[
          OneBitSectionHeader(title: l10n.meshRouteAlternative),
          for (final route in alternatives) _RouteDetailCard(route: route),
        ],
      ],
    );
  }
}

class _RouteDetailCard extends StatelessWidget {
  const _RouteDetailCard({required this.route});

  final MeshRoute route;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    final qualityPreset = route.quality >= 0.7
        ? OneBitStatusPreset.online
        : route.quality >= 0.4
        ? OneBitStatusPreset.pending
        : OneBitStatusPreset.offline;

    return OneBitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  route.destination,
                  style: OneBitTypography.technicalStyle(
                    color: scheme.onSurface,
                    fontSize: OneBitTypography.body,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              OneBitStatusChip.preset(qualityPreset),
            ],
          ),
          const SizedBox(height: OneBitSpacing.m),
          _DetailRow(label: l10n.meshRouteNextHop, value: route.nextHop),
          _DetailRow(label: l10n.meshRouteHopCount, value: '${route.hopCount}'),
          _DetailRow(
            label: l10n.meshRouteCost,
            value: route.cost.toStringAsFixed(2),
          ),
          _DetailRow(
            label: l10n.meshRouteQuality,
            value: '${(route.quality * 100).round()}%',
          ),
          _DetailRow(
            label: l10n.meshRouteReliability,
            value: '${(route.reliability * 100).round()}%',
          ),
          _DetailRow(
            label: l10n.meshRouteLastUsed,
            value: _formatTime(route.lastUsed),
          ),
          if (route.expiresAt != null)
            _DetailRow(
              label: l10n.meshRouteExpired,
              value: _formatTime(route.expiresAt!),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: OneBitTypography.technicalStyle(
              fontSize: OneBitTypography.caption,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
