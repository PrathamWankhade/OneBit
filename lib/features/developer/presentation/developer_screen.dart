import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_panel.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/components/onebit_terminal_line.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Developer tools hub: central access point for all developer screens.
/// Accessed only after developer mode is unlocked (7 taps on version).
class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.devHubTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          OneBitSpacing.m,
          OneBitSpacing.m,
          OneBitSpacing.m,
          OneBitScrollClearance.bottom(context),
        ),
        children: [
          OneBitPanel(
            padding: const EdgeInsets.all(OneBitSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OneBitTerminalLine(
                  status: OneBitTerminalStatus.info,
                  message: 'DEVELOPER MODE ACTIVE',
                ),
                const SizedBox(height: OneBitSpacing.xs),
                OneBitTerminalLine(
                  status: OneBitTerminalStatus.ok,
                  message: l10n.devHubSubtitle,
                ),
              ],
            ),
          ),
          const SizedBox(height: OneBitSpacing.m),
          const OneBitSectionHeader(title: 'Inspection'),
          _ToolTile(
            icon: OneBitIcons.shellMesh,
            title: l10n.devPacketInspector,
            subtitle: l10n.devPacketInspectorDesc,
            path: AppRoutePaths.packetDebug,
          ),
          const SizedBox(height: OneBitSpacing.s),
          _ToolTile(
            icon: OneBitIcons.shellMesh,
            title: l10n.devMeshInspector,
            subtitle: l10n.devMeshInspectorDesc,
            path: AppRoutePaths.meshDebug,
          ),
          const SizedBox(height: OneBitSpacing.xl),
          const OneBitSectionHeader(title: 'System'),
          _ToolTile(
            icon: OneBitIcons.shellDeveloper,
            title: l10n.devLogs,
            subtitle: l10n.devLogsDesc,
            path: AppRoutePaths.logs,
          ),
          const SizedBox(height: OneBitSpacing.s),
          _ToolTile(
            icon: OneBitIcons.storage,
            title: l10n.devDatabaseViewer,
            subtitle: l10n.devDatabaseViewerDesc,
            path: AppRoutePaths.databaseViewer,
          ),
          const SizedBox(height: OneBitSpacing.xl),
          const OneBitSectionHeader(title: 'Analysis'),
          _ToolTile(
            icon: OneBitIcons.shellDeveloper,
            title: l10n.devStatistics,
            subtitle: l10n.devStatisticsDesc,
            path: AppRoutePaths.statistics,
          ),
          const SizedBox(height: OneBitSpacing.s),
          _ToolTile(
            icon: OneBitIcons.shellDeveloper,
            title: l10n.devPerformance,
            subtitle: l10n.devPerformanceDesc,
            path: AppRoutePaths.performance,
          ),
          const SizedBox(height: OneBitSpacing.s),
          _ToolTile(
            icon: OneBitIcons.shellDeveloper,
            title: l10n.devDiagnosticsTitle,
            subtitle: l10n.devDiagnosticsDesc,
            path: AppRoutePaths.diagnostics,
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.path,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String path;

  @override
  Widget build(BuildContext context) {
    return OneBitCard(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: context.textTheme.titleSmall),
        subtitle: Text(subtitle, style: context.textTheme.bodySmall),
        trailing: const Icon(OneBitIcons.chevronRight),
        onTap: () => context.push(path),
      ),
    );
  }
}
