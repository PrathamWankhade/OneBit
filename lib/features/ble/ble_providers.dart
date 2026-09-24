import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/ble/ble_uuids.dart';
import 'package:onebit/features/ble/discovered_device.dart';
import 'package:onebit/features/reliable/transfer.dart';

/// Application-scoped BLE service.
///
/// The service is lazily initialized when first read and disposed
/// when the ProviderScope is torn down. It does not block app startup.
final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Current BLE state, exposed as a synchronous read for widgets.
///
/// This provider starts with [BleState.unknown] and updates whenever
/// the native transport emits a state change.
final bleStateProvider =
    StateNotifierProvider<BleStateNotifier, BleState>((ref) {
  final service = ref.watch(bleServiceProvider);
  return BleStateNotifier(service);
});

/// Notifier that initializes the BLE service and listens for state changes.
class BleStateNotifier extends StateNotifier<BleState> {
  BleStateNotifier(this._service) : super(const BleState()) {
    _init();
  }

  final BleService _service;
  StreamSubscription<BleState>? _stateSub;

  Future<void> _init() async {
    try {
      await _service.initialize();
    } catch (e) {
      AppLogger.error('BLE initialization failed', e);
    }
    if (!mounted) return;
    state = _service.current;

    _stateSub = _service.stateStream.listen((bleState) {
      if (mounted) state = bleState;
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  /// Request BLE permissions. Returns the resulting permission state.
  Future<BlePermissionState> requestPermissions() {
    return _service.requestPermissions();
  }

  /// Attempt recovery after permanent permission denial.
  Future<BlePermissionState> recoverPermissions() {
    return _service.recoverPermissions();
  }

  /// Open the system Bluetooth settings screen.
  Future<void> openBluetoothSettings() {
    return _service.openBluetoothSettings();
  }

  /// Start BLE advertising with default OneBit configuration.
  ///
  /// If [identityPublicKeyBytes] is provided, it is embedded in the
  /// BLE advertisement as a OneBit identity payload.
  Future<String> startAdvertising({
    BleAdvertiseConfig? config,
    List<int>? identityPublicKeyBytes,
  }) {
    final effectiveConfig = config ??
        BleAdvertiseConfig(identityPublicKeyBytes: identityPublicKeyBytes);
    // If config was provided but no identity key, merge it in.
    if (config != null && identityPublicKeyBytes != null) {
      return _service.startAdvertising(
        BleAdvertiseConfig(
          serviceUuid: config.serviceUuid,
          mode: config.mode,
          localName: config.localName,
          identityPublicKeyBytes: identityPublicKeyBytes,
        ),
      );
    }
    return _service.startAdvertising(effectiveConfig);
  }

  /// Stop BLE advertising.
  Future<void> stopAdvertising() {
    return _service.stopAdvertising();
  }

  /// Start a BLE scan with default OneBit configuration.
  Future<String> startScan({BleScanConfig? config}) {
    return _service.startScan(config ?? const BleScanConfig());
  }

  /// Stop the current BLE scan.
  Future<void> stopScan() {
    return _service.stopScan();
  }

  /// Stream of new/updated device discoveries during the current scan.
  Stream<DiscoveredOneBitDevice> get discoveryStream =>
      _service.discoveryStream;

  /// List of currently discovered devices.
  List<DiscoveredOneBitDevice> get discoveredDevices => _service.devices;

  // ── Connection ────────────────────────────────────────────

  /// Connect to a discovered BLE device.
  Future<BleConnectionInfo> connect(String deviceId) {
    return _service.connect(deviceId);
  }

  /// Disconnect from a BLE device.
  Future<void> disconnect(String deviceId) {
    return _service.disconnect(deviceId);
  }

  /// Discover GATT services on a connected device.
  Future<List<String>> discoverServices(String deviceId) {
    return _service.discoverServices(deviceId);
  }

  /// Get connection info for a specific device.
  BleConnectionInfo? connectionFor(String deviceId) =>
      _service.current.connectionFor(deviceId);

  // ── Characteristic Communication ────────────────────────

  /// Read a characteristic value from a connected device.
  Future<List<int>> readCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
  ) {
    return _service.readCharacteristic(
        deviceId, serviceUuid, characteristicUuid);
  }

  /// Write a value to a characteristic on a connected device.
  Future<void> writeCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
    List<int> value, {
    bool withoutResponse = false,
  }) {
    return _service.writeCharacteristic(
      deviceId,
      serviceUuid,
      characteristicUuid,
      value,
      withoutResponse: withoutResponse,
    );
  }

  /// Enable or disable notifications/indications on a characteristic.
  Future<void> setNotify(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
    bool enabled,
  ) {
    return _service.setNotify(
        deviceId, serviceUuid, characteristicUuid, enabled);
  }

  /// Send [payload] reliably with ACK and retry.
  Future<TransferResult> sendReliable(String deviceId, List<int> payload) {
    return _service.sendReliable(deviceId, payload);
  }

  /// Stream of reliable payloads received from connected devices.
  Stream<ReliableDataReceived> get reliableDataReceived =>
      _service.reliableDataReceived;

  /// Stream of characteristic value changes from connected devices.
  Stream<BleCharacteristicValue> get characteristicChanged =>
      _service.characteristicChanged;
}
