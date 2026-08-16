import 'package:flutter/material.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/components/onebit_settings_card.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Notification settings: display-only information about notification
/// configuration. Actual notification rules arrive with the messaging phase.
class NotificationsSettingsScreen extends StatelessWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.settingsNotificationsTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          24,
          OneBitSpacing.m,
          24,
          OneBitScrollClearance.bottom(context),
        ),
        children: [
          OneBitSectionHeader(title: l10n.settingsNotificationsTitle),
          OneBitSettingsCard(
            icon: OneBitIcons.notifications,
            title: l10n.settingsNotificationsTitle,
            subtitle: l10n.settingsNotificationsDescription,
          ),
        ],
      ),
    );
  }
}
