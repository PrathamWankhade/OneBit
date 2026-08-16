import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/features/mesh/domain/mesh_route.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Routes panel showing learned mesh routes.
final class RoutesPanel extends ConsumerWidget {
  const RoutesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final routesAsync = ref.watch(meshRoutesProvider);

    return routesAsync.when(
      loading: () => const OneBitCard(child: OneBitLoadingIndicator(label: '')),
      error: (e, _) => OneBitCard(
        child: Text(l10n.commonError, style: context.textTheme.bodyMedium),
      ),
      data: (result) {
        if (result.isErr) {
          return const SizedBox.shrink();
        }
        final routes = result.value ?? [];
        if (routes.isEmpty) {
          return const SizedBox.shrink();
        }
        return RoutesList(routes: routes);
      },
    );
  }
}

/// List of learned routes.
final class RoutesList extends StatelessWidget {
  const RoutesList({required this.routes, super.key});

  final List<MeshRoute> routes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return OneBitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.meshRoutesTitle,
                  style: context.textTheme.titleMedium,
                ),
              ),
              Text(
                '${routes.length}',
                style: OneBitTypography.oneBitNumeric(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: OneBitSpacing.xs),
          for (final route in routes) ...[
            RouteRow(route: route),
            if (route != routes.last)
              const SizedBox(height: OneBitSpacing.xxs),
          ],
        ],
      ),
    );
  }
}

/// A single route row.
final class RouteRow extends StatelessWidget {
  const RouteRow({required this.route, super.key});

  final MeshRoute route;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    route.destination,
                    style: OneBitTypography.oneBitNumeric(
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (route.preferred) ...[
                    const SizedBox(width: OneBitSpacing.s),
                    OneBitStatusChip.preset(
                      OneBitStatusPreset.online,
                      label: l10n.meshRoutePrimary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 1),
              Text(
                '${l10n.meshRouteNextHop}: ${route.nextHop} · '
                '${route.hopCount} ${route.hopCount == 1 ? 'hop' : 'hops'}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Q: ${(route.quality * 100).round()}%',
              style: OneBitTypography.oneBitCaption(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Text(
              'R: ${(route.reliability * 100).round()}%',
              style: OneBitTypography.oneBitCaption(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
