import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/routing/providers/routing_diagnostics_provider.dart';
import 'package:onebit/features/routing/reachability_reason.dart';
import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/routing_security.dart';
import 'package:onebit/features/routing/ui/widgets/dashboard_widgets.dart';
import 'package:onebit/features/routing/ui/widgets/diagnostics_widgets.dart';
import 'package:onebit/features/routing/ui/widgets/peer_widgets.dart';
import 'package:onebit/features/routing/ui/widgets/route_widgets.dart';
import 'package:onebit/features/routing/ui/widgets/topology_widgets.dart';

DiagnosticsSnapshot _emptySnapshot() {
  return DiagnosticsSnapshot(
    neighborCount: 0,
    reachablePeerCount: 0,
    topologySourceCount: 0,
    activeRouteCount: 0,
    securityEventCount: 0,
    neighbors: const [],
    reachablePeers: const [],
    topologyEntries: const [],
    routes: const [],
    securityEvents: const [],
    recoveringDestinations: const [],
    generatedAt: DateTime(2025),
  );
}

DiagnosticsSnapshot _populatedSnapshot() {
  return DiagnosticsSnapshot(
    neighborCount: 3,
    reachablePeerCount: 2,
    topologySourceCount: 2,
    activeRouteCount: 2,
    securityEventCount: 3,
    neighbors: [
      const NeighborDiagnostics(
        peerId: 'aaa1111111111111111111111111111111111111111111111111111111111111',
        isActive: true,
        isReachable: true,
        reachabilityReason: ReachabilityReason.reachable,
      ),
      const NeighborDiagnostics(
        peerId: 'bbb2222222222222222222222222222222222222222222222222222222222222',
        isActive: true,
        isReachable: false,
        reachabilityReason: ReachabilityReason.notConnected,
      ),
    ],
    reachablePeers: [
      'aaa1111111111111111111111111111111111111111111111111111111111111',
    ],
    topologyEntries: [
      TopologyEntryDiagnostics(
        sourceIdentity: 'aaa1111111111111111111111111111111111111111111111111111111111111',
        neighborCount: 2,
        sequence: 5,
        receivedAt: DateTime(2025),
      ),
    ],
    routes: [
      RouteDiagnostics(
        destinationPeerId: 'ccc3333333333333333333333333333333333333333333333333333333333333',
        nextHopPeerId: 'aaa1111111111111111111111111111111111111111111111111111111111111',
        metric: 2,
        state: RouteState.active,
        source: RouteSource.advertised,
        expiresAt: DateTime(2025, 1, 1, 0, 0, 30),
      ),
    ],
    securityEvents: [
      const SecurityEventDiagnostics(
        peerId: 'aaa1111111111111111111111111111111111111111111111111111111111111',
        event: RoutingSecurityEvent.validationPassed,
      ),
      const SecurityEventDiagnostics(
        peerId: 'bbb2222222222222222222222222222222222222222222222222222222222222',
        event: RoutingSecurityEvent.senderIdentityMismatch,
      ),
    ],
    recoveringDestinations: [],
    generatedAt: DateTime(2025),
  );
}

Widget _wrap(Widget child, {DiagnosticsSnapshot? snapshot}) {
  return ProviderScope(
    overrides: [
      if (snapshot != null)
        routingDiagnosticsProvider.overrideWithValue(snapshot),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('DashboardOverview', () {
    testWidgets('renders with empty snapshot', (tester) async {
      await tester.pumpWidget(
        _wrap(DashboardOverview(snapshot: _emptySnapshot())),
      );
      expect(find.text('Routing Health'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(5));
    });

    testWidgets('renders with populated snapshot', (tester) async {
      final snapshot = _populatedSnapshot();
      await tester.pumpWidget(
        _wrap(DashboardOverview(snapshot: snapshot)),
      );
      expect(find.text('3'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('Neighbors'), findsOneWidget);
      expect(find.text('Reachable Peers'), findsOneWidget);
      expect(find.text('Active Routes'), findsOneWidget);
    });

    testWidgets('shows all five summary cards', (tester) async {
      await tester.pumpWidget(
        _wrap(DashboardOverview(snapshot: _emptySnapshot())),
      );
      expect(find.text('Neighbors'), findsOneWidget);
      expect(find.text('Reachable Peers'), findsOneWidget);
      expect(find.text('Topology Sources'), findsOneWidget);
      expect(find.text('Active Routes'), findsOneWidget);
      expect(find.text('Security Events'), findsOneWidget);
    });
  });

  group('TopologyListView', () {
    testWidgets('shows empty state', (tester) async {
      await tester.pumpWidget(
        _wrap(TopologyListView(snapshot: _emptySnapshot())),
      );
      expect(find.text('No Topology Data'), findsOneWidget);
    });

    testWidgets('shows topology entries', (tester) async {
      await tester.pumpWidget(
        _wrap(TopologyListView(snapshot: _populatedSnapshot())),
      );
      expect(find.text('Topology Sources (1)'), findsOneWidget);
      expect(find.text('2 neighbors'), findsOneWidget);
    });
  });

  group('ReachabilityMatrix', () {
    testWidgets('shows empty state', (tester) async {
      await tester.pumpWidget(
        _wrap(ReachabilityMatrix(snapshot: _emptySnapshot())),
      );
      expect(find.text('No Reachability Data'), findsOneWidget);
    });

    testWidgets('shows matrix with peers', (tester) async {
      await tester.pumpWidget(
        _wrap(ReachabilityMatrix(snapshot: _populatedSnapshot())),
      );
      expect(find.text('Reachability Matrix'), findsOneWidget);
    });
  });

  group('NeighborDiagnosticsView', () {
    testWidgets('shows empty state', (tester) async {
      await tester.pumpWidget(
        _wrap(NeighborDiagnosticsView(snapshot: _emptySnapshot())),
      );
      expect(find.text('No Neighbors'), findsOneWidget);
    });

    testWidgets('shows neighbor cards', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NeighborDiagnosticsView(snapshot: _populatedSnapshot()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Reachable'), findsWidgets);
    });
  });

  group('RouteTableViewer', () {
    testWidgets('shows empty state', (tester) async {
      await tester.pumpWidget(
        _wrap(RouteTableViewer(snapshot: _emptySnapshot())),
      );
      expect(find.text('No Routes'), findsOneWidget);
    });

    testWidgets('shows route tiles', (tester) async {
      await tester.pumpWidget(
        _wrap(RouteTableViewer(snapshot: _populatedSnapshot())),
      );
      expect(find.text('Routes (1)'), findsOneWidget);
      expect(find.textContaining('via'), findsOneWidget);
    });
  });

  group('ExpirationMonitor', () {
    testWidgets('shows empty state when no expiring routes', (tester) async {
      await tester.pumpWidget(
        _wrap(ExpirationMonitor(snapshot: _emptySnapshot())),
      );
      expect(find.text('No Expiring Routes'), findsOneWidget);
    });

    testWidgets('shows expiring routes', (tester) async {
      await tester.pumpWidget(
        _wrap(ExpirationMonitor(snapshot: _populatedSnapshot())),
      );
      expect(find.textContaining('Expiration Monitor'), findsOneWidget);
    });
  });

  group('SecurityDiagnosticsView', () {
    testWidgets('shows empty state', (tester) async {
      await tester.pumpWidget(
        _wrap(SecurityDiagnosticsView(snapshot: _emptySnapshot())),
      );
      expect(find.text('No Security Events'), findsOneWidget);
    });

    testWidgets('shows security events', (tester) async {
      await tester.pumpWidget(
        _wrap(SecurityDiagnosticsView(snapshot: _populatedSnapshot())),
      );
      expect(find.text('Validation Passed'), findsOneWidget);
      expect(find.text('Sender Identity Mismatch'), findsOneWidget);
    });
  });

  group('RecoveryDiagnosticsView', () {
    testWidgets('shows empty state', (tester) async {
      await tester.pumpWidget(
        _wrap(RecoveryDiagnosticsView(snapshot: _emptySnapshot())),
      );
      expect(find.text('No Active Recovery'), findsOneWidget);
    });

    testWidgets('shows recovering destinations', (tester) async {
      final snapshot = DiagnosticsSnapshot(
        neighborCount: 0,
        reachablePeerCount: 0,
        topologySourceCount: 0,
        activeRouteCount: 0,
        securityEventCount: 0,
        neighbors: const [],
        reachablePeers: const [],
        topologyEntries: const [],
        routes: const [],
        securityEvents: const [],
        recoveringDestinations: const ['peer123'],
        generatedAt: DateTime(2025),
      );
      await tester.pumpWidget(
        _wrap(RecoveryDiagnosticsView(snapshot: snapshot)),
      );
      expect(find.textContaining('Recovering'), findsOneWidget);
    });
  });

  group('PerformancePanel', () {
    testWidgets('renders metrics', (tester) async {
      await tester.pumpWidget(
        _wrap(PerformancePanel(snapshot: _populatedSnapshot())),
      );
      expect(find.text('Performance Metrics'), findsOneWidget);
      expect(find.text('Neighbors'), findsOneWidget);
      expect(find.text('3'), findsWidgets);
    });
  });

  group('LogViewer', () {
    testWidgets('renders with empty events', (tester) async {
      await tester.pumpWidget(
        _wrap(LogViewer(snapshot: _emptySnapshot())),
      );
      expect(find.text('No matching events'), findsOneWidget);
    });

    testWidgets('renders with events', (tester) async {
      await tester.pumpWidget(
        _wrap(LogViewer(snapshot: _populatedSnapshot())),
      );
      expect(find.byType(FilterChip), findsNWidgets(4));
    });

    testWidgets('search filters events', (tester) async {
      await tester.pumpWidget(
        _wrap(LogViewer(snapshot: _populatedSnapshot())),
      );
      await tester.enterText(find.byType(TextField), 'aaa');
      await tester.pumpAndSettle();
      expect(find.text('validationPassed'), findsOneWidget);
    });
  });

  group('ExportDiagnosticsButton', () {
    testWidgets('renders button', (tester) async {
      await tester.pumpWidget(
        _wrap(const ExportDiagnosticsButton()),
      );
      expect(find.text('Export Diagnostics'), findsOneWidget);
    });
  });

  group('PeerTimeline', () {
    testWidgets('shows empty state', (tester) async {
      await tester.pumpWidget(
        _wrap(PeerTimeline(snapshot: _emptySnapshot())),
      );
      expect(find.text('No Events'), findsOneWidget);
    });

    testWidgets('shows events', (tester) async {
      await tester.pumpWidget(
        _wrap(PeerTimeline(snapshot: _populatedSnapshot())),
      );
      expect(find.text('validationPassed'), findsOneWidget);
      expect(find.text('senderIdentityMismatch'), findsOneWidget);
    });
  });

  group('Empty States', () {
    testWidgets('all widgets handle empty snapshot gracefully', (tester) async {
      final empty = _emptySnapshot();
      final widgets = <Widget>[
        DashboardOverview(snapshot: empty),
        TopologyListView(snapshot: empty),
        ReachabilityMatrix(snapshot: empty),
        NeighborDiagnosticsView(snapshot: empty),
        RouteTableViewer(snapshot: empty),
        ExpirationMonitor(snapshot: empty),
        SecurityDiagnosticsView(snapshot: empty),
        RecoveryDiagnosticsView(snapshot: empty),
        PerformancePanel(snapshot: empty),
        PeerTimeline(snapshot: empty),
      ];

      for (final widget in widgets) {
        await tester.pumpWidget(_wrap(widget));
        expect(find.byType(widget.runtimeType), findsOneWidget);
        await tester.pumpWidget(Container());
      }
    });
  });
}
