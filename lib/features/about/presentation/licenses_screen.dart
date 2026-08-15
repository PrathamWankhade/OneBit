import 'package:flutter/material.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Open-source licenses: delegates to Flutter's built-in license registry
/// with a clean OneBit presentation.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.licensesTitle)),
      body: ListView(
        padding: const EdgeInsets.all(OneBitSpacing.m),
        children: [
          OneBitSectionHeader(title: l10n.licensesOneBitTitle),
          OneBitCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      OneBitIcons.info,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: OneBitSpacing.m),
                    Expanded(
                      child: Text(
                        'OneBit',
                        style: context.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: OneBitSpacing.s),
                Text(
                  'Copyright (c) 2026 OneBit contributors. '
                  'Released under the MIT License.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: OneBitSpacing.xl),
          OneBitSectionHeader(title: l10n.licensesFlutterTitle),
          OneBitCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  OneBitIcons.licenses,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: OneBitSpacing.m),
                Expanded(
                  child: Text(
                    'View all open-source packages used by OneBit and their '
                    'respective licenses.',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: OneBitSpacing.m),
          Center(
            child: TextButton.icon(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'OneBit',
                applicationVersion: '',
                applicationLegalese: 'Copyright (c) 2026 OneBit contributors',
              ),
              icon: const Icon(OneBitIcons.licenses),
              label: Text(l10n.aboutLicenses),
            ),
          ),
        ],
      ),
    );
  }
}
