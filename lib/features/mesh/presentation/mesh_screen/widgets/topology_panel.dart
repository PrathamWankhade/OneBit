import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/features/mesh/domain/mesh_topology.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Topology visualization panel.
final class TopologyVisualizationPanel extends ConsumerWidget {
  const TopologyVisualizationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final topoAsync = ref.watch(meshTopologyProvider);

    return topoAsync.when(
      loading: () => const OneBitCard(child: OneBitLoadingIndicator(label: '')),
      error: (e, _) => OneBitCard(
        child: Text(l10n.commonError, style: context.textTheme.bodyMedium),
      ),
      data: (result) {
        if (result.isErr || result.value == null) {
          return const SizedBox.shrink();
        }
        final topo = result.value!;
        if (topo.nodes.isEmpty) {
          return const SizedBox.shrink();
        }
        return TopologyGraph(
          nodes: topo.nodes,
          links: topo.links,
          partitions: topo.partitions,
        );
      },
    );
  }
}

/// Renders the topology graph with nodes and links.
final class TopologyGraph extends StatelessWidget {
  const TopologyGraph({
    required this.nodes,
    required this.links,
    required this.partitions,
    super.key,
  });

  final List<TopologyNode> nodes;
  final List<TopologyLink> links;
  final int partitions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.oneBitColors;

    return OneBitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.meshVisualizationTitle,
                  style: context.textTheme.titleMedium,
                ),
              ),
              Text(
                '${nodes.length} nodes · ${links.length} links',
                style: OneBitTypography.oneBitCaption(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: OneBitSpacing.sm),
          SizedBox(
            height: 180,
            child: Padding(
              padding: const EdgeInsets.all(OneBitSpacing.xs),
              child: CustomPaint(
                size: const Size(double.infinity, 180),
                painter: TopologyPainter(
                  nodes: nodes,
                  links: links,
                  nodeColor: scheme.onSurface,
                  linkColor: scheme.outlineVariant,
                  localNodeColor: colors.success,
                  qualityColor: colors.info,
                ),
              ),
            ),
          ),
          if (partitions > 1) ...[
            const SizedBox(height: OneBitSpacing.xs),
            Text(
              '$partitions ${l10n.meshPartitionsLabel}',
              style: OneBitTypography.oneBitCaption(
                color: colors.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Custom painter for the topology graph.
final class TopologyPainter extends CustomPainter {
  TopologyPainter({
    required this.nodes,
    required this.links,
    required this.nodeColor,
    required this.linkColor,
    required this.localNodeColor,
    required this.qualityColor,
  });

  final List<TopologyNode> nodes;
  final List<TopologyLink> links;
  final Color nodeColor;
  final Color linkColor;
  final Color localNodeColor;
  final Color qualityColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;

    final positions = _layoutNodes(nodes, size);

    final linkPaint = Paint()
      ..color = linkColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final link in links) {
      final aIdx = nodes.indexWhere((n) => n.nodeId == link.nodeA);
      final bIdx = nodes.indexWhere((n) => n.nodeId == link.nodeB);
      if (aIdx < 0 || bIdx < 0) continue;
      final a = positions[aIdx];
      final b = positions[bIdx];

      final opacity = (link.quality * 0.8 + 0.2).clamp(0.0, 1.0);
      linkPaint.color = linkColor.withAlpha((opacity * 255).round());
      canvas.drawLine(a, b, linkPaint);
    }

    final nodePaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final pos = positions[i];
      final radius = node.isLocal ? 8.0 : 5.0;

      nodePaint.color = node.isLocal ? localNodeColor : nodeColor;
      canvas.drawCircle(pos, radius, nodePaint);

      if (!node.isLocal) {
        final borderPaint = Paint()
          ..color = nodeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawCircle(pos, radius, borderPaint);
      }
    }
  }

  List<Offset> _layoutNodes(List<TopologyNode> nodes, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final positions = <Offset>[];

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node.isLocal) {
        positions.add(center);
      } else {
        final angle = (2 * 3.14159 * i) / nodes.length;
        final radius = size.shortestSide * 0.35;
        positions.add(
          Offset(
            center.dx + radius * _cos(angle),
            center.dy + radius * _sin(angle),
          ),
        );
      }
    }
    return positions;
  }

  double _cos(double angle) => _cosImpl(angle);
  double _sin(double angle) => _sinImpl(angle);

  static double _cosImpl(double x) {
    final normalized = x % (2 * 3.141592653589793);
    return _cosNearZero(normalized);
  }

  static double _sinImpl(double x) => _cosImpl(x - 3.141592653589793 / 2);

  static double _cosNearZero(double x) {
    if (x < 0) return _cosNearZero(-x);
    if (x > 3.141592653589793) return -_cosNearZero(2 * 3.141592653589793 - x);
    final x2 = x * x;
    return 1 - x2 / 2 + x2 * x2 / 24 - x2 * x2 * x2 / 720;
  }

  @override
  bool shouldRepaint(TopologyPainter oldDelegate) =>
      nodes != oldDelegate.nodes || links != oldDelegate.links;
}
