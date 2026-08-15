import 'package:flutter/foundation.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/bluetooth/domain/advertisement_config.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_device.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_permission_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_radio_state.dart';
import 'package:onebit/features/bluetooth/domain/connection_options.dart';
import 'package:onebit/features/bluetooth/domain/gatt_models.dart';
import 'package:onebit/features/bluetooth/domain/mtu_negotiation_result.dart';
import 'package:onebit/features/bluetooth/domain/rssi_reading.dart';
import 'package:onebit/features/bluetooth/domain/scan_config.dart';
import 'package:onebit/features/bluetooth/domain/scan_result.dart';

/// Transport contract for the Bluetooth layer.
///
/// Pure transport: bytes in, bytes out, radio lifecycle. Nothing here knows
/// about messages, routing, trust or the mesh. Every method returns a
/// [Result] so failures stay in the failure framework.
abstract interface class BluetoothRepository {
  /// Radio + permission + battery snapshot.
  Future<Result<BluetoothRadioSnapshot>> getRadioSnapshot();

  /// Requests the runtime permissions the current Android target needs.
  Future<Result<BluetoothPermissionState>> requestPermissions();

  /// Recovers from a denied permission by re-requesting the missing grants.
  Future<Result<BluetoothPermissionState>> recoverPermissions();

  /// Starts a scan cycle per [config]. Returns the scan id.
  Future<Result<String>> startScan(ScanConfig config);

  /// Stops the scan cycle [scanId].
  Future<Result<void>> stopScan(String scanId);

  /// Starts advertising per [config]. Returns the advertising id.
  ///
  /// Advertising is the peripheral role; the native side also stands up
  /// the local GATT server so inbound peers find the probe service.
  Future<Result<String>> startAdvertising(AdvertisementConfig config);

  /// Stops advertising [advertisingId] (and the peripheral GATT server).
  Future<Result<void>> stopAdvertising(String advertisingId);

  /// Starts the local GATT server (peripheral role) for [deviceId].
  Future<Result<void>> startGattServer({required String deviceId});

  /// Stops the local GATT server.
  Future<Result<void>> stopGattServer();

  /// Connects to [device] with [options].
  Future<Result<void>> connect(
    BluetoothDevice device,
    ConnectionOptions options,
  );

  /// Disconnects the link to [deviceId].
  Future<Result<void>> disconnect(String deviceId);

  /// Reads the current RSSI of a connected device.
  Future<Result<RssiReading>> readRssi(String deviceId);

  /// Requests an MTU of [mtu] bytes (typically 512).
  Future<Result<MtuNegotiationResult>> requestMtu(String deviceId, int mtu);

  /// Discovers and returns the GATT services of a connected device.
  Future<Result<List<GattService>>> discoverServices(String deviceId);

  /// Reads a characteristic.
  Future<Result<List<int>>> readCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
  });

  /// Writes a characteristic (with or without response).
  Future<Result<void>> writeCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    bool withoutResponse = false,
    bool reliable = false,
  });

  /// Subscribes or unsubscribes a characteristic notification/indication.
  Future<Result<void>> setCharacteristicNotification({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required bool enabled,
    bool indications = false,
  });

  /// Starts the secure foreground service (background scan/advertise).
  Future<Result<void>> startForegroundService({required String reason});

  /// Stops the foreground service.
  Future<Result<void>> stopForegroundService();

  /// Transport event stream: state changes, scan results, connections,
  /// RSSI, notifications. Decoded by the implementation.
  Stream<BluetoothTransportEvent> get events;

  /// Stream of the application transport state machine snapshots.
  Stream<BluetoothRadioState> get radioStateStream;
}

/// Snapshot of radio, permission and battery status.
@immutable
final class BluetoothRadioSnapshot {
  const BluetoothRadioSnapshot({
    required this.radio,
    required this.permission,
    required this.batterySaver,
    required this.maxConcurrentConnections,
  });

  final BluetoothRadioState radio;
  final BluetoothPermissionState permission;
  final bool batterySaver;
  final int maxConcurrentConnections;
}

/// Events emitted by the transport (decoded from the event channel).
@immutable
sealed class BluetoothTransportEvent {
  const BluetoothTransportEvent();
}

final class RadioStateChangedEvent extends BluetoothTransportEvent {
  const RadioStateChangedEvent(this.radio);
  final BluetoothRadioState radio;
}

final class ScanResultEvent extends BluetoothTransportEvent {
  const ScanResultEvent(this.result);
  final ScanResult result;
}

final class ScanStateChangedEvent extends BluetoothTransportEvent {
  const ScanStateChangedEvent({required this.scanning, required this.scanId});
  final bool scanning;
  final String? scanId;
}

final class AdvertisingStateChangedEvent extends BluetoothTransportEvent {
  const AdvertisingStateChangedEvent({
    required this.active,
    required this.advertisingId,
  });
  final bool active;
  final String? advertisingId;
}

final class ConnectionChangedEvent extends BluetoothTransportEvent {
  const ConnectionChangedEvent({
    required this.deviceId,
    required this.state,
    this.mtu,
    this.errorCode,
  });
  final String deviceId;
  final String state;
  final int? mtu;
  final String? errorCode;
}

/// MTU was negotiated for a link (result of `requestMtu`).
///
/// Distinct from the state-machine [MtuNegotiatedEvent] in `bluetooth_events.dart`.
final class MtuResultEvent extends BluetoothTransportEvent {
  const MtuResultEvent(this.deviceId, this.requestedMtu, this.actualMtu);
  final String deviceId;
  final int requestedMtu;
  final int actualMtu;
}

final class RssiEvent extends BluetoothTransportEvent {
  const RssiEvent(this.reading);
  final RssiReading reading;
}

final class CharacteristicChangedEvent extends BluetoothTransportEvent {
  const CharacteristicChangedEvent({
    required this.deviceId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.value,
    required this.indication,
  });
  final String deviceId;
  final String serviceUuid;
  final String characteristicUuid;
  final List<int> value;
  final bool indication;
}

final class PermissionChangedEvent extends BluetoothTransportEvent {
  const PermissionChangedEvent(this.state);
  final BluetoothPermissionState state;
}

/// A transport-level failure surfaced by the native side as an event
/// (scan timeout, scan failure). Carries the stable `ble.*` code so
/// listeners can react without string sniffing.
final class TransportErrorEvent extends BluetoothTransportEvent {
  const TransportErrorEvent({
    required this.code,
    required this.message,
    this.context,
  });

  final String code;
  final String? message;
  final String? context;
}
