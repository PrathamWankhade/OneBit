import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/bluetooth/bluetooth_service.dart';
import 'package:onebit/features/bluetooth/data/bluetooth_platform.dart';
import 'package:onebit/features/bluetooth/domain/advertisement_config.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_device.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_permission_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_radio_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_repository.dart';
import 'package:onebit/features/bluetooth/domain/connection_options.dart';
import 'package:onebit/features/bluetooth/domain/gatt_models.dart';
import 'package:onebit/features/bluetooth/domain/mtu_negotiation_result.dart';
import 'package:onebit/features/bluetooth/domain/rssi_reading.dart';
import 'package:onebit/features/bluetooth/domain/scan_config.dart';

import '../../core/database/support/database_support.dart';
import 'support/fake_bluetooth_platform.dart';

void main() {
  late FakeBluetoothPlatform platform;
  late BluetoothRepository repository;
  late BluetoothService service;

  setUp(() {
    platform = FakeBluetoothPlatform();
    platform.enqueue('getState', Ok(readySnapshot()));
    repository = BluetoothRepositoryImplForTest(platform);
    service = BluetoothService(repository: repository, logger: silentLogger);
  });

  tearDown(() {
    platform.dispose();
  });

  group('BluetoothService', () {
    test('start is idempotent and reports the radio state', () async {
      final first = await service.start();
      expect(first.isOk, isTrue);
      expect(service.isStarted, isTrue);

      final second = await service.start();
      expect(second.isOk, isTrue);
      expect(service.isStarted, isTrue);

      await service.stop();
      expect(service.isStarted, isFalse);
    });

    test('start degrades gracefully when the native side fails', () async {
      platform = FakeBluetoothPlatform();
      platform.enqueue(
        'getState',
        const Err(PlatformFailure(message: 'ble.unsupported')),
      );
      final degraded = BluetoothService(
        repository: BluetoothRepositoryImplForTest(platform),
        logger: silentLogger,
      );
      final result = await degraded.start();
      expect(result.isErr, isTrue);
      expect(degraded.isStarted, isFalse);
    });

    test('receives transport events while started', () async {
      await service.start();
      platform.emit({'event': 'stateChanged', 'state': 'off'});
      platform.emit({'event': 'transportError', 'code': 'ble.scan.timeout'});
      // No crash and the subscription stays alive.
      await Future<void>.delayed(Duration.zero);
      expect(service.isStarted, isTrue);
      await service.stop();
    });
  });
}

/// Lightweight [BluetoothRepository] backed by the fake platform so the
/// service tests don't depend on the real event-stream implementation.
final class BluetoothRepositoryImplForTest implements BluetoothRepository {
  BluetoothRepositoryImplForTest(this.platform);

  final FakeBluetoothPlatform platform;

  @override
  Stream<BluetoothTransportEvent> get events => _events.stream;

  @override
  Stream<BluetoothRadioState> get radioStateStream => _radioStates.stream;

  final _events = StreamController<BluetoothTransportEvent>.broadcast();
  final _radioStates = StreamController<BluetoothRadioState>.broadcast();

  @override
  Future<Result<BluetoothRadioSnapshot>> getRadioSnapshot() async {
    final result = await platform.getState();
    return result.map(
      (map) => BluetoothRadioSnapshot(
        radio: map.radioState,
        permission: map.permissionState,
        batterySaver: map.batterySaver,
        maxConcurrentConnections: map.maxConcurrent,
      ),
    );
  }

  @override
  Future<Result<BluetoothPermissionState>> requestPermissions() async {
    final result = await platform.requestPermissions();
    return result.map((map) => map.permissionState);
  }

  @override
  Future<Result<BluetoothPermissionState>> recoverPermissions() async {
    final result = await platform.recoverPermissions();
    return result.map((map) => map.permissionState);
  }

  @override
  Future<Result<String>> startScan(ScanConfig config) async =>
      const Err(PlatformFailure(message: 'ble.unsupported'));

  @override
  Future<Result<void>> stopScan(String scanId) async =>
      const Err(PlatformFailure(message: 'ble.unsupported'));

  @override
  Future<Result<String>> startAdvertising(AdvertisementConfig config) async =>
      const Err(PlatformFailure(message: 'ble.unsupported'));

  @override
  Future<Result<void>> stopAdvertising(String advertisingId) async =>
      const Err(PlatformFailure(message: 'ble.unsupported'));

  @override
  Future<Result<void>> startGattServer({required String deviceId}) async =>
      const Err(PlatformFailure(message: 'ble.unsupported'));

  @override
  Future<Result<void>> stopGattServer() async =>
      const Err(PlatformFailure(message: 'ble.unsupported'));

  @override
  Future<Result<void>> connect(
    BluetoothDevice device,
    ConnectionOptions options,
  ) async => const Err(PlatformFailure(message: 'ble.unsupported'));

  @override
  Future<Result<void>> disconnect(String deviceId) async =>
      const Err(PlatformFailure(message: 'ble.unsupported'));

  @override
  Future<Result<RssiReading>> readRssi(String deviceId) async =>
      const Err(PlatformFailure(message: 'ble.unsupported'));

  @override
  Future<Result<MtuNegotiationResult>> requestMtu(
    String deviceId,
    int mtu,
  ) async => const Err(PlatformFailure(message: 'ble.unsupported'));

  @override
  Future<Result<List<GattService>>> discoverServices(String deviceId) async =>
      const Err(PlatformFailure(message: 'ble.unsupported'));

  @override
  Future<Result<List<int>>> readCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
  }) async => const Err(PlatformFailure(message: 'ble.unsupported'));

  @override
  Future<Result<void>> writeCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    bool withoutResponse = false,
    bool reliable = false,
  }) async => const Err(PlatformFailure(message: 'ble.unsupported'));

  @override
  Future<Result<void>> setCharacteristicNotification({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required bool enabled,
    bool indications = false,
  }) async => const Err(PlatformFailure(message: 'ble.unsupported'));

  @override
  Future<Result<void>> startForegroundService({required String reason}) async =>
      const Err(PlatformFailure(message: 'ble.unsupported'));

  @override
  Future<Result<void>> stopForegroundService() async =>
      const Err(PlatformFailure(message: 'ble.unsupported'));

  void dispose() {
    _events.close();
    _radioStates.close();
  }
}
