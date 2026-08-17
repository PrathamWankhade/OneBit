import 'package:flutter/material.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Nearby-specific settings: Bluetooth discovery behavior, scan preferences,
/// and nearby visibility options.
class NearbySettingsScreen extends StatelessWidget {
  const NearbySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.nearbySettingsTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          OneBitSpacing.xxl,
          OneBitSpacing.lg,
          OneBitSpacing.xxl,
          OneBitScrollClearance.bottom(context),
        ),
        children: [
          OneBitSectionHeader(title: l10n.nearbySettingsDiscovery),
          OneBitCard(
            child: _InfoRow(
              icon: OneBitIcons.bluetooth,
              title: l10n.nearbySettingsDiscoveryBehavior,
              subtitle: l10n.nearbySettingsDiscoveryBehaviorDescription,
            ),
          ),
          const SizedBox(height: OneBitSpacing.s),
          OneBitCard(
            child: _InfoRow(
              icon: OneBitIcons.radar,
              title: l10n.nearbySettingsScanBehavior,
              subtitle: l10n.nearbySettingsScanBehaviorDescription,
            ),
          ),

          const SizedBox(height: OneBitSpacing.xxl),
          OneBitSectionHeader(title: l10n.nearbySettingsVisibility),
          OneBitCard(
            child: _InfoRow(
              icon: OneBitIcons.info,
              title: l10n.nearbySettingsNearbyVisibility,
              subtitle: l10n.nearbySettingsNearbyVisibilityDescription,
            ),
          ),
          const SizedBox(height: OneBitSpacing.s),
          OneBitCard(
            child: _InfoRow(
              icon: OneBitIcons.notifications,
              title: l10n.nearbySettingsAnnouncementBehavior,
              subtitle: l10n.nearbySettingsAnnouncementBehaviorDescription,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: OneBitSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.textTheme.titleSmall),
              const SizedBox(height: OneBitSpacing.xs),
              Text(
                subtitle,
                style: context.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
