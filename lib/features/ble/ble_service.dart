import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/ble/ble_uuids.dart';
import 'package:onebit/features/ble/discovered_device.dart';
import 'package:onebit/features/reliable/ble_service_channel.dart';
import 'package:onebit/features/reliable/reliable_transfer_manager.dart';
import 'package:onebit/features/reliable/transfer.dart';

/// Channel names matching the Kotlin `BluetoothChannel`.
const _methodsChannel = 'dev.onebit.onebit/ble';
const _eventsChannel = 'dev.onebit.onebit/ble_events';

/// Dart-side bridge to the native BLE transport.
///
/// The service exposes a [stateStream] that mirrors the Kotlin
/// `BluetoothManager.getState()` + state events. It never
/// blocks the UI thread — all native calls are asynchronous.
class BleService {
  BleService({MethodChannel? methodChannel, EventChannel? eventChannel})
      : _methods = methodChannel ?? const MethodChannel(_methodsChannel),
        _events = eventChannel ?? const EventChannel(_eventsChannel);

  final MethodChannel _methods;
  final EventChannel _events;

  StreamSubscription<dynamic>? _eventSub;
  StreamController<BleState> _stateController =
      StreamController<BleState>.broadcast();

  bool _initialized = false;
  bool _disposed = false;

  /// Current state snapshot (synchronous read for Riverpod).
  BleState _current = const BleState();
  BleState get current => _current;

  /// Whether the service has been disposed.
  bool get isDisposed => _disposed;

  /// Stream of BLE state changes.
  Stream<BleState> get stateStream => _stateController.stream;

  /// Discovered devices during the current scan session.
  final Map<String, DiscoveredOneBitDevice> _devices = {};
  List<DiscoveredOneBitDevice> get devices => List.unmodifiable(_devices.values);

  /// Stream of new/updated device discoveries.
  StreamController<DiscoveredOneBitDevice> _discoveryController =
      StreamController<DiscoveredOneBitDevice>.broadcast();
  Stream<DiscoveredOneBitDevice> get discoveryStream =>
      _discoveryController.stream;

  /// Stream of characteristic value changes (notify/indication).
  StreamController<BleCharacteristicValue> _characteristicChangedController =
      StreamController<BleCharacteristicValue>.broadcast();

  /// Stream of characteristic value changes from connected devices.
  Stream<BleCharacteristicValue> get characteristicChanged =>
      _characteristicChangedController.stream;

  // ── Reliable Transfer ───────────────────────────────────

  /// Per-device reliable transfer managers, keyed by device ID.
  final Map<String, ReliableTransferManager> _reliableManagers = {};

  /// Per-device reliable channels, keyed by device ID.
  final Map<String, BleServiceChannel> _reliableChannels = {};

  /// Stream controller for reliable payloads received from peers.
  StreamController<ReliableDataReceived> _reliableDataController =
      StreamController<ReliableDataReceived>.broadcast();

  /// Stream of reliable payloads received from connected devices.
  Stream<ReliableDataReceived> get reliableDataReceived =>
      _reliableDataController.stream;

  /// Send [payload] reliably to [deviceId] with ACK and retry.
  ///
  /// Returns [TransferResult.delivered] when the peer acknowledges,
  /// [TransferResult.failed] after retries are exhausted, or
  /// [TransferResult.cancelled] on disconnect/disposal.
  Future<TransferResult> sendReliable(
    String deviceId,
    List<int> payload,
  ) async {
    _assertNotDisposed();
    var manager = _reliableManagers[deviceId];
    if (manager == null) {
      manager = _createReliableManager(deviceId);
      _reliableManagers[deviceId] = manager;
    }
    return manager.sendReliable(payload);
  }

  ReliableTransferManager _createReliableManager(String deviceId) {
    final channel = BleServiceChannel(service: this, deviceId: deviceId);
    channel.startListening();
    _reliableChannels[deviceId] = channel;
    return ReliableTransferManager(
      channel: channel,
      onDataReceived: (payload, transferId) {
        if (!_reliableDataController.isClosed) {
          _reliableDataController.add(ReliableDataReceived(
            deviceId: deviceId,
            payload: payload,
            transferId: transferId,
          ));
        }
      },
    );
  }

  /// Push a discovered device through the stream (for testing).
  @visibleForTesting
  void pushDiscovery(DiscoveredOneBitDevice device) {
    if (!_discoveryController.isClosed) {
      _discoveryController.add(device);
    }
  }

  /// Push a connection state change through the state stream (for testing).
  @visibleForTesting
  void pushConnectionState(String deviceId, BleConnectionState state) {
    _applyConnectionStateEvent({
      'deviceId': deviceId,
      'state': state.name,
    });
  }

  /// Push a characteristic value change through the stream (for testing).
  @visibleForTesting
  void pushCharacteristicChanged({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    bool isIndication = false,
  }) {
    if (!_characteristicChangedController.isClosed) {
      _characteristicChangedController.add(BleCharacteristicValue(
        deviceId: deviceId,
        serviceUuid: serviceUuid,
        characteristicUuid: characteristicUuid,
        value: value,
        isIndication: isIndication,
      ));
    }
  }

  /// Throws if the service has been disposed.
  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('BleService has been disposed');
    }
  }

  /// Initialize the service by fetching the initial state and
  /// subscribing to native events.
  ///
  /// Safe to call after [dispose] — recreates internal controllers.
  Future<void> initialize() async {
    if (_initialized) return;

    // Reset disposed flag — initialize() is safe to call after dispose.
    _disposed = false;

    // Recreate controllers if the service was previously disposed.
    if (_stateController.isClosed) {
      _stateController = StreamController<BleState>.broadcast();
    }
    if (_discoveryController.isClosed) {
      _discoveryController =
          StreamController<DiscoveredOneBitDevice>.broadcast();
    }
    if (_characteristicChangedController.isClosed) {
      _characteristicChangedController =
          StreamController<BleCharacteristicValue>.broadcast();
    }
    if (_reliableDataController.isClosed) {
      _reliableDataController =
          StreamController<ReliableDataReceived>.broadcast();
    }

    _initialized = true;

    AppLogger.info('BLE service initializing');

    _listenToEvents();

    try {
      final result = await _methods.invokeMethod<Map>('getState');
      if (result != null) {
        _applyState(Map<String, dynamic>.from(result));
      }
      AppLogger.info('BLE service initialized: $_current');
    } on PlatformException catch (e) {
      AppLogger.error('BLE getState failed', e);
      _current = const BleState(radio: BleRadioState.unknown);
      _emitState();
    }
  }

  /// Request Bluetooth permissions from the user.
  /// Returns the resulting permission state.
  Future<BlePermissionState> requestPermissions() async {
    try {
      final result = await _methods.invokeMethod<Map>('requestPermissions');
      if (result != null) {
        _applyPermissionState(Map<String, dynamic>.from(result));
      }
      return _current.permission;
    } on PlatformException catch (e) {
      AppLogger.error('BLE requestPermissions failed', e);
      return BlePermissionState.notDetermined;
    }
  }

  /// Attempt recovery after permissions were permanently denied.
  /// This re-requests the missing permissions.
  Future<BlePermissionState> recoverPermissions() async {
    try {
      final result = await _methods.invokeMethod<Map>('recoverPermissions');
      if (result != null) {
        _applyPermissionState(Map<String, dynamic>.from(result));
      }
      return _current.permission;
    } on PlatformException catch (e) {
      AppLogger.error('BLE recoverPermissions failed', e);
      return _current.permission;
    }
  }

  /// Open the system Bluetooth settings screen.
  Future<void> openBluetoothSettings() async {
    try {
      await _methods.invokeMethod('openBluetoothSettings');
    } on PlatformException catch (e) {
      AppLogger.error('BLE openBluetoothSettings failed', e);
    }
  }

  // ── Advertising ────────────────────────────────────────────

  /// Start BLE advertising with the given [config].
  ///
  /// Returns the advertising session ID on success. If advertising is
  /// already active, returns the existing session ID without creating
  /// a duplicate.
  ///
  /// Throws [BleAdvertisingException] on failure.
  Future<String> startAdvertising(BleAdvertiseConfig config) async {
    _assertNotDisposed();
    if (_current.isAdvertising && _current.advertisingId != null) {
      AppLogger.info('BLE advertising already active: ${_current.advertisingId}');
      return _current.advertisingId!;
    }
    // Guard against concurrent start calls during the starting transition.
    if (_current.advertising == BleAdvertisingState.starting) {
      return _current.advertisingId ?? '';
    }

    _updateAdvertisingState(BleAdvertisingState.starting);

    try {
      final params = <String, dynamic>{
        'serviceUuid': config.serviceUuid,
        'mode': config.mode.name,
        'localName': config.localName,
        'background': false,
        'rotationCount': 0,
      };

      // Embed identity public key in manufacturer data if available.
      final identityPayload =
          BleIdentityProtocol.buildPayload(config.identityPublicKeyBytes);
      if (identityPayload != null) {
        params['manufacturerId'] = BleIdentityProtocol.companyId;
        params['manufacturerData'] = identityPayload;
      }

      final result = await _methods.invokeMethod<Map>(
        'startAdvertising',
        params,
      );

      if (result == null) {
        _updateAdvertisingState(BleAdvertisingState.error);
        throw const BleAdvertisingException('startAdvertising returned null');
      }

      final id = result['id'] as String? ?? 'unknown';
      _current = _current.copyWith(
        advertising: BleAdvertisingState.advertising,
        advertisingId: id,
      );
      _emitState();
      AppLogger.info('BLE advertising started: $id');
      return id;
    } on PlatformException catch (e) {
      AppLogger.error('BLE startAdvertising failed', e);
      _updateAdvertisingState(BleAdvertisingState.error);
      throw BleAdvertisingException(e.message ?? 'advertising failed');
    }
  }

  /// Stop the current BLE advertising session.
  ///
  /// Safe to call when advertising is already stopped — does not crash.
  Future<void> stopAdvertising() async {
    if (_disposed) return;
    final id = _current.advertisingId;
    if (id == null) {
      AppLogger.info('BLE advertising not active, nothing to stop');
      return;
    }

    _updateAdvertisingState(BleAdvertisingState.stopping);

    try {
      await _methods.invokeMethod('stopAdvertising', {
        'advertisingId': id,
      });
      _current = _current.copyWith(
        advertising: BleAdvertisingState.idle,
        clearAdvertisingId: true,
      );
      _emitState();
      AppLogger.info('BLE advertising stopped');
    } on PlatformException catch (e) {
      AppLogger.error('BLE stopAdvertising failed', e);
      _current = _current.copyWith(
        advertising: BleAdvertisingState.idle,
        clearAdvertisingId: true,
      );
      _emitState();
    }
  }

  /// Dispose the service and release native resources.
  Future<void> dispose() async {
    if (_current.isScanning) {
      await stopScan();
    }
    if (_current.isAdvertising) {
      await stopAdvertising();
    }
    // Disconnect any active connections.
    for (final deviceId in _current.connections.keys.toList()) {
      final info = _current.connections[deviceId];
      if (info != null && info.state != BleConnectionState.disconnected) {
        await disconnect(deviceId);
      }
    }
    // Clean up any remaining per-device resources.
    for (final deviceId in _reliableManagers.keys.toList()) {
      _cleanupPerDeviceResources(deviceId);
    }
    _reliableManagers.clear();
    _reliableChannels.clear();
    await _eventSub?.cancel();
    await _discoveryController.close();
    await _characteristicChangedController.close();
    await _reliableDataController.close();
    await _stateController.close();
    _initialized = false;
    _disposed = true;
  }

  // ── Scanning ───────────────────────────────────────────────

  /// Start a BLE scan with the given [config].
  ///
  /// Returns the scan session ID. If a scan is already active,
  /// returns the existing ID without creating a duplicate.
  ///
  /// Discovered devices are emitted on [discoveryStream] and
  /// deduplicated by device ID with RSSI updates.
  Future<String> startScan(BleScanConfig config) async {
    _assertNotDisposed();
    if (_current.isScanning && _current.scanId != null) {
      AppLogger.info('BLE scan already active: ${_current.scanId}');
      return _current.scanId!;
    }
    // Guard against concurrent start calls during the starting transition.
    if (_current.scan == BleScanState.starting) {
      return _current.scanId ?? '';
    }

    // Pre-check: Bluetooth must be on and permissions granted.
    if (_current.needsBluetoothEnable) {
      AppLogger.warning('BLE scan blocked: Bluetooth is off');
      _updateScanState(BleScanState.error);
      throw const BleScanException('Bluetooth is off');
    }
    if (!_current.isOperational && _current.radio == BleRadioState.ready) {
      // Radio is ready but permissions are missing.
      AppLogger.warning('BLE scan blocked: permissions not granted');
      _updateScanState(BleScanState.error);
      throw const BleScanException('Bluetooth permissions not granted');
    }

    _updateScanState(BleScanState.starting);

    try {
      final result = await _methods.invokeMethod<Map>(
        'startScan',
        <String, dynamic>{
          'mode': config.mode.name,
          'serviceUuids': config.serviceUuids,
          'duplicateFilter': config.duplicateFilter,
          'timeoutMs': config.timeoutMs,
          'reportDelayMs': config.reportDelayMs,
          'background': config.background,
          'rssiIntervalMs': config.rssiIntervalMs,
          'adaptive': config.adaptive,
        },
      );

      if (result == null) {
        _updateScanState(BleScanState.error);
        throw const BleScanException('startScan returned null');
      }

      final id = result['id'] as String?;
      if (id == null) {
        _updateScanState(BleScanState.error);
        throw const BleScanException('startScan returned no id');
      }

      _current = _current.copyWith(
        scan: BleScanState.scanning,
        scanId: id,
      );
      _emitState();
      AppLogger.info('BLE scan started: $id');
      return id;
    } on PlatformException catch (e) {
      AppLogger.error('BLE startScan failed', e);
      _updateScanState(BleScanState.error);
      throw BleScanException(e.message ?? 'scan failed');
    }
  }

  /// Stop the current BLE scan session.
  ///
  /// Safe to call when no scan is active — does not crash.
  Future<void> stopScan() async {
    if (_disposed) return;
    final id = _current.scanId;
    if (id == null) {
      AppLogger.info('BLE scan not active, nothing to stop');
      return;
    }

    _updateScanState(BleScanState.stopping);

    try {
      await _methods.invokeMethod('stopScan', <String, dynamic>{
        'scanId': id,
      });
    } on PlatformException catch (e) {
      AppLogger.error('BLE stopScan failed', e);
    }

    _current = _current.copyWith(
      scan: BleScanState.idle,
      clearScanId: true,
    );
    _devices.clear();
    _emitState();
    AppLogger.info('BLE scan stopped');
  }

  // ── Connection ─────────────────────────────────────────────

  /// Connect to a discovered BLE device.
  ///
  /// Returns a [BleConnectionInfo] on success. The connection lifecycle
  /// is managed by the native [ConnectionManager] which handles MTU
  /// negotiation and service discovery automatically.
  ///
  /// Throws [BleConnectionException] on failure.
  Future<BleConnectionInfo> connect(String deviceId) async {
    _assertNotDisposed();
    final existing = _current.connections[deviceId];
    if (existing != null &&
        (existing.state == BleConnectionState.connecting ||
            existing.state == BleConnectionState.connected)) {
      AppLogger.info('BLE already connected/connecting to $deviceId');
      return existing;
    }

    _updateConnection(deviceId, BleConnectionState.connecting);

    try {
      final result = await _methods.invokeMethod<Map>(
        'connect',
        <String, dynamic>{'deviceId': deviceId},
      );

      if (result == null) {
        _updateConnection(deviceId, BleConnectionState.error,
            error: 'connect returned null');
        throw const BleConnectionException('connect returned null');
      }

      AppLogger.info('BLE connect requested: $deviceId');
      // State transitions are driven by native events.
      return _current.connections[deviceId] ??
          BleConnectionInfo(
              deviceId: deviceId, state: BleConnectionState.connecting);
    } on PlatformException catch (e) {
      AppLogger.error('BLE connect failed', e);
      _updateConnection(deviceId, BleConnectionState.error,
          error: e.message ?? 'connection failed');
      throw BleConnectionException(e.message ?? 'connection failed');
    }
  }

  /// Disconnect from a BLE device.
  ///
  /// Safe to call when already disconnected or disconnecting — does not crash.
  /// Cleans up per-device resources (reliable transfer, channels)
  /// and removes the connection info from the state.
  Future<void> disconnect(String deviceId) async {
    _assertNotDisposed();
    final info = _current.connections[deviceId];
    if (info == null ||
        info.state == BleConnectionState.disconnected ||
        info.state == BleConnectionState.disconnecting) {
      AppLogger.info('BLE not connected to $deviceId, nothing to disconnect');
      return;
    }

    _updateConnection(deviceId, BleConnectionState.disconnecting);

    try {
      await _methods.invokeMethod('disconnect', <String, dynamic>{
        'deviceId': deviceId,
      });
      _updateConnection(deviceId, BleConnectionState.disconnected);
      _cleanupPerDeviceResources(deviceId);
      AppLogger.info('BLE disconnected: $deviceId');
    } on PlatformException catch (e) {
      AppLogger.error('BLE disconnect failed', e);
      _updateConnection(deviceId, BleConnectionState.disconnected);
      _cleanupPerDeviceResources(deviceId);
    }
  }

  /// Release per-device resources: reliable managers, channels, and
  /// discovered device cache entries.
  ///
  /// Called after disconnect (success or failure) and during full dispose.
  void _cleanupPerDeviceResources(String deviceId) {
    _reliableManagers[deviceId]?.onDisconnect();
    _reliableManagers.remove(deviceId);
    _reliableChannels[deviceId]?.dispose();
    _reliableChannels.remove(deviceId);
    _devices.remove(deviceId);
  }

  /// Discover GATT services on a connected device.
  ///
  /// Returns the list of discovered service UUIDs. After connection,
  /// the native layer typically performs automatic service discovery.
  /// This method can be used to explicitly trigger or verify discovery.
  Future<List<String>> discoverServices(String deviceId) async {
    final info = _current.connections[deviceId];
    if (info == null || info.state != BleConnectionState.connected) {
      throw const BleConnectionException('device not connected');
    }

    try {
      final result = await _methods.invokeMethod<Map>(
        'discoverServices',
        <String, dynamic>{'deviceId': deviceId},
      );

      if (result == null) {
        throw const BleConnectionException('discoverServices returned null');
      }

      final services = (result['services'] as List?)
              ?.map((s) => s.toString())
              .toList() ??
          [];

      final hasOneBit = services.any(
        (s) => s.toUpperCase().contains(BleUuids.oneBitServiceShort),
      );

      _updateConnection(
        deviceId,
        BleConnectionState.connected,
        servicesDiscovered: true,
        hasOneBitService: hasOneBit,
      );

      AppLogger.info(
          'BLE services discovered for $deviceId: ${services.length} services, '
          'OneBit: $hasOneBit');
      return services;
    } on PlatformException catch (e) {
      AppLogger.error('BLE discoverServices failed', e);
      _updateConnection(deviceId, BleConnectionState.error,
          error: e.message ?? 'service discovery failed');
      throw BleConnectionException(e.message ?? 'service discovery failed');
    }
  }

  // ── Characteristic Communication ─────────────────────────

  /// Read a characteristic value from a connected device.
  ///
  /// Returns the raw byte value as a list of integers.
  /// The device must be connected with services discovered.
  Future<List<int>> readCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
  ) async {
    _assertNotDisposed();
    final info = _current.connections[deviceId];
    if (info == null || info.state != BleConnectionState.connected) {
      throw const BleConnectionException('device not connected');
    }

    try {
      final result = await _methods.invokeMethod<Map>(
        'readCharacteristic',
        <String, dynamic>{
          'deviceId': deviceId,
          'serviceUuid': serviceUuid,
          'characteristicUuid': characteristicUuid,
        },
      );

      if (result == null) {
        throw const BleConnectionException('readCharacteristic returned null');
      }

      final value = (result['value'] as List?)
              ?.map((v) => (v as num).toInt())
              .toList() ??
          [];

      AppLogger.info(
          'BLE read characteristic $characteristicUuid from $deviceId: '
          '${value.length} bytes');
      return value;
    } on PlatformException catch (e) {
      AppLogger.error('BLE readCharacteristic failed', e);
      throw BleConnectionException(e.message ?? 'read failed');
    }
  }

  /// Write a value to a characteristic on a connected device.
  ///
  /// [value] is the raw byte payload as a list of integers.
  /// If [withoutResponse] is true, the write uses the no-ack type
  /// and returns immediately without waiting for acknowledgment.
  Future<void> writeCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
    List<int> value, {
    bool withoutResponse = false,
  }) async {
    _assertNotDisposed();
    final info = _current.connections[deviceId];
    if (info == null || info.state != BleConnectionState.connected) {
      throw const BleConnectionException('device not connected');
    }

    try {
      await _methods.invokeMethod(
        'writeCharacteristic',
        <String, dynamic>{
          'deviceId': deviceId,
          'serviceUuid': serviceUuid,
          'characteristicUuid': characteristicUuid,
          'value': value,
          'withoutResponse': withoutResponse,
        },
      );

      AppLogger.info(
          'BLE wrote ${value.length} bytes to $characteristicUuid on $deviceId');
    } on PlatformException catch (e) {
      AppLogger.error('BLE writeCharacteristic failed', e);
      throw BleConnectionException(e.message ?? 'write failed');
    }
  }

  /// Enable or disable notifications/indications on a characteristic.
  ///
  /// When enabled, value changes are delivered through [characteristicChanged].
  Future<void> setNotify(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
    bool enabled,
  ) async {
    _assertNotDisposed();
    final info = _current.connections[deviceId];
    if (info == null || info.state != BleConnectionState.connected) {
      throw const BleConnectionException('device not connected');
    }

    try {
      await _methods.invokeMethod(
        'setNotify',
        <String, dynamic>{
          'deviceId': deviceId,
          'serviceUuid': serviceUuid,
          'characteristicUuid': characteristicUuid,
          'enabled': enabled,
        },
      );

      AppLogger.info(
          'BLE setNotify $characteristicUuid on $deviceId: $enabled');
    } on PlatformException catch (e) {
      AppLogger.error('BLE setNotify failed', e);
      throw BleConnectionException(e.message ?? 'setNotify failed');
    }
  }

  void _updateConnection(
    String deviceId,
    BleConnectionState state, {
    bool? servicesDiscovered,
    bool? hasOneBitService,
    String? error,
  }) {
    final existing = _current.connections[deviceId];
    final info = existing?.copyWith(
          state: state,
          servicesDiscovered: servicesDiscovered,
          hasOneBitService: hasOneBitService,
          errorMessage: error,
          clearError: error == null,
        ) ??
        BleConnectionInfo(
          deviceId: deviceId,
          state: state,
          servicesDiscovered: servicesDiscovered ?? false,
          hasOneBitService: hasOneBitService ?? false,
          errorMessage: error,
        );

    final newConnections = Map<String, BleConnectionInfo>.from(
      _current.connections,
    );
    newConnections[deviceId] = info;
    _current = _current.copyWith(connections: newConnections);
    _emitState();
  }

  // ── Internal ──────────────────────────────────────────────

  void _listenToEvents() {
    _eventSub = _events.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is! Map) return;
        final type = event['event'] as String?;
        if (type == 'stateChanged' || type == 'permissionChanged') {
          _applyState(Map<String, dynamic>.from(event));
        } else if (type == 'advertisingChanged') {
          _applyAdvertisingEvent(Map<String, dynamic>.from(event));
        } else if (type == 'scanResult') {
          _applyScanResult(Map<String, dynamic>.from(event));
        } else if (type == 'scanStateChanged') {
          _applyScanStateChanged(Map<String, dynamic>.from(event));
        } else if (type == 'transportError') {
          _applyTransportError(Map<String, dynamic>.from(event));
        } else if (type == 'connectionStateChanged') {
          _applyConnectionStateEvent(Map<String, dynamic>.from(event));
        } else if (type == 'servicesDiscovered') {
          _applyServicesDiscoveredEvent(Map<String, dynamic>.from(event));
        } else if (type == 'characteristicChanged') {
          _applyCharacteristicChangedEvent(Map<String, dynamic>.from(event));
        }
      },
      onError: (Object e) {
        AppLogger.warning('BLE event stream error: $e');
      },
    );
  }

  void _applyState(Map<String, dynamic> data) {
    final radioStr = data['state'] as String? ?? 'unknown';
    final permStr = data['permission'] as String? ?? 'notDetermined';
    final batterySaver = data['batterySaver'] as bool? ?? false;
    final recoveryRequired = data['recoveryRequired'] as bool? ?? false;

    final radio = _parseRadioState(radioStr);
    final permission = _parsePermissionState(permStr);

    _current = _current.copyWith(
      radio: radio,
      permission: permission,
      batterySaver: batterySaver,
      recoveryRequired: recoveryRequired,
    );

    _emitState();
  }

  /// Apply only permission-related state without overwriting radio state.
  ///
  /// The Kotlin `requestPermissions`/`recoverPermissions` methods return
  /// only `{"permission": ...}` — a full `_applyState` call would reset
  /// `radio` to `unknown` because the `state` key is absent.
  void _applyPermissionState(Map<String, dynamic> data) {
    final permStr = data['permission'] as String? ?? 'notDetermined';
    final permission = _parsePermissionState(permStr);

    if (_current.permission == permission) return;

    _current = _current.copyWith(permission: permission);
    _emitState();
  }

  void _applyAdvertisingEvent(Map<String, dynamic> data) {
    final active = data['active'] as bool? ?? false;
    final id = data['advertisingId'] as String?;

    if (active) {
      _current = _current.copyWith(
        advertising: BleAdvertisingState.advertising,
        advertisingId: id,
      );
    } else {
      _current = _current.copyWith(
        advertising: BleAdvertisingState.idle,
        clearAdvertisingId: true,
      );
    }

    _emitState();
  }

  void _applyScanResult(Map<String, dynamic> data) {
    final device = DiscoveredOneBitDevice.fromScanResult(data);

    // Only keep devices advertising the OneBit service UUID.
    // The native ScanFilter already performs this check, but we
    // apply it here as a safety net.
    if (!device.isOneBit) return;

    // Deduplicate: update RSSI if seen, otherwise add.
    final existing = _devices[device.deviceId];
    if (existing != null) {
      _devices[device.deviceId] =
          existing.withUpdatedRssi(device.rssi, device.timestamp);
    } else {
      _devices[device.deviceId] = device;
    }

    if (!_discoveryController.isClosed) {
      _discoveryController.add(_devices[device.deviceId]!);
    }
  }

  void _applyScanStateChanged(Map<String, dynamic> data) {
    final active = data['scanning'] as bool? ?? false;
    final id = data['scanId'] as String?;

    if (!active) {
      _current = _current.copyWith(
        scan: BleScanState.idle,
        clearScanId: true,
      );
      _devices.clear();
      _emitState();
    } else if (id != null) {
      _current = _current.copyWith(
        scan: BleScanState.scanning,
        scanId: id,
      );
      _emitState();
    }
  }

  void _applyTransportError(Map<String, dynamic> data) {
    final code = data['code'] as String? ?? '';
    final context = data['context'] as String? ?? '';

    if (context == 'scan') {
      AppLogger.warning('BLE scan transport error: $code');
      _updateScanState(BleScanState.error);
      _devices.clear();
    }
  }

  void _applyConnectionStateEvent(Map<String, dynamic> data) {
    final deviceId = data['deviceId'] as String?;
    final stateStr = data['state'] as String?;
    if (deviceId == null || stateStr == null) return;

    final state = _parseConnectionState(stateStr);
    _updateConnection(deviceId, state);

    // Handle Bluetooth being turned off during connection.
    if (state == BleConnectionState.disconnected &&
        _current.radio == BleRadioState.off) {
      AppLogger.warning('BLE device disconnected due to Bluetooth OFF');
    }

    // On disconnect: clean up all per-device resources.
    if (state == BleConnectionState.disconnected) {
      _cleanupPerDeviceResources(deviceId);
    }
  }

  void _applyServicesDiscoveredEvent(Map<String, dynamic> data) {
    final deviceId = data['deviceId'] as String?;
    final services = (data['services'] as List?)
            ?.map((s) => s.toString())
            .toList() ??
        [];
    if (deviceId == null) return;

    final hasOneBit = services.any(
      (s) => s.toUpperCase().contains(BleUuids.oneBitServiceShort),
    );

    _updateConnection(
      deviceId,
      BleConnectionState.connected,
      servicesDiscovered: true,
      hasOneBitService: hasOneBit,
    );

    AppLogger.info(
        'BLE services discovered event for $deviceId: ${services.length} services, '
        'OneBit: $hasOneBit');
  }

  void _applyCharacteristicChangedEvent(Map<String, dynamic> data) {
    final deviceId = data['deviceId'] as String?;
    final serviceUuid = data['serviceUuid'] as String?;
    final characteristicUuid = data['characteristicUuid'] as String?;
    final value = (data['value'] as List?)
            ?.map((v) => (v as num).toInt())
            .toList() ??
        [];
    final isIndication = data['indication'] as bool? ?? false;

    if (deviceId == null || serviceUuid == null || characteristicUuid == null) {
      return;
    }

    final bleValue = BleCharacteristicValue(
      deviceId: deviceId,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      value: value,
      isIndication: isIndication,
    );

    if (!_characteristicChangedController.isClosed) {
      _characteristicChangedController.add(bleValue);
    }

    // Feed incoming data to the reliable transfer manager for this device.
    if (characteristicUuid == BleUuids.communicationCharacteristic) {
      _reliableManagers[deviceId]?.handleIncoming(value);
    }

    AppLogger.info(
        'BLE characteristic changed: $characteristicUuid from $deviceId: '
        '${value.length} bytes');
  }

  static BleConnectionState _parseConnectionState(String value) {
    return switch (value) {
      'idle' || 'disconnected' => BleConnectionState.disconnected,
      'connecting' => BleConnectionState.connecting,
      'connected' ||
      'mtuNegotiation' ||
      'serviceDiscovery' ||
      'ready' =>
        BleConnectionState.connected,
      'disconnecting' => BleConnectionState.disconnecting,
      'error' || 'reconnecting' => BleConnectionState.error,
      _ => BleConnectionState.disconnected,
    };
  }

  void _updateScanState(BleScanState newState) {
    _current = _current.copyWith(scan: newState);
    _emitState();
  }

  void _updateAdvertisingState(BleAdvertisingState newState) {
    _current = _current.copyWith(advertising: newState);
    _emitState();
  }

  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(_current);
    }
  }

  static BleRadioState _parseRadioState(String value) {
    return switch (value) {
      'ready' => BleRadioState.ready,
      'initializing' => BleRadioState.initializing,
      'off' => BleRadioState.off,
      'unavailable' => BleRadioState.unavailable,
      _ => BleRadioState.unknown,
    };
  }

  static BlePermissionState _parsePermissionState(String value) {
    return switch (value) {
      'granted' => BlePermissionState.granted,
      'partial' => BlePermissionState.partial,
      'notDetermined' => BlePermissionState.notDetermined,
      'permanentlyDenied' => BlePermissionState.permanentlyDenied,
      'adapterOff' => BlePermissionState.adapterOff,
      _ => BlePermissionState.notDetermined,
    };
  }
}
