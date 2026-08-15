import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/extensions/date_time_extensions.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/identity/domain/trust_level.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/nodes/presentation/nodes_controller.dart';
import 'package:onebit/l10n/app_localizations.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_node_card.dart';
import 'package:onebit/shared/design_system/components/onebit_offline_banner.dart';
import 'package:onebit/shared/design_system/components/onebit_offline_state.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/responsive/onebit_master_detail.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Nodes tab: the local registry.
///
/// Renders exclusively from [nodesViewProvider]; trusted contacts and live
/// neighbors arrive already merged by the controller. Rows are
/// [OneBitNodeCard]s with technical identifiers in the Consolas family.
class NodesScreen extends ConsumerWidget {
  const NodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(nodesViewProvider);

    return OneBitScaffold(
      appBar: AppBar(
        title: Text(l10n.nodesTitle),
        actions: [
          OneBitIconButton(
            icon: OneBitIcons.shellSettings,
            tooltip: l10n.settingsTitle,
            onPressed: () => context.push(AppRoutePaths.settings),
          ),
        ],
      ),
      body: _body(context, ref, view),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<NodesView> view,
  ) {
    final l10n = context.l10n;
    if (view.hasError) {
      return OneBitErrorState(
        message: l10n.nodesLoadError,
        detail: view.error.toString(),
        retryLabel: l10n.commonRetry,
        onRetry: () => ref.invalidate(nodesViewProvider),
      );
    }
    final value = view.value;
    if (value == null) {
      return const OneBitLoadingIndicator(label: '');
    }
    if (value.error != null && value.isEmpty) {
      return OneBitErrorState(
        message: l10n.nodesLoadError,
        detail: value.error.toString(),
        retryLabel: l10n.commonRetry,
        onRetry: () => ref.read(nodesViewProvider.notifier).retry(),
      );
    }
    if (!value.loaded) {
      return const OneBitLoadingIndicator(label: '');
    }
    if (value.offline && value.isEmpty) {
      return OneBitOfflineState(
        title: l10n.nodesOfflineTitle,
        message: l10n.nodesOfflineMessage,
      );
    }
    if (value.isEmpty) {
      return OneBitEmptyState(
        icon: OneBitIcons.shellNodes,
        title: l10n.nodesEmpty,
        message: l10n.nodesEmptyMessage,
      );
    }
    return Column(
      children: [
        if (value.offline)
          OneBitOfflineBanner(
            title: l10n.nodesOfflineTitle,
            message: l10n.nodesOfflineMessage,
          ),
        Expanded(
          child: context.isTablet
              ? _TabletNodeGrid(
                  trusted: value.trusted,
                  nearby: value.nearby,
                  l10n: l10n,
                )
              : ListView(
                  padding: const EdgeInsets.all(OneBitSpacing.m),
                  children: [
                    if (value.trusted.isNotEmpty) ...[
                      OneBitSectionHeader(
                        title: l10n.nodesTrustedSection,
                        subtitle: l10n.nodesTrustedCount(value.trusted.length),
                      ),
                      for (final row in value.trusted)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: OneBitSpacing.s),
                          child: _TrustedNodeCard(row: row),
                        ),
                      if (value.nearby.isNotEmpty)
                        const SizedBox(height: OneBitSpacing.l),
                    ],
                    if (value.nearby.isNotEmpty) ...[
                      OneBitSectionHeader(
                        title: l10n.nodesNearbySection,
                        subtitle: l10n.nodesNearbyCount(value.nearby.length),
                      ),
                      for (final row in value.nearby)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: OneBitSpacing.s),
                          child: _NearbyNodeCard(row: row),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// A trusted contact card: identity material plus live link data when the
/// node is currently a mesh neighbor.
final class _TrustedNodeCard extends ConsumerWidget {
  const _TrustedNodeCard({required this.row});

  final TrustedNodeRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final neighbor = row.neighbor;
    return OneBitNodeCard(
      name: row.name,
      nodeId: row.nodeId,
      fingerprint: row.fingerprint,
      verification: verificationPresetFor(row.trustLevel),
      verificationLabel: trustLevelLabel(l10n, row.trustLevel),
      connection: connectionPresetFor(neighbor?.connectionState),
      rssi: neighbor?.latestRssiDb,
      lastSeen: row.lastSeen == null
          ? null
          : relativeTimeLabel(l10n, row.lastSeen!),
      routeInfo: row.hasRoute
          ? l10n.nodeRouteHopCount(row.hopEstimate ?? 1)
          : l10n.nodeRouteUnavailable,
      onTap: () => context.go(AppRoutePaths.nodeOf(row.nodeId)),
    );
  }
}

/// A nearby node card: live link observation without identity material.
final class _NearbyNodeCard extends ConsumerWidget {
  const _NearbyNodeCard({required this.row});

  final NearbyNodeRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final neighbor = row.neighbor;
    return OneBitNodeCard(
      name: row.nodeId,
      nodeId: row.nodeId,
      verification: OneBitStatusPreset.nearby,
      verificationLabel: l10n.nodeTrustNearby,
      connection: connectionPresetFor(neighbor.connectionState),
      rssi: neighbor.latestRssiDb,
      lastSeen: relativeTimeLabel(l10n, neighbor.lastSeen),
      routeInfo: l10n.nodeRouteHopCount(row.hopEstimate),
      onTap: () => context.go(AppRoutePaths.nodeOf(row.nodeId)),
    );
  }
}

/// Localized label of a connection state.
String connectionStateLabel(AppLocalizations l10n, MeshLinkState state) =>
    switch (state) {
      MeshLinkState.advertising => l10n.nodeConnectionAdvertising,
      MeshLinkState.connecting => l10n.nodeConnectionConnecting,
      MeshLinkState.connected => l10n.nodeConnectionConnected,
      MeshLinkState.disconnecting => l10n.nodeConnectionDisconnecting,
      MeshLinkState.disconnected => l10n.nodeConnectionDisconnected,
    };

/// Localized label of a trust posture.
String trustLevelLabel(AppLocalizations l10n, TrustLevel level) =>
    switch (level) {
      TrustLevel.known => l10n.nodeTrustKnown,
      TrustLevel.verified => l10n.nodeTrustVerified,
      TrustLevel.blocked => l10n.nodeTrustBlocked,
    };

/// Relative "last seen" text ("just now", "5 min ago", …).
String relativeTimeLabel(AppLocalizations l10n, DateTime time) =>
    RelativeTime.of(time).label(l10n);
