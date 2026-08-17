import 'package:flutter/material.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Nodes-specific settings: node discovery, known node behavior,
/// node visibility, and display preferences.
class NodesSettingsScreen extends StatelessWidget {
  const NodesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.nodesSettingsTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          OneBitSpacing.xxl,
          OneBitSpacing.lg,
          OneBitSpacing.xxl,
          OneBitScrollClearance.bottom(context),
        ),
        children: [
          OneBitSectionHeader(title: l10n.nodesSettingsDiscovery),
          OneBitCard(
            child: _InfoRow(
              icon: OneBitIcons.radar,
              title: l10n.nodesSettingsDiscoveryBehavior,
              subtitle: l10n.nodesSettingsDiscoveryBehaviorDescription,
            ),
          ),
          const SizedBox(height: OneBitSpacing.s),
          OneBitCard(
            child: _InfoRow(
              icon: OneBitIcons.search,
              title: l10n.nodesSettingsRefreshBehavior,
              subtitle: l10n.nodesSettingsRefreshBehaviorDescription,
            ),
          ),

          const SizedBox(height: OneBitSpacing.xxl),
          OneBitSectionHeader(title: l10n.nodesSettingsDisplay),
          OneBitCard(
            child: _InfoRow(
              icon: OneBitIcons.info,
              title: l10n.nodesSettingsVisibility,
              subtitle: l10n.nodesSettingsVisibilityDescription,
            ),
          ),
          const SizedBox(height: OneBitSpacing.s),
          OneBitCard(
            child: _InfoRow(
              icon: OneBitIcons.shellNodes,
              title: l10n.nodesSettingsNaming,
              subtitle: l10n.nodesSettingsNamingDescription,
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
