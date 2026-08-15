import 'package:flutter/material.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Notification settings: display-only information about notification
/// configuration. Actual notification rules arrive with the messaging phase.
class NotificationsSettingsScreen extends StatelessWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.settingsNotificationsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(OneBitSpacing.m),
        children: [
          OneBitSectionHeader(title: l10n.settingsNotificationsTitle),
          OneBitCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  OneBitIcons.notifications,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: OneBitSpacing.m),
                Expanded(
                  child: Text(
                    l10n.settingsNotificationsDescription,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
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
