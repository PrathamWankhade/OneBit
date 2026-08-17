import 'package:flutter/material.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Mesh-specific settings: mesh discovery, relay behavior, routing,
/// network diagnostics, and mesh engine configuration.
class MeshSettingsScreen extends StatelessWidget {
  const MeshSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.meshSettingsTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          OneBitSpacing.xxl,
          OneBitSpacing.lg,
          OneBitSpacing.xxl,
          OneBitScrollClearance.bottom(context),
        ),
        children: [
          OneBitSectionHeader(title: l10n.meshSettingsNetwork),
          OneBitCard(
            child: _InfoRow(
              icon: OneBitIcons.bluetooth,
              title: l10n.meshSettingsDiscovery,
              subtitle: l10n.meshSettingsDiscoveryDescription,
            ),
          ),
          const SizedBox(height: OneBitSpacing.s),
          OneBitCard(
            child: _InfoRow(
              icon: OneBitIcons.signal,
              title: l10n.meshSettingsRouting,
              subtitle: l10n.meshSettingsRoutingDescription,
            ),
          ),

          const SizedBox(height: OneBitSpacing.xxl),
          OneBitSectionHeader(title: l10n.meshSettingsEngine),
          OneBitCard(
            child: _InfoRow(
              icon: OneBitIcons.storage,
              title: l10n.meshSettingsEngineBehavior,
              subtitle: l10n.meshSettingsEngineBehaviorDescription,
            ),
          ),
          const SizedBox(height: OneBitSpacing.s),
          OneBitCard(
            child: _InfoRow(
              icon: OneBitIcons.info,
              title: l10n.meshSettingsDiagnostics,
              subtitle: l10n.meshSettingsDiagnosticsDescription,
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
