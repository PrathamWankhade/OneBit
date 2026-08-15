import 'package:flutter/material.dart';
import 'package:onebit/core/extensions/date_time_extensions.dart';
import 'package:onebit/features/identity/domain/trust_contact.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_neighbor.dart';
import 'package:onebit/features/nodes/presentation/node_details_controller.dart';
import 'package:onebit/features/nodes/presentation/nodes_controller.dart';
import 'package:onebit/features/nodes/presentation/nodes_screen.dart';
import 'package:onebit/l10n/app_localizations.dart';
import 'package:onebit/shared/design_system/components/onebit_list_item.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Identity section for a node.
final class NodeIdentitySection extends StatelessWidget {
  const NodeIdentitySection({
    required this.model,
    required this.l10n,
    super.key,
  });

  final NodeDetailsModel model;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OneBitSectionHeader(title: l10n.nodeIdentitySection),
        OneBitListItem(
          title: l10n.nodeIdLabel,
          leading: OneBitIcons.node,
          trailing: Text(
            model.nodeId,
            style: OneBitTypography.technicalStyle(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        if (model.contact != null) ...[
          OneBitListItem(
            title: l10n.nodeFingerprintLabel,
            leading: OneBitIcons.security,
            trailing: Text(
              model.contact!.fingerprintHex,
              style: OneBitTypography.technicalStyle(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ] else
          OneBitListItem(
            title: l10n.nodeNotInContacts,
            leading: OneBitIcons.info,
          ),
      ],
    );
  }
}

/// Connection details section for a node.
final class NodeConnectionSection extends StatelessWidget {
  const NodeConnectionSection({
    required this.neighbor,
    required this.l10n,
    super.key,
  });

  final MeshNeighbor? neighbor;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: OneBitSpacing.l),
        OneBitSectionHeader(title: l10n.nodeConnectionSection),
        if (neighbor == null)
          OneBitListItem(
            title: l10n.nodeNotNearby,
            leading: OneBitIcons.cloudOff,
          )
        else ...[
          OneBitListItem(
            title: l10n.nodeRssiLatest,
            subtitle: connectionStateLabel(l10n, neighbor!.connectionState),
            leading: OneBitIcons.signal,
            trailing: Text(
              '${neighbor!.latestRssiDb} dBm',
              style: OneBitTypography.technicalStyle(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          OneBitListItem(
            title: l10n.nodeRssiSmoothed,
            leading: OneBitIcons.signal,
            trailing: Text(
              '${neighbor!.smoothedRssiDb.toStringAsFixed(1)} dBm',
              style: OneBitTypography.technicalStyle(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (neighbor!.distanceEstimateMeters != null)
            OneBitListItem(
              title: l10n.nodeDistanceLabel,
              leading: OneBitIcons.radar,
              trailing: Text(
                '${neighbor!.distanceEstimateMeters!.toStringAsFixed(1)} m',
                style: OneBitTypography.technicalStyle(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          OneBitListItem(
            title: l10n.nodeHopLabel,
            leading: OneBitIcons.shellMesh,
            trailing: Text(
              '${neighbor!.hopEstimate}',
              style: OneBitTypography.technicalStyle(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          OneBitListItem(
            title: l10n.nodeLinkQuality,
            leading: OneBitIcons.signal,
            trailing: Text(
              '${(neighbor!.linkQuality * 100).round()}%',
              style: OneBitTypography.technicalStyle(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          OneBitListItem(
            title: l10n.nodeFirstSeen,
            leading: OneBitIcons.schedule,
            subtitle: clockLabel(neighbor!.firstSeen),
          ),
          OneBitListItem(
            title: l10n.nodeLastSeen,
            leading: OneBitIcons.schedule,
            subtitle: clockLabel(neighbor!.lastSeen),
          ),
          OneBitListItem(
            title: l10n.nodeCapabilities,
            leading: OneBitIcons.node,
            subtitle: neighbor!.capabilities
                .map((c) => capabilityLabel(l10n, c))
                .join(' · '),
          ),
        ],
      ],
    );
  }
}

/// Route section for a node.
final class NodeRouteSection extends StatelessWidget {
  const NodeRouteSection({
    required this.neighbor,
    required this.l10n,
    super.key,
  });

  final MeshNeighbor? neighbor;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: OneBitSpacing.l),
        OneBitSectionHeader(title: l10n.nodeRouteSection),
        if (neighbor == null)
          OneBitListItem(
            title: l10n.nodeRouteUnavailable,
            leading: OneBitIcons.cloudOff,
          )
        else ...[
          OneBitListItem(
            title: l10n.nodeRouteAvailable,
            leading: OneBitIcons.shellMesh,
            trailing: Text(
              l10n.nodeRouteHopCount(neighbor!.hopEstimate),
              style: OneBitTypography.technicalStyle(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Verification section for a node.
final class NodeVerificationSection extends StatelessWidget {
  const NodeVerificationSection({
    required this.contact,
    required this.l10n,
    required this.onPickTrustLevel,
    required this.onShowVerificationCode,
    super.key,
  });

  final TrustContact? contact;
  final AppLocalizations l10n;
  final VoidCallback onPickTrustLevel;
  final VoidCallback onShowVerificationCode;

  @override
  Widget build(BuildContext context) {
    if (contact == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: OneBitSpacing.l),
        OneBitSectionHeader(title: l10n.nodeVerificationSection),
        OneBitListItem(
          title: l10n.nodeTrustLevelLabel,
          leading: OneBitIcons.verified,
          trailing: OneBitStatusChip.preset(
            verificationPresetFor(contact!.trustLevel)!,
            label: trustLevelLabel(l10n, contact!.trustLevel),
          ),
          onTap: onPickTrustLevel,
          showChevron: true,
        ),
        OneBitListItem(
          title: l10n.nodeShowVerificationCode,
          leading: OneBitIcons.security,
          onTap: onShowVerificationCode,
        ),
      ],
    );
  }
}

/// Capability label helper.
String capabilityLabel(AppLocalizations l10n, MeshCapability capability) =>
    switch (capability) {
      MeshCapability.relay => l10n.nodeCapabilityRelay,
      MeshCapability.router => l10n.nodeCapabilityRouter,
      MeshCapability.storeForward => l10n.nodeCapabilityStoreForward,
    };
