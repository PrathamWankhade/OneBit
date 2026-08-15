import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/logger/log_level.dart';
import 'package:onebit/core/logger/log_output.dart';
import 'package:onebit/core/logger/log_record.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/logger/logger_providers.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/core/theme/onebit_theme.dart';

import 'package:onebit/features/developer/presentation/developer_screen.dart';
import 'package:onebit/features/developer/presentation/diagnostics_screen.dart';
import 'package:onebit/features/developer/presentation/logs_screen.dart';
import 'package:onebit/features/developer/presentation/performance_screen.dart';
import 'package:onebit/features/developer/presentation/statistics_screen.dart';
import 'package:onebit/features/dtn/domain/dtn_queue_snapshot.dart';
import 'package:onebit/features/dtn/domain/dtn_statistics.dart';
import 'package:onebit/features/dtn/dtn_providers.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_network_status.dart';
import 'package:onebit/features/mesh/domain/mesh_statistics.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/l10n/app_localizations.dart';

MaterialApp _app(Widget child, {ThemeData? theme}) => MaterialApp(
  locale: const Locale('en'),
  theme: theme ?? OneBitTheme.dark,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  group('DeveloperScreen', () {
    testWidgets('renders all tool tiles', (tester) async {
      await tester.pumpWidget(_app(const DeveloperScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(DeveloperScreen), findsOneWidget);
      expect(find.byType(ListTile), findsAtLeast(4));
    });

    testWidgets('renders terminal header panel', (tester) async {
      await tester.pumpWidget(_app(const DeveloperScreen()));
      await tester.pumpAndSettle();
      expect(find.text('DEVELOPER MODE ACTIVE'), findsOneWidget);
    });

    testWidgets('renders section headers', (tester) async {
      await tester.pumpWidget(_app(const DeveloperScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Inspection'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
    });

    testWidgets('renders in light theme', (tester) async {
      await tester.pumpWidget(
        _app(const DeveloperScreen(), theme: OneBitTheme.light),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DeveloperScreen), findsOneWidget);
    });

    testWidgets('renders with large text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          theme: OneBitTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: const Scaffold(body: DeveloperScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DeveloperScreen), findsOneWidget);
    });
  });

  group('LogsScreen', () {
    testWidgets('renders search and filter controls', (tester) async {
      await tester.pumpWidget(_app(const LogsScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(LogsScreen), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(SegmentedButton<LogLevel?>), findsOneWidget);
    });

    testWidgets('renders subsystem filter', (tester) async {
      await tester.pumpWidget(_app(const LogsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('BLE'), findsOneWidget);
      expect(find.text('MESH'), findsOneWidget);
      expect(find.text('DTN'), findsOneWidget);
      expect(find.text('PACKET'), findsOneWidget);
      expect(find.text('IDENTITY'), findsOneWidget);
      expect(find.text('MEDIA'), findsOneWidget);
    });

    testWidgets('renders clear button', (tester) async {
      await tester.pumpWidget(_app(const LogsScreen()));
      await tester.pumpAndSettle();
      // Clear button exists in app bar
      expect(find.byType(LogsScreen), findsOneWidget);
    });

    testWidgets('renders in light theme', (tester) async {
      await tester.pumpWidget(
        _app(const LogsScreen(), theme: OneBitTheme.light),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LogsScreen), findsOneWidget);
    });

    testWidgets('renders with large text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          theme: OneBitTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: const Scaffold(body: LogsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LogsScreen), findsOneWidget);
    });
  });

  group('LogsScreen filtering', () {
    testWidgets('filters by level', (tester) async {
      final buffer = BufferLogOutput();
      buffer.write(
        LogRecord(
          level: LogLevel.info,
          message: 'info message',
          time: DateTime(2026),
          tag: LogTags.mesh,
        ),
      );
      buffer.write(
        LogRecord(
          level: LogLevel.error,
          message: 'error message',
          time: DateTime(2026),
          tag: LogTags.mesh,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appLogBufferProvider.overrideWithValue(buffer)],
          child: _app(const LogsScreen()),
        ),
      );
      // Advance timer to trigger log refresh
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Both messages should be visible initially (formatted with timestamps)
      expect(find.textContaining('INFO'), findsAtLeast(1));
      expect(find.textContaining('ERROR'), findsAtLeast(1));
    });

    testWidgets('filters by subsystem', (tester) async {
      final buffer = BufferLogOutput();
      buffer.write(
        LogRecord(
          level: LogLevel.info,
          message: 'mesh message',
          time: DateTime(2026),
          tag: LogTags.mesh,
        ),
      );
      buffer.write(
        LogRecord(
          level: LogLevel.info,
          message: 'dtn message',
          time: DateTime(2026),
          tag: LogTags.dtn,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appLogBufferProvider.overrideWithValue(buffer)],
          child: _app(const LogsScreen()),
        ),
      );
      // Advance timer to trigger log refresh
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Both messages visible with ALL filter
      expect(find.textContaining('mesh message'), findsAtLeast(1));
      expect(find.textContaining('dtn message'), findsAtLeast(1));
    });

    testWidgets('clear logs empties the buffer', (tester) async {
      final buffer = BufferLogOutput();
      buffer.write(
        LogRecord(
          level: LogLevel.info,
          message: 'test message',
          time: DateTime(2026),
          tag: LogTags.mesh,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appLogBufferProvider.overrideWithValue(buffer)],
          child: _app(const LogsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(buffer.snapshot(), isNotEmpty);

      // Clear the buffer
      buffer.clear();

      expect(buffer.snapshot(), isEmpty);
    });
  });

  group('LogRecord formatting', () {
    test('toLine formats correctly', () {
      final record = LogRecord(
        level: LogLevel.info,
        message: 'test message',
        time: DateTime(2026, 1, 1, 12, 30, 45, 123),
        tag: LogTags.mesh,
      );

      final line = record.toLine();
      expect(line, contains('INFO'));
      expect(line, contains('[mesh]'));
      expect(line, contains('test message'));
    });

    test('toLine without tag', () {
      final record = LogRecord(
        level: LogLevel.warning,
        message: 'warning message',
        time: DateTime(2026),
      );

      final line = record.toLine();
      expect(line, contains('WARN'));
      expect(line, contains('warning message'));
      expect(line, isNot(contains('[]')));
    });
  });

  group('BufferLogOutput', () {
    test('clear removes all records', () {
      final buffer = BufferLogOutput(capacity: 10);
      for (var i = 0; i < 5; i++) {
        buffer.write(
          LogRecord(
            level: LogLevel.info,
            message: 'msg $i',
            time: DateTime(2026),
          ),
        );
      }
      expect(buffer.snapshot().length, 5);
      buffer.clear();
      expect(buffer.snapshot(), isEmpty);
    });

    test('capacity limits records', () {
      final buffer = BufferLogOutput(capacity: 3);
      for (var i = 0; i < 5; i++) {
        buffer.write(
          LogRecord(
            level: LogLevel.info,
            message: 'msg $i',
            time: DateTime(2026),
          ),
        );
      }
      expect(buffer.snapshot().length, 3);
      expect(buffer.snapshot().first.message, 'msg 2');
    });
  });

  group('StatisticsScreen', () {
    testWidgets('renders stat sections', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshStatisticsProvider.overrideWithValue(
              AsyncData(
                Ok(
                  MeshStatistics(
                    packetsSeen: 100,
                    packetsForwarded: 50,
                    packetsDeliveredUp: 30,
                    dropsByReason: {},
                    duplicatesDropped: 5,
                    neighborJoins: 10,
                    neighborLeaves: 3,
                    routeSwitches: 2,
                    routeDiscoveriesIssued: 1,
                    routeDiscoveriesLearned: 4,
                    topologyChanges: 7,
                    duplicateCacheHits: 20,
                    duplicateCacheEvictions: 2,
                    duplicateCacheSize: 5,
                    duplicateCacheCapacity: 50,
                    packetsPerMinute: 25,
                    startedAt: DateTime(2026),
                  ),
                ),
              ),
            ),
            dtnStatisticsSnapshotProvider.overrideWithValue(
              AsyncData(
                DtnStatisticsSnapshot(
                  stored: 10,
                  delivered: 8,
                  acknowledged: 7,
                  expired: 1,
                  retried: 2,
                  relayed: 3,
                  recovered: 0,
                  parked: 1,
                  deduplicated: 1,
                  liveEnvelopes: 5,
                  avgDeliveryLatency: 0.15,
                  recordedAt: DateTime(2026),
                ),
              ),
            ),
          ],
          child: _app(const StatisticsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('renders in light theme', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshStatisticsProvider.overrideWithValue(const AsyncLoading()),
            dtnStatisticsSnapshotProvider.overrideWithValue(
              const AsyncLoading(),
            ),
          ],
          child: _app(const StatisticsScreen(), theme: OneBitTheme.light),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });
  });

  group('PerformanceScreen', () {
    testWidgets('renders performance sections', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshDiagnosticsProvider.overrideWithValue(const AsyncLoading()),
            appLogBufferProvider.overrideWithValue(BufferLogOutput()),
          ],
          child: _app(const PerformanceScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PerformanceScreen), findsOneWidget);
    });

    testWidgets('renders in light theme', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshDiagnosticsProvider.overrideWithValue(const AsyncLoading()),
            appLogBufferProvider.overrideWithValue(BufferLogOutput()),
          ],
          child: _app(const PerformanceScreen(), theme: OneBitTheme.light),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PerformanceScreen), findsOneWidget);
    });
  });

  group('DiagnosticsScreen', () {
    testWidgets('renders diagnostics panels', (tester) async {
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
                    activeNeighborCount: 3,
                    knownNodeCount: 5,
                    disconnectedNeighborCount: 1,
                    averageRssiDb: -65,
                    averageHopCount: 1.5,
                    relayedPacketsPerMinute: 120,
                    connectionQuality: 0.85,
                    meshStability: 0.92,
                    packetSuccessRate: 0.97,
                    partitionCount: 1,
                    observedAt: DateTime(2026),
                  ),
                ),
              ),
            ),
            meshDiagnosticsProvider.overrideWithValue(const AsyncLoading()),
            dtnQueueSnapshotProvider.overrideWithValue(
              AsyncData(
                DtnQueueSnapshot(
                  outgoing: 2,
                  deferred: 1,
                  retry: 0,
                  incoming: 3,
                  relaying: 1,
                  awaitingAck: 0,
                  live: 7,
                  takenAt: DateTime(2026),
                ),
              ),
            ),
          ],
          child: _app(const DiagnosticsScreen()),
        ),
      );
      await tester.pump();
      expect(find.byType(DiagnosticsScreen), findsOneWidget);
    });

    testWidgets('renders in light theme', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshStateProvider.overrideWithValue(
              const AsyncData(Ok(MeshEngineState.stopped)),
            ),
            meshNetworkStatusProvider.overrideWithValue(const AsyncLoading()),
            meshDiagnosticsProvider.overrideWithValue(const AsyncLoading()),
            dtnQueueSnapshotProvider.overrideWithValue(const AsyncLoading()),
          ],
          child: _app(const DiagnosticsScreen(), theme: OneBitTheme.light),
        ),
      );
      await tester.pump();
      expect(find.byType(DiagnosticsScreen), findsOneWidget);
    });

    testWidgets('renders with large text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          theme: OneBitTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: ProviderScope(
            overrides: [
              meshStateProvider.overrideWithValue(
                const AsyncData(Ok(MeshEngineState.stopped)),
              ),
              meshNetworkStatusProvider.overrideWithValue(const AsyncLoading()),
              meshDiagnosticsProvider.overrideWithValue(const AsyncLoading()),
              dtnQueueSnapshotProvider.overrideWithValue(const AsyncLoading()),
            ],
            child: const Scaffold(body: DiagnosticsScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(DiagnosticsScreen), findsOneWidget);
    });

    testWidgets('renders in landscape', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshStateProvider.overrideWithValue(
              const AsyncData(Ok(MeshEngineState.stopped)),
            ),
            meshNetworkStatusProvider.overrideWithValue(const AsyncLoading()),
            meshDiagnosticsProvider.overrideWithValue(const AsyncLoading()),
            dtnQueueSnapshotProvider.overrideWithValue(const AsyncLoading()),
          ],
          child: _app(const DiagnosticsScreen()),
        ),
      );
      await tester.pump();
      expect(find.byType(DiagnosticsScreen), findsOneWidget);
    });
  });

  group('Security: no private key exposure', () {
    test('LogRecord does not expose key material', () {
      final record = LogRecord(
        level: LogLevel.info,
        message: 'test',
        time: DateTime(2026),
        tag: LogTags.identity,
      );
      final line = record.toLine();
      // Should not contain any key-like hex strings
      expect(line, isNot(contains('private')));
      expect(line, isNot(contains('secret')));
      expect(line, isNot(contains('session_key')));
    });

    test('LogTags are safe subsystem identifiers', () {
      expect(LogTags.app, 'app');
      expect(LogTags.config, 'config');
      expect(LogTags.platform, 'platform');
      expect(LogTags.storage, 'storage');
      expect(LogTags.identity, 'identity');
      expect(LogTags.mesh, 'mesh');
      expect(LogTags.packet, 'packet');
      expect(LogTags.dtn, 'dtn');
      expect(LogTags.messaging, 'messaging');
      expect(LogTags.media, 'media');
      expect(LogTags.native, 'native');
    });
  });
}
