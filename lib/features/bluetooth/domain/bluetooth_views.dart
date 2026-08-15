import 'package:flutter/foundation.dart';

import 'bluetooth_connection_state.dart';
import 'bluetooth_device.dart';
import 'bluetooth_state.dart';
import 'rssi_reading.dart';

/// UI-facing snapshot of the application state machine.
@immutable
final class BluetoothMachineView {
  const BluetoothMachineView({
    this.state = BluetoothState.bluetoothOff,
    this.deviceId,
    this.negotiatedMtu = 23,
  });

  /// Application transport state.
  final BluetoothState state;

  /// Peer of the monitored link, when one exists.
  final String? deviceId;

  /// Negotiated MTU (23 until negotiation).
  final int negotiatedMtu;

  bool get radioOperational => state.isRadioOperational;

  BluetoothMachineView copyWith({
    BluetoothState? state,
    String? deviceId,
    int? negotiatedMtu,
  }) => BluetoothMachineView(
    state: state ?? this.state,
    deviceId: deviceId ?? this.deviceId,
    negotiatedMtu: negotiatedMtu ?? this.negotiatedMtu,
  );
}

/// UI-facing scan lifecycle plus discovered devices.
@immutable
final class BluetoothScanView {
  const BluetoothScanView({
    this.scanning = false,
    this.scanId,
    this.devices = const [],
  });

  final bool scanning;
  final String? scanId;
  final List<BluetoothDevice> devices;

  BluetoothScanView copyWith({
    bool? scanning,
    String? scanId,
    List<BluetoothDevice>? devices,
  }) => BluetoothScanView(
    scanning: scanning ?? this.scanning,
    scanId: scanId ?? this.scanId,
    devices: devices ?? this.devices,
  );
}

/// Per-link lifecycle and latest RSSI for the developer panels.
@immutable
final class BluetoothLinksView {
  const BluetoothLinksView({this.connections = const {}, this.rssi = const {}});

  /// deviceId → latest connection stage.
  final Map<String, BluetoothConnectionState> connections;

  /// deviceId → latest smoothed RSSI reading.
  final Map<String, RssiReading> rssi;

  BluetoothLinksView copyWith({
    Map<String, BluetoothConnectionState>? connections,
    Map<String, RssiReading>? rssi,
  }) => BluetoothLinksView(
    connections: connections ?? this.connections,
    rssi: rssi ?? this.rssi,
  );
}

/// Advertising + peripheral GATT server lifecycle for the dev panels.
@immutable
final class BluetoothAdvertisingView {
  const BluetoothAdvertisingView({
    this.advertising = false,
    this.advertisingId,
    this.gattServer = false,
  });

  final bool advertising;
  final String? advertisingId;
  final bool gattServer;

  BluetoothAdvertisingView copyWith({
    bool? advertising,
    String? advertisingId,
    bool? gattServer,
  }) => BluetoothAdvertisingView(
    advertising: advertising ?? this.advertising,
    advertisingId: advertisingId ?? this.advertisingId,
    gattServer: gattServer ?? this.gattServer,
  );
}
