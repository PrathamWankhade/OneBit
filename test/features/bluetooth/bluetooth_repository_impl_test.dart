import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/bluetooth/data/bluetooth_repository_impl.dart';
import 'package:onebit/features/bluetooth/domain/advertisement_config.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_device.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_permission_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_radio_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_repository.dart';
import 'package:onebit/features/bluetooth/domain/connection_options.dart';
import 'package:onebit/features/bluetooth/domain/gatt_models.dart';
import 'package:onebit/features/bluetooth/domain/scan_config.dart';

import '../../core/database/support/database_support.dart';
import 'support/fake_bluetooth_platform.dart';

void main() {
  late FakeBluetoothPlatform platform;
  late BluetoothRepositoryImpl repository;

  setUp(() {
    platform = FakeBluetoothPlatform();
    repository = BluetoothRepositoryImpl(
      platform: platform,
      logger: silentLogger,
    );
  });

  tearDown(() {
    platform.dispose();
  });

  group('BluetoothRepositoryImpl', () {
    test('getRadioSnapshot maps the native payload', () async {
      platform.enqueue('getState', Ok(readySnapshot()));
      final result = await repository.getRadioSnapshot();
      expect(result.isOk, isTrue);
      expect(result.value!.radio, BluetoothRadioState.ready);
      expect(result.value!.permission, BluetoothPermissionState.granted);
      expect(result.value!.maxConcurrentConnections, 4);
    });

    test('getRadioSnapshot surfaces native failures', () async {
      platform.enqueue(
        'getState',
        const Err(PlatformFailure(message: 'ble.disabled')),
      );
      final result = await repository.getRadioSnapshot();
      expect(result.isErr, isTrue);
      expect(result.failure!.message, contains('ble.disabled'));
    });

    test('requestPermissions maps the permission state', () async {
      platform.enqueue(
        'requestPermissions',
        const Ok({'permission': 'granted'}),
      );
      final result = await repository.requestPermissions();
      expect(result.value, BluetoothPermissionState.granted);
    });

    test('recoverPermissions re-requests and maps the state', () async {
      platform.enqueue(
        'recoverPermissions',
        const Ok({'permission': 'granted'}),
      );
      final result = await repository.recoverPermissions();
      expect(result.value, BluetoothPermissionState.granted);
      expect(platform.invokedMethods, contains('recoverPermissions'));
    });

    test('recoverPermissions surfaces native failures', () async {
      platform.enqueue(
        'recoverPermissions',
        const Err(PlatformFailure(message: 'ble.permission.location')),
      );
      final result = await repository.recoverPermissions();
      expect(result.isErr, isTrue);
      expect(result.failure!.message, contains('ble.permission.location'));
    });

    test('startGattServer passes the device id', () async {
      platform.enqueue('startGattServer', const Ok({'deviceId': 'd-1'}));
      final result = await repository.startGattServer(deviceId: 'd-1');
      expect(result.isOk, isTrue);
      expect(platform.invokedMethods, contains('startGattServer'));
    });

    test('stopGattServer stops the peripheral server', () async {
      platform.enqueue('stopGattServer', const Ok({}));
      final result = await repository.stopGattServer();
      expect(result.isOk, isTrue);
      expect(platform.invokedMethods, contains('stopGattServer'));
    });

    test('startScan encodes config and returns the scan id', () async {
      platform.enqueue('startScan', const Ok({'id': 'scan-1'}));
      final result = await repository.startScan(
        const ScanConfig(
          mode: ScanMode.active,
          timeout: Duration(seconds: 30),
          background: true,
        ),
      );
      expect(result.value, 'scan-1');
      final args = platform.invokedMethods;
      expect(args, contains('startScan'));
    });

    test('startScan rejects an id-less response', () async {
      platform.enqueue('startScan', const Ok({}));
      final result = await repository.startScan(const ScanConfig());
      expect(result.isErr, isTrue);
    });

    test('connect serializes device and options', () async {
      platform.enqueue('connect', const Ok({'deviceId': 'd-1'}));
      final result = await repository.connect(
        const BluetoothDevice(id: 'd-1', name: 'peer'),
        const ConnectionOptions(requestMtu: 512, maxRetries: 2),
      );
      expect(result.isOk, isTrue);
      expect(platform.invokedMethods, contains('connect'));
    });

    test('requestMtu maps negotiation result with fallback flag', () async {
      platform.enqueue(
        'requestMtu',
        const Ok({'requestedMtu': 512, 'actualMtu': 185}),
      );
      final result = await repository.requestMtu('d-1', 512);
      expect(result.value!.requestedMtu, 512);
      expect(result.value!.actualMtu, 185);
      expect(result.value!.fellBack, isTrue);
    });

    test('discoverServices decodes the service tree', () async {
      platform.enqueue(
        'discoverServices',
        const Ok({
          'services': [
            {
              'uuid': 'svc-1',
              'isPrimary': true,
              'characteristics': [
                {
                  'uuid': 'char-1',
                  'properties': 0x02,
                  'descriptors': <Map<String, Object?>>[],
                  'value': <int>[],
                },
              ],
            },
          ],
        }),
      );
      final result = await repository.discoverServices('d-1');
      expect(result.value!.single.uuid, 'svc-1');
      expect(
        result.value!.single.characteristics.single.supports(GattProperty.read),
        isTrue,
      );
    });

    test('readCharacteristic returns raw bytes', () async {
      platform.enqueue(
        'readCharacteristic',
        const Ok({
          'value': [1, 2, 3],
        }),
      );
      final result = await repository.readCharacteristic(
        deviceId: 'd-1',
        serviceUuid: 'svc-1',
        characteristicUuid: 'char-1',
      );
      expect(result.value, [1, 2, 3]);
    });

    test('writeCharacteristic passes the byte payload', () async {
      platform.enqueue('writeCharacteristic', const Ok({'written': 3}));
      final result = await repository.writeCharacteristic(
        deviceId: 'd-1',
        serviceUuid: 'svc-1',
        characteristicUuid: 'char-1',
        value: [9, 9],
        withoutResponse: true,
      );
      expect(result.isOk, isTrue);
    });

    test('event stream decodes native events into domain events', () async {
      repository.startListening();
      final seen = <Type>[];
      final sub = repository.events.listen(
        (event) => seen.add(event.runtimeType),
      );

      platform.emit({'event': 'stateChanged', 'state': 'ready'});
      platform.emit({
        'event': 'scanResult',
        'result': {
          'device': {'id': 'd-1'},
          'rssiDb': -55,
          'timestamp': 1,
        },
      });
      platform.emit({
        'event': 'connectionChanged',
        'deviceId': 'd-1',
        'state': 'ready',
        'mtu': 512,
      });
      platform.emit({
        'event': 'mtuNegotiated',
        'deviceId': 'd-1',
        'requestedMtu': 512,
        'actualMtu': 185,
      });
      platform.emit({
        'event': 'rssi',
        'deviceId': 'd-1',
        'rssi': -60,
        'smoothed': -61.2,
        'timestamp': 1,
      });
      platform.emit({'event': 'unknownThing'});

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(
        seen,
        containsAllInOrder([
          RadioStateChangedEvent,
          ScanResultEvent,
          ConnectionChangedEvent,
          MtuResultEvent,
          RssiEvent,
        ]),
      );
    });

    test('transportError events decode into typed failures', () async {
      repository.startListening();
      final errors = <TransportErrorEvent>[];
      final sub = repository.events.listen((event) {
        if (event is TransportErrorEvent) errors.add(event);
      });

      platform.emit({
        'event': 'transportError',
        'code': 'ble.scan.timeout',
        'message': 'scan scan-1 reached its deadline',
        'context': 'scan',
      });

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(errors.single.code, 'ble.scan.timeout');
      expect(errors.single.message, contains('deadline'));
      expect(errors.single.context, 'scan');
    });

    test('advertising args round-trip with rotation count', () async {
      platform.enqueue('startAdvertising', const Ok({'id': 'adv-1'}));
      final result = await repository.startAdvertising(
        const AdvertisementConfig(
          mode: AdvertisingPowerMode.lowLatency,
          serviceUuid: '00001111-0000-1000-8000-00805f9b34fb',
          manufacturerId: 276,
          manufacturerData: [1, 2],
          localName: 'onebit-node',
          background: true,
          rotationCount: 3,
        ),
      );
      expect(result.value, 'adv-1');
    });

    test('radioStateStream emits radio changes', () async {
      repository.startListening();
      final states = <BluetoothRadioState>[];
      final sub = repository.radioStateStream.listen(states.add);
      platform.emit({'event': 'stateChanged', 'state': 'ready'});
      platform.emit({'event': 'stateChanged', 'state': 'off'});
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(states, [BluetoothRadioState.ready, BluetoothRadioState.off]);
    });

    test('advertising args round-trip with rotation count', () async {
      platform.enqueue('startAdvertising', const Ok({'id': 'adv-1'}));
      final result = await repository.startAdvertising(
        const AdvertisementConfig(
          mode: AdvertisingPowerMode.lowLatency,
          serviceUuid: '00001111-0000-1000-8000-00805f9b34fb',
          manufacturerId: 276,
          manufacturerData: [1, 2],
          localName: 'onebit-node',
          background: true,
          rotationCount: 3,
        ),
      );
      expect(result.value, 'adv-1');
    });
  });
}
