import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/routing/providers/routing_diagnostics_provider.dart';
import 'package:onebit/features/routing/ui/widgets/dashboard_widgets.dart';
import 'package:onebit/features/routing/ui/widgets/diagnostics_widgets.dart';
import 'package:onebit/features/routing/ui/widgets/peer_widgets.dart';
import 'package:onebit/features/routing/ui/widgets/route_widgets.dart';
import 'package:onebit/features/routing/ui/widgets/topology_widgets.dart';

class RoutingDiagnosticsScreen extends ConsumerStatefulWidget {
  const RoutingDiagnosticsScreen({super.key});

  @override
  ConsumerState<RoutingDiagnosticsScreen> createState() =>
      _RoutingDiagnosticsScreenState();
}

class _RoutingDiagnosticsScreenState
    extends ConsumerState<RoutingDiagnosticsScreen> {
  int _selectedPeerIndex = -1;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(routingDiagnosticsProvider);

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: AppTheme.bgBase,
        appBar: AppBar(
          backgroundColor: AppTheme.bgBase,
          title: Text(
            'Routing Diagnostics',
            style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppTheme.accent,
            unselectedLabelColor: AppTheme.textTertiary,
            indicatorColor: AppTheme.accent,
            labelStyle: AppTheme.caption.copyWith(color: AppTheme.accent),
            unselectedLabelStyle:
                AppTheme.caption.copyWith(color: AppTheme.textTertiary),
            tabs: const [
              Tab(text: 'Dashboard'),
              Tab(text: 'Topology'),
              Tab(text: 'Routes'),
              Tab(text: 'Peers'),
              Tab(text: 'Security'),
              Tab(text: 'Logs'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() {}),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: TabBarView(
          children: [
            DashboardOverview(snapshot: snapshot),
            _TopologyTab(snapshot: snapshot),
            _RoutesTab(snapshot: snapshot),
            _PeersTab(
              snapshot: snapshot,
              selectedIndex: _selectedPeerIndex,
              onSelected: (index) =>
                  setState(() => _selectedPeerIndex = index),
            ),
            _SecurityTab(snapshot: snapshot),
            _LogsTab(snapshot: snapshot),
          ],
        ),
      ),
    );
  }
}

class _TopologyTab extends StatelessWidget {
  const _TopologyTab({required this.snapshot});

  final DiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: AppTheme.bgElevated,
            child: TabBar(
              labelColor: AppTheme.accent,
              unselectedLabelColor: AppTheme.textTertiary,
              indicatorColor: AppTheme.accent,
              labelStyle: AppTheme.caption.copyWith(color: AppTheme.accent),
              unselectedLabelStyle:
                  AppTheme.caption.copyWith(color: AppTheme.textTertiary),
              tabs: const [
                Tab(text: 'List'),
                Tab(text: 'Matrix'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                TopologyListView(snapshot: snapshot),
                ReachabilityMatrix(snapshot: snapshot),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutesTab extends StatelessWidget {
  const _RoutesTab({required this.snapshot});

  final DiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: AppTheme.bgElevated,
            child: TabBar(
              labelColor: AppTheme.accent,
              unselectedLabelColor: AppTheme.textTertiary,
              indicatorColor: AppTheme.accent,
              labelStyle: AppTheme.caption.copyWith(color: AppTheme.accent),
              unselectedLabelStyle:
                  AppTheme.caption.copyWith(color: AppTheme.textTertiary),
              tabs: const [
                Tab(text: 'Routes'),
                Tab(text: 'Expiration'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                RouteTableViewer(snapshot: snapshot),
                ExpirationMonitor(snapshot: snapshot),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeersTab extends StatelessWidget {
  const _PeersTab({
    required this.snapshot,
    required this.selectedIndex,
    required this.onSelected,
  });

  final DiagnosticsSnapshot snapshot;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (selectedIndex >= 0 && selectedIndex < snapshot.neighbors.length) {
      final peerId = snapshot.neighbors[selectedIndex].peerId;
      return PeerInspector(peerId: peerId, snapshot: snapshot);
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: AppTheme.bgElevated,
            child: TabBar(
              labelColor: AppTheme.accent,
              unselectedLabelColor: AppTheme.textTertiary,
              indicatorColor: AppTheme.accent,
              labelStyle: AppTheme.caption.copyWith(color: AppTheme.accent),
              unselectedLabelStyle:
                  AppTheme.caption.copyWith(color: AppTheme.textTertiary),
              tabs: const [
                Tab(text: 'Neighbors'),
                Tab(text: 'Timeline'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                NeighborDiagnosticsView(snapshot: snapshot),
                PeerTimeline(snapshot: snapshot),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityTab extends StatelessWidget {
  const _SecurityTab({required this.snapshot});

  final DiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: AppTheme.bgElevated,
            child: TabBar(
              labelColor: AppTheme.accent,
              unselectedLabelColor: AppTheme.textTertiary,
              indicatorColor: AppTheme.accent,
              labelStyle: AppTheme.caption.copyWith(color: AppTheme.accent),
              unselectedLabelStyle:
                  AppTheme.caption.copyWith(color: AppTheme.textTertiary),
              tabs: const [
                Tab(text: 'Security'),
                Tab(text: 'Recovery'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                SecurityDiagnosticsView(snapshot: snapshot),
                RecoveryDiagnosticsView(snapshot: snapshot),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogsTab extends StatelessWidget {
  const _LogsTab({required this.snapshot});

  final DiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: AppTheme.bgElevated,
            child: TabBar(
              labelColor: AppTheme.accent,
              unselectedLabelColor: AppTheme.textTertiary,
              indicatorColor: AppTheme.accent,
              labelStyle: AppTheme.caption.copyWith(color: AppTheme.accent),
              unselectedLabelStyle:
                  AppTheme.caption.copyWith(color: AppTheme.textTertiary),
              tabs: const [
                Tab(text: 'Logs'),
                Tab(text: 'Performance'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                Column(
                  children: [
                    Expanded(child: LogViewer(snapshot: snapshot)),
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: ExportDiagnosticsButton(),
                    ),
                  ],
                ),
                PerformancePanel(snapshot: snapshot),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
