import 'package:onebit/features/ble/ble_uuids.dart';

/// BLE radio and permission state exposed to the application.
///
/// Wire values match the Kotlin `BluetoothManager.getState()` map exactly.
/// The state machine is intentionally flat — the application checks
/// `isOperational` rather than juggling every intermediate state.
enum BleRadioState {
  /// Bluetooth adapter is on and ready.
  ready,

  /// Adapter is transitioning to ON.
  initializing,

  /// Adapter is OFF or transitioning to OFF.
  off,

  /// No Bluetooth adapter found on this device.
  unavailable,

  /// Could not determine the state (platform error).
  unknown,
}

enum BlePermissionState {
  /// All required runtime permissions are granted.
  granted,

  /// Some but not all permissions are granted.
  partial,

  /// Permissions have not been requested yet.
  notDetermined,

  /// Permissions are denied and the system won't show the dialog.
  permanentlyDenied,

  /// Adapter is off so permission checks are skipped.
  adapterOff,
}

/// Current scanning session state.
enum BleScanState {
  /// No scan is active.
  idle,

  /// Scan is starting.
  starting,

  /// Actively scanning.
  scanning,

  /// Scan is stopping.
  stopping,

  /// Scan encountered an error.
  error,
}

/// Configuration for a BLE scan session.
class BleScanConfig {
  const BleScanConfig({
    this.serviceUuids = const [BleUuids.oneBitService],
    this.mode = BleScanMode.active,
    this.duplicateFilter = true,
    this.timeoutMs = 30000,
    this.reportDelayMs = 0,
    this.background = false,
    this.rssiIntervalMs = 0,
    this.adaptive = true,
  });

  /// Service UUIDs to filter for. Only devices advertising these UUIDs
  /// will be reported.
  final List<String> serviceUuids;

  /// Scan power mode.
  final BleScanMode mode;

  /// Whether to filter duplicate results (same device).
  final bool duplicateFilter;

  /// Hard timeout in milliseconds. `null` or `0` means no timeout.
  final int? timeoutMs;

  /// Report delay in milliseconds for batched results.
  final int reportDelayMs;

  /// Whether the scan runs in the background.
  final bool background;

  /// RSSI update interval in milliseconds. `0` disables periodic RSSI events.
  final int rssiIntervalMs;

  /// Whether to use adaptive duty cycling.
  final bool adaptive;
}

/// BLE scan power modes matching the Kotlin `ScannerManager` parameters.
enum BleScanMode {
  /// Low latency, higher power.
  active,

  /// Low power, higher latency.
  passive,
}

/// Error thrown when BLE scanning operations fail.
class BleScanException implements Exception {
  const BleScanException(this.message);
  final String message;

  @override
  String toString() => 'BleScanException: $message';
}

/// Connection state for a BLE device.
enum BleConnectionState {
  /// Not connected.
  disconnected,

  /// Connection in progress.
  connecting,

  /// GATT connection established, services not yet discovered.
  connected,

  /// Disconnecting from the device.
  disconnecting,

  /// Connection or service discovery failed.
  error,
}

/// Per-device connection information.
class BleConnectionInfo {
  const BleConnectionInfo({
    required this.deviceId,
    this.state = BleConnectionState.disconnected,
    this.servicesDiscovered = false,
    this.hasOneBitService = false,
    this.errorMessage,
  });

  final String deviceId;
  final BleConnectionState state;
  final bool servicesDiscovered;
  final bool hasOneBitService;
  final String? errorMessage;

  bool get isConnected =>
      state == BleConnectionState.connected && servicesDiscovered;

  bool get isConnecting => state == BleConnectionState.connecting;

  bool get isDisconnected => state == BleConnectionState.disconnected;

  bool get hasError => state == BleConnectionState.error;

  BleConnectionInfo copyWith({
    BleConnectionState? state,
    bool? servicesDiscovered,
    bool? hasOneBitService,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BleConnectionInfo(
      deviceId: deviceId,
      state: state ?? this.state,
      servicesDiscovered: servicesDiscovered ?? this.servicesDiscovered,
      hasOneBitService: hasOneBitService ?? this.hasOneBitService,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleConnectionInfo &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          state == other.state &&
          servicesDiscovered == other.servicesDiscovered &&
          hasOneBitService == other.hasOneBitService &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
        deviceId,
        state,
        servicesDiscovered,
        hasOneBitService,
        errorMessage,
      );

  @override
  String toString() =>
      'BleConnectionInfo(deviceId: $deviceId, state: $state, '
      'servicesDiscovered: $servicesDiscovered, '
      'hasOneBitService: $hasOneBitService, '
      'errorMessage: $errorMessage)';
}

/// Error thrown when BLE connection operations fail.
class BleConnectionException implements Exception {
  const BleConnectionException(this.message);
  final String message;

  @override
  String toString() => 'BleConnectionException: $message';
}

/// Error thrown when BLE advertising operations fail.
class BleAdvertisingException implements Exception {
  const BleAdvertisingException(this.message);
  final String message;

  @override
  String toString() => 'BleAdvertisingException: $message';
}

/// A characteristic value change received from a connected device.
class BleCharacteristicValue {
  const BleCharacteristicValue({
    required this.deviceId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.value,
    this.isIndication = false,
  });

  final String deviceId;
  final String serviceUuid;
  final String characteristicUuid;
  final List<int> value;
  final bool isIndication;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleCharacteristicValue &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          serviceUuid == other.serviceUuid &&
          characteristicUuid == other.characteristicUuid &&
          _listEquals(value, other.value) &&
          isIndication == other.isIndication;

  @override
  int get hashCode => Object.hash(
        deviceId,
        serviceUuid,
        characteristicUuid,
        Object.hashAll(value),
        isIndication,
      );

  @override
  String toString() =>
      'BleCharacteristicValue(deviceId: $deviceId, '
      'serviceUuid: $serviceUuid, characteristicUuid: $characteristicUuid, '
      'value: ${value.length} bytes, isIndication: $isIndication)';

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A reliable payload received from a connected device.
class ReliableDataReceived {
  const ReliableDataReceived({
    required this.deviceId,
    required this.payload,
    required this.transferId,
  });

  final String deviceId;
  final List<int> payload;
  final int transferId;

  @override
  String toString() =>
      'ReliableDataReceived(deviceId: $deviceId, '
      'payload: ${payload.length} bytes, transferId: $transferId)';
}

/// Snapshot of the BLE subsystem at a point in time.
class BleState {
  const BleState({
    this.radio = BleRadioState.unknown,
    this.permission = BlePermissionState.notDetermined,
    this.batterySaver = false,
    this.recoveryRequired = false,
    this.advertising = BleAdvertisingState.idle,
    this.advertisingId,
    this.scan = BleScanState.idle,
    this.scanId,
    this.connections = const {},
  });

  /// Whether BLE operations (scanning, advertising) can proceed.
  bool get isOperational =>
      radio == BleRadioState.ready && permission == BlePermissionState.granted;

  /// Whether the user needs to enable Bluetooth.
  bool get needsBluetoothEnable => radio == BleRadioState.off;

  /// Whether permissions need to be requested.
  bool get needsPermissionRequest =>
      permission == BlePermissionState.notDetermined ||
      permission == BlePermissionState.partial;

  /// Whether the user has permanently denied permissions and must
  /// be directed to app settings.
  bool get needsManualRecovery => recoveryRequired;

  /// Whether BLE advertising is currently active.
  bool get isAdvertising => advertising == BleAdvertisingState.advertising;

  /// Whether BLE scanning is currently active.
  bool get isScanning => scan == BleScanState.scanning;

  /// Whether any device is currently connected or connecting.
  bool get isConnectingOrConnected => connections.values.any(
        (c) =>
            c.state == BleConnectionState.connecting ||
            c.state == BleConnectionState.connected,
      );

  final BleRadioState radio;
  final BlePermissionState permission;
  final bool batterySaver;
  final bool recoveryRequired;
  final BleAdvertisingState advertising;
  final BleScanState scan;

  /// The native advertising session ID, if currently advertising.
  final String? advertisingId;

  /// The native scan session ID, if currently scanning.
  final String? scanId;

  /// Per-device connection information, keyed by device ID.
  final Map<String, BleConnectionInfo> connections;

  /// Get connection info for a specific device.
  BleConnectionInfo? connectionFor(String deviceId) =>
      connections[deviceId];

  /// Whether a specific device is connected with services discovered.
  bool isDeviceConnected(String deviceId) {
    final info = connections[deviceId];
    return info != null && info.isConnected;
  }

  BleState copyWith({
    BleRadioState? radio,
    BlePermissionState? permission,
    bool? batterySaver,
    bool? recoveryRequired,
    BleAdvertisingState? advertising,
    String? advertisingId,
    bool clearAdvertisingId = false,
    BleScanState? scan,
    String? scanId,
    bool clearScanId = false,
    Map<String, BleConnectionInfo>? connections,
  }) {
    return BleState(
      radio: radio ?? this.radio,
      permission: permission ?? this.permission,
      batterySaver: batterySaver ?? this.batterySaver,
      recoveryRequired: recoveryRequired ?? this.recoveryRequired,
      advertising: advertising ?? this.advertising,
      advertisingId: clearAdvertisingId
          ? null
          : (advertisingId ?? this.advertisingId),
      scan: scan ?? this.scan,
      scanId: clearScanId ? null : (scanId ?? this.scanId),
      connections: connections ?? this.connections,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleState &&
          runtimeType == other.runtimeType &&
          radio == other.radio &&
          permission == other.permission &&
          batterySaver == other.batterySaver &&
          recoveryRequired == other.recoveryRequired &&
          advertising == other.advertising &&
          advertisingId == other.advertisingId &&
          scan == other.scan &&
          scanId == other.scanId &&
          _mapEquals(connections, other.connections);

  @override
  int get hashCode => Object.hash(
        radio,
        permission,
        batterySaver,
        recoveryRequired,
        advertising,
        advertisingId,
        scan,
        scanId,
      );

  @override
  String toString() =>
      'BleState(radio: $radio, permission: $permission, '
      'batterySaver: $batterySaver, recoveryRequired: $recoveryRequired, '
      'advertising: $advertising, advertisingId: $advertisingId, '
      'scan: $scan, scanId: $scanId, '
      'connections: ${connections.length} devices)';

  static bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (entry.value != b[entry.key]) return false;
    }
    return true;
  }
}
