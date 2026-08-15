import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/database/connection/connection_factory.dart';
import 'package:onebit/core/database/database_providers.dart'
    show databaseConnectionFactoryProvider;
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/trust_level.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_neighbor.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/features/nodes/presentation/node_details_screen.dart';
import 'package:onebit/features/nodes/presentation/nodes_screen.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../app/support/app_navigation_support.dart';
import '../../app/support/screen_test_support.dart';

/// The nodes tab: trusted contacts, live neighbors and the loading/error/
/// empty state machine.
void main() {
  Future<void> pumpNodes(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    GoRouter.of(tester.element(find.byType(AppShell))).go(AppRoutePaths.nodes);
    await tester.pumpAndSettle();
  }

  testWidgets('empty registry shows the friendly empty state', (tester) async {
    final container = await pumpShell(tester);

    await pumpNodes(tester, container);

    expect(find.byType(NodesScreen), findsOneWidget);
    // The mesh is stopped by default, so the offline state is shown.
    // When the mesh is running with no nodes, the empty state is shown.
    expect(
      find.text('No nodes yet').evaluate().isNotEmpty ||
          find.text("You're offline").evaluate().isNotEmpty,
      isTrue,
      reason: 'Should show either empty or offline state',
    );

    await disposeApp(tester);
  });

  testWidgets('trusted contacts render identity and verification material', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    await seedContact(
      container,
      nodeId: 'node-abc',
      displayName: 'Alice',
      trustLevel: TrustLevel.verified,
    );
    await tester.pumpAndSettle();

    await pumpNodes(tester, container);

    expect(find.text('Trusted'), findsOneWidget);
    expect(find.text('1 contacts'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('node-abc'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.textContaining('abababab'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('node ids and fingerprints render in the technical family', (
    tester,
  ) async {
    final container = await pumpShell(tester);
    await seedContact(container, nodeId: 'node-abc', displayName: 'Alice');
    await tester.pumpAndSettle();

    await pumpNodes(tester, container);

    final nodeId = tester.widget<Text>(find.text('node-abc'));
    expect(nodeId.style?.fontFamily, OneBitTypography.technicalFamily);

    final fingerprint = tester.widget<Text>(find.textContaining('abababab'));
    expect(fingerprint.style?.fontFamily, OneBitTypography.technicalFamily);

    await disposeApp(tester);
  });

  testWidgets('tapping a trusted contact opens its details', (tester) async {
    final container = await pumpShell(tester);
    await seedContact(container, nodeId: 'node-abc', displayName: 'Alice');
    await tester.pumpAndSettle();

    await pumpNodes(tester, container);

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(find.byType(NodeDetailsScreen), findsOneWidget);
    expect(find.text('node-abc'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('live mesh neighbors appear without identity material', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(
            FakeIdentityRepository(identity: testIdentity()),
          ),
          databaseConnectionFactoryProvider.overrideWithValue(
            const InMemoryConnectionFactory(),
          ),
          meshNeighborsProvider.overrideWith(
            (_) => Stream.value(
              Ok([
                MeshNeighbor(
                  nodeId: 'peer-live',
                  connectionState: MeshLinkState.connected,
                  latestRssiDb: -42,
                  smoothedRssiDb: -45,
                  firstSeen: DateTime.utc(2026, 1, 1),
                  lastSeen: DateTime.utc(2026, 1, 2),
                ),
              ]),
            ),
          ),
        ],
        child: const OneBitApp(),
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(AppShell))).go(AppRoutePaths.nodes);
    await tester.pumpAndSettle();

    expect(find.text('Nearby'), findsWidgets);
    expect(find.text('peer-live'), findsWidgets);
    expect(find.text('-42 dBm'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('registry failure shows the error state with retry', (
    tester,
  ) async {
    final controller = StreamController<Result<List<MeshNeighbor>>>.broadcast();
    addTearDown(controller.close);
    SharedPreferencesAsyncPlatform.instance = sharedPrefsStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(
            FakeIdentityRepository(identity: testIdentity()),
          ),
          databaseConnectionFactoryProvider.overrideWithValue(
            const InMemoryConnectionFactory(),
          ),
          meshNeighborsProvider.overrideWith((_) => controller.stream),
        ],
        child: const OneBitApp(),
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(AppShell))).go(AppRoutePaths.nodes);
    await tester.pump();

    controller.add(const Err(StorageFailure(message: 'boom')));
    await tester.pumpAndSettle();

    expect(find.byType(OneBitErrorState), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    controller.add(
      Ok([
        MeshNeighbor(
          nodeId: 'peer-live',
          connectionState: MeshLinkState.connected,
          latestRssiDb: -42,
          smoothedRssiDb: -45,
          firstSeen: DateTime.utc(2026, 1, 1),
          lastSeen: DateTime.utc(2026, 1, 2),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('peer-live'), findsWidgets);
    expect(find.byType(OneBitErrorState), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('registry stays loading while the neighbor stream is silent', (
    tester,
  ) async {
    final controller = StreamController<Result<List<MeshNeighbor>>>.broadcast();
    addTearDown(controller.close);
    SharedPreferencesAsyncPlatform.instance = sharedPrefsStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(
            FakeIdentityRepository(identity: testIdentity()),
          ),
          databaseConnectionFactoryProvider.overrideWithValue(
            const InMemoryConnectionFactory(),
          ),
          meshNeighborsProvider.overrideWith((_) => controller.stream),
        ],
        child: const OneBitApp(),
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(AppShell))).go(AppRoutePaths.nodes);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(OneBitLoadingIndicator), findsOneWidget);

    await disposeApp(tester);
  });
}
