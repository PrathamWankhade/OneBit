import 'package:flutter/material.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Privacy & security information: encryption, identity, local storage,
/// no-server architecture. Read-only display of the system's guarantees.
class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.settingsPrivacyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(OneBitSpacing.m),
        children: [
          OneBitSectionHeader(title: l10n.settingsPrivacyIdentityPrivacy),
          _InfoTile(
            icon: OneBitIcons.security,
            title: l10n.settingsPrivacyE2eLabel,
            message: l10n.settingsPrivacyE2eDescription,
          ),
          const SizedBox(height: OneBitSpacing.s),
          _InfoTile(
            icon: OneBitIcons.fingerprint,
            title: l10n.settingsPrivacyIdentityLabel,
            message: l10n.settingsPrivacyIdentityDescription,
          ),
          const SizedBox(height: OneBitSpacing.s),
          _InfoTile(
            icon: OneBitIcons.node,
            title: l10n.settingsPrivacySecureStorage,
            message: l10n.settingsPrivacySecureStorageDescription,
          ),
          const SizedBox(height: OneBitSpacing.xl),
          OneBitSectionHeader(title: l10n.settingsPrivacyMetadata),
          _InfoTile(
            icon: OneBitIcons.info,
            title: l10n.settingsPrivacyMetadata,
            message: l10n.settingsPrivacyMetadataDescription,
          ),
          const SizedBox(height: OneBitSpacing.s),
          _InfoTile(
            icon: OneBitIcons.nodeActive,
            title: l10n.settingsPrivacyNodeVisibility,
            message: l10n.settingsPrivacyNodeVisibilityDescription,
          ),
          const SizedBox(height: OneBitSpacing.xl),
          OneBitSectionHeader(title: l10n.settingsPrivacyVerification),
          _InfoTile(
            icon: OneBitIcons.verified,
            title: l10n.settingsPrivacyVerification,
            message: l10n.settingsPrivacyVerificationDescription,
          ),
          const SizedBox(height: OneBitSpacing.xl),
          OneBitSectionHeader(title: l10n.settingsStorage),
          _InfoTile(
            icon: OneBitIcons.storage,
            title: l10n.settingsPrivacyLocalStorageLabel,
            message: l10n.settingsPrivacyLocalStorageDescription,
          ),
          const SizedBox(height: OneBitSpacing.s),
          _InfoTile(
            icon: OneBitIcons.cloudOff,
            title: l10n.settingsPrivacyNoServerLabel,
            message: l10n.settingsPrivacyNoServerDescription,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return OneBitCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: OneBitSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.textTheme.titleSmall),
                const SizedBox(height: OneBitSpacing.xs),
                Text(
                  message,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
