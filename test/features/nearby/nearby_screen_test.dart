import 'dart:async';

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
import 'package:onebit/features/bluetooth/presentation/bluetooth_providers.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/features/nearby/domain/nearby_peer.dart';
import 'package:onebit/features/nearby/presentation/nearby_screen.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_offline_state.dart';
import 'package:onebit/shared/design_system/components/onebit_permission_state.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';

import '../../app/support/app_navigation_support.dart';
import '../bluetooth/support/fake_bluetooth_platform.dart';

/// The nearby tab: radio/permission gating, live peer feed, scan lifecycle
/// and the loading/error/empty state machine.
void main() {
  Future<void> pumpNearby(
    WidgetTester tester,
    FakeBluetoothPlatform platform,
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
          bluetoothPlatformProvider.overrideWithValue(platform),
        ],
        child: const OneBitApp(),
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(AppShell))).go(AppRoutePaths.nearby);
    await tester.pumpAndSettle();
  }

  Map<String, Object?> peerResult(String id, int rssi) => {
    'event': 'scanResult',
    'result': {
      'device': {'id': id, 'name': 'onebit-node'},
      'rssiDb': rssi,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'connectable': true,
    },
  };

  testWidgets('empty state greets a quiet air', (tester) async {
    final platform = FakeBluetoothPlatform();
    platform.enqueue('getState', Ok(readySnapshot()));

    await pumpNearby(tester, platform);

    expect(find.byType(NearbyScreen), findsOneWidget);
    expect(find.text('No devices nearby yet'), findsOneWidget);

    await disposeApp(tester);
    platform.dispose();
  });

  testWidgets('discovered peers render id, rssi and last seen', (tester) async {
    final platform = FakeBluetoothPlatform();
    platform.enqueue('getState', Ok(readySnapshot()));

    await pumpNearby(tester, platform);

    platform.emit(peerResult('peer-1', -55));
    await tester.pump();
    await tester.pump();

    expect(find.text('peer-1'), findsOneWidget);
    expect(find.text('-55 dBm'), findsOneWidget);
    expect(find.text('1 devices'), findsOneWidget);
    expect(find.textContaining('Last seen'), findsOneWidget);

    await disposeApp(tester);
    platform.dispose();
  });

  testWidgets('scan toggle delegates to the scan controller', (tester) async {
    final platform = FakeBluetoothPlatform();
    platform.enqueue('getState', Ok(readySnapshot()));
    platform.enqueue('startScan', const Ok({'started': true}));
    platform.enqueue('stopScan', const Ok({'stopped': true}));

    await pumpNearby(tester, platform);

    await tester.tap(find.byIcon(OneBitIcons.radar));
    await tester.pumpAndSettle();
    expect(platform.invokedMethods, contains('startScan'));
    expect(find.text('Scanning…'), findsOneWidget);

    await tester.tap(find.byIcon(OneBitIcons.radar));
    await tester.pumpAndSettle();
    expect(platform.invokedMethods, contains('stopScan'));

    await disposeApp(tester);
    platform.dispose();
  });

  testWidgets('radio off shows the offline state', (tester) async {
    final platform = FakeBluetoothPlatform();
    platform.enqueue(
      'getState',
      const Ok({
        'state': 'off',
        'permission': 'granted',
        'batterySaver': false,
        'maxConcurrentConnections': 4,
      }),
    );

    await pumpNearby(tester, platform);

    expect(find.byType(OneBitOfflineState), findsOneWidget);
    expect(find.text('Bluetooth is off'), findsOneWidget);

    await disposeApp(tester);
    platform.dispose();
  });

  testWidgets('denied permissions show the permission state', (tester) async {
    final platform = FakeBluetoothPlatform();
    platform.enqueue(
      'getState',
      const Ok({
        'state': 'ready',
        'permission': 'denied',
        'batterySaver': false,
        'maxConcurrentConnections': 4,
      }),
    );

    await pumpNearby(tester, platform);

    expect(find.byType(OneBitPermissionState), findsOneWidget);
    expect(find.text('Bluetooth access needed'), findsOneWidget);

    await disposeApp(tester);
    platform.dispose();
  });

  testWidgets('peer feed failure shows the error state with retry', (
    tester,
  ) async {
    final platform = FakeBluetoothPlatform();
    platform.enqueue('getState', Ok(readySnapshot()));

    final controller = StreamController<Result<List<NearbyPeer>>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(
            FakeIdentityRepository(identity: testIdentity()),
          ),
          databaseConnectionFactoryProvider.overrideWithValue(
            const InMemoryConnectionFactory(),
          ),
          bluetoothPlatformProvider.overrideWithValue(platform),
          nearbyPeersProvider.overrideWith((_) => controller.stream),
        ],
        child: const OneBitApp(),
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(AppShell))).go(AppRoutePaths.nearby);
    await tester.pumpAndSettle();

    controller.add(const Err(PlatformFailure(message: 'ble.stream')));
    await tester.pumpAndSettle();

    expect(find.byType(OneBitErrorState), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    controller.add(
      Ok([
        NearbyPeer(
          peerId: 'peer-1',
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
          rssiDb: -50,
        ),
      ]),
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('peer-1'), findsOneWidget);
    expect(find.byType(OneBitErrorState), findsNothing);

    await disposeApp(tester);
    platform.dispose();
  });

  testWidgets('nearby stays loading while the peer feed is silent', (
    tester,
  ) async {
    final platform = FakeBluetoothPlatform();
    platform.enqueue('getState', Ok(readySnapshot()));

    final controller = StreamController<Result<List<NearbyPeer>>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(
            FakeIdentityRepository(identity: testIdentity()),
          ),
          databaseConnectionFactoryProvider.overrideWithValue(
            const InMemoryConnectionFactory(),
          ),
          bluetoothPlatformProvider.overrideWithValue(platform),
          nearbyPeersProvider.overrideWith((_) => controller.stream),
        ],
        child: const OneBitApp(),
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(AppShell))).go(AppRoutePaths.nearby);
    await tester.pumpAndSettle();

    expect(find.byType(OneBitLoadingIndicator), findsOneWidget);

    await disposeApp(tester);
    platform.dispose();
  });
}
