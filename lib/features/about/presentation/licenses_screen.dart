import 'package:flutter/material.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/components/onebit_settings_card.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Open-source licenses: delegates to Flutter's built-in license registry
/// with a clean OneBit presentation.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.licensesTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          OneBitSpacing.xxl,
          OneBitSpacing.lg,
          OneBitSpacing.xxl,
          OneBitScrollClearance.bottom(context),
        ),
        children: [
          OneBitSectionHeader(title: l10n.licensesOneBitTitle),
          OneBitSettingsCard(
            icon: OneBitIcons.info,
            title: 'OneBit',
            subtitle: '${l10n.licensesCopyright}. '
                'Released under the MIT License.',
          ),
          const SizedBox(height: OneBitSpacing.xl),
          OneBitSectionHeader(title: l10n.licensesFlutterTitle),
          OneBitSettingsCard(
            icon: OneBitIcons.licenses,
            title: l10n.licensesFlutterTitle,
            subtitle: l10n.licensesSubtitle,
          ),
          const SizedBox(height: OneBitSpacing.lg),
          Center(
            child: OneBitButton(
              label: l10n.aboutLicenses,
              icon: OneBitIcons.licenses,
              variant: OneBitButtonVariant.text,
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'OneBit',
                applicationVersion: '',
                applicationLegalese: 'Copyright (c) 2026 OneBit contributors',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
