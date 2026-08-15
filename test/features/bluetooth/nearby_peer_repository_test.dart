import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/bluetooth/data/nearby_peer_repository_impl.dart';
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
import 'package:onebit/features/bluetooth/domain/scan_result.dart';
import 'package:onebit/features/nearby/domain/nearby_peer.dart';

void main() {
  group('NearbyPeerRepositoryImpl', () {
    test('projects scan results into peers and prunes stale ones', () async {
      final transport = FakeTransport();
      final repository = NearbyPeerRepositoryImpl(
        transport: transport,
        staleAfter: const Duration(milliseconds: 50),
      );

      final snapshots = <Result<List<NearbyPeer>>>[];
      final sub = repository.observeNearbyPeers().listen(snapshots.add);

      final at = DateTime.now().millisecondsSinceEpoch;
      transport.emitScan('p-1', 'first', -60, at);
      transport.emitScan('p-2', null, -70, at);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(snapshots, isNotEmpty);
      expect(snapshots.last.value ?? const <NearbyPeer>[], hasLength(2));

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(snapshots.last.value ?? const <NearbyPeer>[], isEmpty);

      await sub.cancel();
      repository.dispose();
    });

    test('disconnected or errored links drop the peer', () async {
      final transport = FakeTransport();
      final repository = NearbyPeerRepositoryImpl(
        transport: transport,
        staleAfter: const Duration(minutes: 5),
      );
      final snapshots = <Result<List<NearbyPeer>>>[];
      final sub = repository.observeNearbyPeers().listen(snapshots.add);

      final at = DateTime.now().millisecondsSinceEpoch;
      transport.emitScan('p-1', null, -60, at);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      transport.emit(
        const ConnectionChangedEvent(deviceId: 'p-1', state: 'disconnected'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(snapshots.last.value ?? const <NearbyPeer>[], isEmpty);

      await sub.cancel();
      repository.dispose();
    });
  });
}

/// Scriptable transport for repository tests.
final class FakeTransport implements BluetoothRepository {
  final _events = StreamController<BluetoothTransportEvent>.broadcast();

  void emit(BluetoothTransportEvent event) => _events.add(event);

  void emitScan(String id, String? name, int rssi, int millis) {
    emit(
      ScanResultEvent(
        ScanResult(
          device: BluetoothDevice(id: id, name: name),
          rssiDb: rssi,
          timestamp: DateTime.fromMillisecondsSinceEpoch(millis),
          connectable: true,
        ),
      ),
    );
  }

  @override
  Stream<BluetoothTransportEvent> get events => _events.stream;

  @override
  Stream<BluetoothRadioState> get radioStateStream => const Stream.empty();

  @override
  Future<Result<void>> connect(
    BluetoothDevice device,
    ConnectionOptions options,
  ) => Future.value(const Ok(null));

  @override
  Future<Result<void>> disconnect(String deviceId) =>
      Future.value(const Ok(null));

  @override
  Future<Result<List<GattService>>> discoverServices(String deviceId) =>
      Future.value(const Ok([]));

  @override
  Future<Result<BluetoothRadioSnapshot>> getRadioSnapshot() => Future.value(
    const Ok(
      BluetoothRadioSnapshot(
        radio: BluetoothRadioState.ready,
        permission: BluetoothPermissionState.granted,
        batterySaver: false,
        maxConcurrentConnections: 4,
      ),
    ),
  );

  @override
  Future<Result<List<int>>> readCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
  }) => Future.value(const Ok([]));

  @override
  Future<Result<RssiReading>> readRssi(String deviceId) => Future.value(
    Ok(RssiReading(deviceId: '', rssiDb: 0, smoothedDb: 0, timestamp: _epoch)),
  );

  @override
  Future<Result<MtuNegotiationResult>> requestMtu(String deviceId, int mtu) =>
      Future.value(
        Ok(
          MtuNegotiationResult(
            deviceId: deviceId,
            requestedMtu: mtu,
            actualMtu: mtu,
            fellBack: false,
          ),
        ),
      );

  @override
  Future<Result<BluetoothPermissionState>> requestPermissions() =>
      Future.value(const Ok(BluetoothPermissionState.granted));

  @override
  Future<Result<BluetoothPermissionState>> recoverPermissions() =>
      Future.value(const Ok(BluetoothPermissionState.granted));

  @override
  Future<Result<void>> startGattServer({required String deviceId}) =>
      Future.value(const Ok(null));

  @override
  Future<Result<void>> stopGattServer() => Future.value(const Ok(null));

  @override
  Future<Result<void>> setCharacteristicNotification({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required bool enabled,
    bool indications = false,
  }) => Future.value(const Ok(null));

  @override
  Future<Result<String>> startAdvertising(AdvertisementConfig config) =>
      Future.value(const Ok('adv-1'));

  @override
  Future<Result<void>> startForegroundService({required String reason}) =>
      Future.value(const Ok(null));

  @override
  Future<Result<String>> startScan(ScanConfig config) =>
      Future.value(const Ok('scan-1'));

  @override
  Future<Result<void>> stopAdvertising(String advertisingId) =>
      Future.value(const Ok(null));

  @override
  Future<Result<void>> stopForegroundService() => Future.value(const Ok(null));

  @override
  Future<Result<void>> stopScan(String scanId) => Future.value(const Ok(null));

  @override
  Future<Result<void>> writeCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    bool withoutResponse = false,
    bool reliable = false,
  }) => Future.value(const Ok(null));
}

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);
