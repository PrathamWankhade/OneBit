import 'package:flutter/material.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/components/onebit_settings_card.dart';
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
        padding: EdgeInsets.fromLTRB(
          24,
          OneBitSpacing.m,
          24,
          OneBitScrollClearance.bottom(context),
        ),
        children: [
          OneBitSectionHeader(title: l10n.settingsPrivacyIdentityPrivacy),
          OneBitSettingsCard(
            icon: OneBitIcons.security,
            title: l10n.settingsPrivacyE2eLabel,
            subtitle: l10n.settingsPrivacyE2eDescription,
          ),
          const SizedBox(height: OneBitSpacing.s),
          OneBitSettingsCard(
            icon: OneBitIcons.fingerprint,
            title: l10n.settingsPrivacyIdentityLabel,
            subtitle: l10n.settingsPrivacyIdentityDescription,
          ),
          const SizedBox(height: OneBitSpacing.s),
          OneBitSettingsCard(
            icon: OneBitIcons.node,
            title: l10n.settingsPrivacySecureStorage,
            subtitle: l10n.settingsPrivacySecureStorageDescription,
          ),
          const SizedBox(height: OneBitSpacing.xl),
          OneBitSectionHeader(title: l10n.settingsPrivacyMetadata),
          OneBitSettingsCard(
            icon: OneBitIcons.info,
            title: l10n.settingsPrivacyMetadata,
            subtitle: l10n.settingsPrivacyMetadataDescription,
          ),
          const SizedBox(height: OneBitSpacing.s),
          OneBitSettingsCard(
            icon: OneBitIcons.nodeActive,
            title: l10n.settingsPrivacyNodeVisibility,
            subtitle: l10n.settingsPrivacyNodeVisibilityDescription,
          ),
          const SizedBox(height: OneBitSpacing.xl),
          OneBitSectionHeader(title: l10n.settingsPrivacyVerification),
          OneBitSettingsCard(
            icon: OneBitIcons.verified,
            title: l10n.settingsPrivacyVerification,
            subtitle: l10n.settingsPrivacyVerificationDescription,
          ),
          const SizedBox(height: OneBitSpacing.xl),
          OneBitSectionHeader(title: l10n.settingsStorage),
          OneBitSettingsCard(
            icon: OneBitIcons.storage,
            title: l10n.settingsPrivacyLocalStorageLabel,
            subtitle: l10n.settingsPrivacyLocalStorageDescription,
          ),
          const SizedBox(height: OneBitSpacing.s),
          OneBitSettingsCard(
            icon: OneBitIcons.cloudOff,
            title: l10n.settingsPrivacyNoServerLabel,
            subtitle: l10n.settingsPrivacyNoServerDescription,
          ),
        ],
      ),
    );
  }
}
