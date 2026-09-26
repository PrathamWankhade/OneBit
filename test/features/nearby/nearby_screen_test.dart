import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/ble/ble_providers.dart';
import 'package:onebit/features/ble/discovered_device.dart';
import 'package:onebit/features/identity/identity_providers.dart';
import 'package:onebit/features/nearby/presentation/nearby_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testChannel = MethodChannel('dev.onebit.onebit/ble');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(testChannel, (call) async {
      if (call.method == 'getState') {
        return <String, dynamic>{
          'state': 'ready',
          'permission': 'granted',
          'batterySaver': false,
          'recoveryRequired': false,
        };
      }
      if (call.method == 'startScan') {
        return <String, dynamic>{'id': 'scan-1'};
      }
      if (call.method == 'stopScan') {
        return <String, dynamic>{};
      }
      if (call.method == 'startAdvertising') {
        return <String, dynamic>{'id': 'adv-1'};
      }
      if (call.method == 'stopAdvertising') {
        return <String, dynamic>{};
      }
      if (call.method == 'connect') {
        return <String, dynamic>{'status': 'connecting'};
      }
      if (call.method == 'disconnect') {
        return <String, dynamic>{};
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(testChannel, null);
  });

  Widget buildTestApp({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        // Advertising waits for the local identity before starting, but
        // these tests are about discovery UI, not identity — stubbing it
        // keeps them from opening the real database.
        localIdentityProvider.overrideWith((ref) async => null),
        ...overrides,
      ],
      child: const MaterialApp(
        home: NearbyScreen(),
      ),
    );
  }

  group('NearbyScreen', () {
    testWidgets('idle state shows no peers message', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump();

      expect(find.text('No peers nearby'), findsOneWidget);
      expect(find.text('Scan again'), findsOneWidget);
    });

    testWidgets('scanning shows animation then peers', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Scanning for peers'),
        findsOneWidget,
      );
    });

    testWidgets('discovered device appears in list', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pump();

      final service = ProviderScope.containerOf(
        tester.element(find.byType(NearbyScreen)),
      ).read(bleServiceProvider);
      service.pushDiscovery(
        const DiscoveredOneBitDevice(
          deviceId: 'AA:BB:CC:DD:EE:FF',
          rssi: -55,
          timestamp: 1700000000000,
          name: 'OneBit-001',
          serviceUuids: ['D1A00000-0000-1000-8000-00805F9B34FB'],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('OneBit-001'), findsOneWidget);
    });

    testWidgets('multiple devices are shown', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pump();

      final service = ProviderScope.containerOf(
        tester.element(find.byType(NearbyScreen)),
      ).read(bleServiceProvider);

      service.pushDiscovery(
        const DiscoveredOneBitDevice(
          deviceId: 'AA:BB:CC:DD:EE:01',
          rssi: -50,
          timestamp: 1700000000000,
          name: 'OneBit-A',
          serviceUuids: ['D1A00000-0000-1000-8000-00805F9B34FB'],
        ),
      );
      service.pushDiscovery(
        const DiscoveredOneBitDevice(
          deviceId: 'AA:BB:CC:DD:EE:02',
          rssi: -70,
          timestamp: 1700000000000,
          name: 'OneBit-B',
          serviceUuids: ['D1A00000-0000-1000-8000-00805F9B34FB'],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('OneBit-A'), findsOneWidget);
      expect(find.text('OneBit-B'), findsOneWidget);
    });

    testWidgets('devices sorted by signal strength', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pump();

      final service = ProviderScope.containerOf(
        tester.element(find.byType(NearbyScreen)),
      ).read(bleServiceProvider);

      service.pushDiscovery(
        const DiscoveredOneBitDevice(
          deviceId: 'AA:BB:CC:DD:EE:01',
          rssi: -85,
          timestamp: 1700000000000,
          name: 'Weak-Device',
          serviceUuids: ['D1A00000-0000-1000-8000-00805F9B34FB'],
        ),
      );
      service.pushDiscovery(
        const DiscoveredOneBitDevice(
          deviceId: 'AA:BB:CC:DD:EE:02',
          rssi: -45,
          timestamp: 1700000000000,
          name: 'Strong-Device',
          serviceUuids: ['D1A00000-0000-1000-8000-00805F9B34FB'],
        ),
      );
      await tester.pump();
      await tester.pump();

      final strongIndex = tester.getTopLeft(find.text('Strong-Device')).dy;
      final weakIndex = tester.getTopLeft(find.text('Weak-Device')).dy;
      expect(strongIndex, lessThan(weakIndex));
    });

    testWidgets('device without name shows fallback', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pump();

      final service = ProviderScope.containerOf(
        tester.element(find.byType(NearbyScreen)),
      ).read(bleServiceProvider);

      service.pushDiscovery(
        const DiscoveredOneBitDevice(
          deviceId: 'AA:BB:CC:DD:EE:FF',
          rssi: -60,
          timestamp: 1700000000000,
          serviceUuids: ['D1A00000-0000-1000-8000-00805F9B34FB'],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('OneBit device'), findsOneWidget);
    });

    testWidgets('bluetooth off shows disabled state', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, (call) async {
        if (call.method == 'getState') {
          return <String, dynamic>{
            'state': 'off',
            'permission': 'granted',
            'batterySaver': false,
            'recoveryRequired': false,
          };
        }
        return null;
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump();

      expect(find.text('Bluetooth is off'), findsOneWidget);
      expect(
        find.text('Enable Bluetooth to discover and connect to nearby OneBit peers.'),
        findsOneWidget,
      );
    });

    testWidgets('permission required shows permission state', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, (call) async {
        if (call.method == 'getState') {
          return <String, dynamic>{
            'state': 'ready',
            'permission': 'notDetermined',
            'batterySaver': false,
            'recoveryRequired': false,
          };
        }
        if (call.method == 'requestPermissions') {
          return <String, dynamic>{
            'permission': 'granted',
          };
        }
        return null;
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump();

      expect(find.text('Permission needed'), findsOneWidget);
      expect(find.text('Grant permission'), findsOneWidget);
    });

    testWidgets('dispose stops scan and advertising', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pump();

      final service = ProviderScope.containerOf(
        tester.element(find.byType(NearbyScreen)),
      ).read(bleServiceProvider);

      expect(service.current.isScanning, true);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      expect(service.current.isScanning, false);
    });

    testWidgets('new scan clears stale results from previous session',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pump();

      final service = ProviderScope.containerOf(
        tester.element(find.byType(NearbyScreen)),
      ).read(bleServiceProvider);

      service.pushDiscovery(
        const DiscoveredOneBitDevice(
          deviceId: 'AA:BB:CC:DD:EE:01',
          rssi: -55,
          timestamp: 1700000000000,
          name: 'Old-Device',
          serviceUuids: ['D1A00000-0000-1000-8000-00805F9B34FB'],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Old-Device'), findsOneWidget);

      await service.stopScan();
      await tester.pump();
      await tester.pump();

      // After stopping, the peers found view still shows the device
      expect(find.text('Old-Device'), findsOneWidget);
      expect(find.text('1 nearby'), findsOneWidget);

      // Start second scan — old devices should be cleared
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pump();

      expect(find.text('Old-Device'), findsNothing);
    });

    testWidgets('permission request preserves radio state', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, (call) async {
        if (call.method == 'getState') {
          return <String, dynamic>{
            'state': 'ready',
            'permission': 'notDetermined',
            'batterySaver': false,
            'recoveryRequired': false,
          };
        }
        if (call.method == 'requestPermissions') {
          return <String, dynamic>{
            'permission': 'granted',
          };
        }
        return null;
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump();

      expect(find.text('Permission needed'), findsOneWidget);

      await tester.tap(find.text('Grant permission'));
      await tester.pump();
      await tester.pump();

      expect(find.text('No peers nearby'), findsOneWidget);
      expect(find.text('Scan again'), findsOneWidget);
    });

    testWidgets('discovered device is tappable', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pump();

      final service = ProviderScope.containerOf(
        tester.element(find.byType(NearbyScreen)),
      ).read(bleServiceProvider);

      service.pushDiscovery(
        const DiscoveredOneBitDevice(
          deviceId: 'AA:BB:CC:DD:EE:FF',
          rssi: -55,
          timestamp: 1700000000000,
          name: 'OneBit-001',
          serviceUuids: ['D1A00000-0000-1000-8000-00805F9B34FB'],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('OneBit-001'), findsOneWidget);
      await tester.tap(find.text('OneBit-001'));
      await tester.pump();
    });

    testWidgets('becomes discoverable automatically, scanning stays manual',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump();

      final service = ProviderScope.containerOf(
        tester.element(find.byType(NearbyScreen)),
      ).read(bleServiceProvider);

      // A phone nobody remembered to put in advertise mode would otherwise
      // never appear in anyone else's list.
      expect(service.current.isAdvertising, true);

      // Scanning is still the user's call, so the idle "Scan again"
      // state remains reachable.
      expect(service.current.isScanning, false);
      expect(find.text('No peers nearby'), findsOneWidget);
      expect(find.text('Scan again'), findsOneWidget);
    });
  });
}
