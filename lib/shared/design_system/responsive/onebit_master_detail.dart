import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/responsive/onebit_responsive.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Master-detail layout for tablets and expanded viewports.
///
/// On compact screens, shows only [master]. On medium/expanded screens,
/// shows [master] alongside [detail] in a side-by-side layout.
/// When [selectedIndex] is non-null on compact, navigates to detail;
/// on tablets, the detail pane is always visible.
class OneBitMasterDetail extends StatelessWidget {
  const OneBitMasterDetail({
    required this.master,
    required this.detail,
    this.selectedIndex,
    this.masterWidth = 360,
    this.dividerWidth = 1,
    super.key,
  });

  /// The master list pane.
  final Widget master;

  /// The detail pane shown when a selection is active.
  final Widget detail;

  /// Index of the selected item; null shows placeholder on tablets.
  final int? selectedIndex;

  /// Width of the master pane on tablets.
  final double masterWidth;

  /// Width of the divider between panes.
  final double dividerWidth;

  @override
  Widget build(BuildContext context) {
    return switch (context.breakpoint) {
      OneBitBreakpoint.compact => master,
      OneBitBreakpoint.medium || OneBitBreakpoint.expanded => Row(
        children: [
          SizedBox(width: masterWidth, child: master),
          Container(
            width: dividerWidth,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(child: detail),
        ],
      ),
    };
  }
}

/// Responsive grid that adapts column count to viewport width.
///
/// On compact screens, renders a single column. On medium, renders 2 columns.
/// On expanded, renders 3 columns. Cards reflow naturally.
class OneBitResponsiveGrid extends StatelessWidget {
  const OneBitResponsiveGrid({
    required this.children,
    this.compactColumns = 1,
    this.mediumColumns = 2,
    this.expandedColumns = 3,
    this.spacing = OneBitSpacing.m,
    this.runSpacing = OneBitSpacing.m,
    this.padding = const EdgeInsets.all(OneBitSpacing.m),
    super.key,
  });

  /// The grid items.
  final List<Widget> children;

  /// Number of columns on compact viewports.
  final int compactColumns;

  /// Number of columns on medium viewports.
  final int mediumColumns;

  /// Number of columns on expanded viewports.
  final int expandedColumns;

  /// Horizontal spacing between columns.
  final double spacing;

  /// Vertical spacing between rows.
  final double runSpacing;

  /// Outer padding around the grid.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final columns = switch (context.breakpoint) {
      OneBitBreakpoint.compact => compactColumns,
      OneBitBreakpoint.medium => mediumColumns,
      OneBitBreakpoint.expanded => expandedColumns,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Padding(
          padding: padding,
          child: Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            children: [
              for (final child in children)
                SizedBox(width: itemWidth, child: child),
            ],
          ),
        );
      },
    );
  }
}
