import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/core/theme/onebit_theme.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_network_status.dart';
import 'package:onebit/features/mesh/domain/mesh_topology.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/features/mesh/presentation/mesh_screen.dart';
import 'package:onebit/l10n/app_localizations.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';

void main() {
  group('MeshScreen', () {
    testWidgets('shows loading indicator while state loads', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshStateProvider.overrideWithValue(const AsyncLoading()),
            meshNetworkStatusProvider.overrideWithValue(const AsyncLoading()),
            meshTopologyProvider.overrideWithValue(const AsyncLoading()),
            meshNeighborsProvider.overrideWithValue(const AsyncLoading()),
            meshRoutesProvider.overrideWithValue(const AsyncLoading()),
            meshStatisticsProvider.overrideWithValue(const AsyncLoading()),
          ],
          child: MaterialApp(
            theme: OneBitTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: MeshScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(OneBitLoadingIndicator), findsOneWidget);
    });

    testWidgets('shows error state on failure', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshStateProvider.overrideWithValue(
              AsyncError(Exception('fail'), StackTrace.empty),
            ),
            meshNetworkStatusProvider.overrideWithValue(const AsyncLoading()),
            meshTopologyProvider.overrideWithValue(const AsyncLoading()),
            meshNeighborsProvider.overrideWithValue(const AsyncLoading()),
            meshRoutesProvider.overrideWithValue(const AsyncLoading()),
            meshStatisticsProvider.overrideWithValue(const AsyncLoading()),
          ],
          child: MaterialApp(
            theme: OneBitTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: MeshScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Something went wrong'), findsOneWidget);
    });

    testWidgets('shows mesh panels when engine is stopped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshStateProvider.overrideWithValue(
              const AsyncData(Ok(MeshEngineState.stopped)),
            ),
            meshNetworkStatusProvider.overrideWithValue(const AsyncLoading()),
            meshTopologyProvider.overrideWithValue(const AsyncLoading()),
            meshNeighborsProvider.overrideWithValue(const AsyncLoading()),
            meshRoutesProvider.overrideWithValue(const AsyncLoading()),
            meshStatisticsProvider.overrideWithValue(const AsyncLoading()),
          ],
          child: MaterialApp(
            theme: OneBitTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: MeshScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(MeshScreen), findsOneWidget);
    });

    testWidgets('shows topology visualization when nodes exist', (
      tester,
    ) async {
      final topo = TopologySnapshot(
        nodes: const [
          TopologyNode(nodeId: 'local', isLocal: true),
          TopologyNode(
            nodeId: 'peer-1',
            isLocal: false,
            rssiDb: -60,
            hopCount: 1,
          ),
          TopologyNode(
            nodeId: 'peer-2',
            isLocal: false,
            rssiDb: -75,
            hopCount: 2,
          ),
        ],
        links: const [
          TopologyLink(nodeA: 'local', nodeB: 'peer-1', quality: 0.9),
          TopologyLink(nodeA: 'peer-1', nodeB: 'peer-2', quality: 0.6),
        ],
        partitions: 1,
        observedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshStateProvider.overrideWithValue(
              const AsyncData(Ok(MeshEngineState.running)),
            ),
            meshNetworkStatusProvider.overrideWithValue(
              AsyncData(
                Ok(
                  MeshNetworkStatus(
                    engineState: MeshEngineState.running,
                    activeNeighborCount: 2,
                    knownNodeCount: 3,
                    disconnectedNeighborCount: 0,
                    averageRssiDb: -67,
                    averageHopCount: 1.5,
                    relayedPacketsPerMinute: 50,
                    connectionQuality: 0.8,
                    meshStability: 0.9,
                    packetSuccessRate: 0.95,
                    partitionCount: 1,
                    observedAt: DateTime(2026),
                  ),
                ),
              ),
            ),
            meshTopologyProvider.overrideWithValue(AsyncData(Ok(topo))),
            meshNeighborsProvider.overrideWithValue(const AsyncData(Ok([]))),
            meshRoutesProvider.overrideWithValue(const AsyncData(Ok([]))),
            meshStatisticsProvider.overrideWithValue(const AsyncLoading()),
          ],
          child: MaterialApp(
            theme: OneBitTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: MeshScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('3 nodes · 2 links'), findsOneWidget);
    });

    testWidgets('renders in light theme', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshStateProvider.overrideWithValue(
              const AsyncData(Ok(MeshEngineState.stopped)),
            ),
            meshNetworkStatusProvider.overrideWithValue(const AsyncLoading()),
            meshTopologyProvider.overrideWithValue(const AsyncLoading()),
            meshNeighborsProvider.overrideWithValue(const AsyncLoading()),
            meshRoutesProvider.overrideWithValue(const AsyncLoading()),
            meshStatisticsProvider.overrideWithValue(const AsyncLoading()),
          ],
          child: MaterialApp(
            theme: OneBitTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: MeshScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(MeshScreen), findsOneWidget);
    });

    testWidgets('renders with large text scale', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshStateProvider.overrideWithValue(
              const AsyncData(Ok(MeshEngineState.stopped)),
            ),
            meshNetworkStatusProvider.overrideWithValue(const AsyncLoading()),
            meshTopologyProvider.overrideWithValue(const AsyncLoading()),
            meshNeighborsProvider.overrideWithValue(const AsyncLoading()),
            meshRoutesProvider.overrideWithValue(const AsyncLoading()),
            meshStatisticsProvider.overrideWithValue(const AsyncLoading()),
          ],
          child: MaterialApp(
            theme: OneBitTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: const Scaffold(body: MeshScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(MeshScreen), findsOneWidget);
    });

    testWidgets('renders in landscape', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshStateProvider.overrideWithValue(
              const AsyncData(Ok(MeshEngineState.stopped)),
            ),
            meshNetworkStatusProvider.overrideWithValue(const AsyncLoading()),
            meshTopologyProvider.overrideWithValue(const AsyncLoading()),
            meshNeighborsProvider.overrideWithValue(const AsyncLoading()),
            meshRoutesProvider.overrideWithValue(const AsyncLoading()),
            meshStatisticsProvider.overrideWithValue(const AsyncLoading()),
          ],
          child: MaterialApp(
            theme: OneBitTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SizedBox(width: 800, height: 400, child: MeshScreen()),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(MeshScreen), findsOneWidget);
    });
  });
}
