import 'dart:async';

import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/bluetooth/data/bluetooth_codecs.dart';
import 'package:onebit/features/bluetooth/data/bluetooth_methods.dart';
import 'package:onebit/features/bluetooth/data/bluetooth_platform.dart';
import 'package:onebit/features/bluetooth/domain/advertisement_config.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_device.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_errors.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_permission_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_radio_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_repository.dart';
import 'package:onebit/features/bluetooth/domain/connection_options.dart';
import 'package:onebit/features/bluetooth/domain/gatt_models.dart';
import 'package:onebit/features/bluetooth/domain/mtu_negotiation_result.dart';
import 'package:onebit/features/bluetooth/domain/rssi_reading.dart';
import 'package:onebit/features/bluetooth/domain/scan_config.dart';

/// [BluetoothRepository] over [BluetoothPlatform].
///
/// Owns the transport event stream (replayed so late subscribers see the
/// latest radio state), converts native payloads into domain models, and
/// surfaces failures as [PlatformFailure] with the stable `ble.*` code in
/// the message.
final class BluetoothRepositoryImpl implements BluetoothRepository {
  BluetoothRepositoryImpl({required this._platform, required this._logger});

  static const _tag = 'ble.transport';

  final BluetoothPlatform _platform;
  final AppLogger _logger;

  BluetoothRadioState _lastRadio = BluetoothRadioState.unknown;
  final StreamController<BluetoothTransportEvent> _events =
      StreamController<BluetoothTransportEvent>.broadcast();
  final StreamController<BluetoothRadioState> _radioStates =
      StreamController<BluetoothRadioState>.broadcast();

  /// The latest radio snapshot, safe to read synchronously.
  BluetoothRadioState get lastRadioState => _lastRadio;

  StreamSubscription<Map<String, Object?>>? _listening;

  @override
  Stream<BluetoothTransportEvent> get events => _events.stream;

  @override
  Stream<BluetoothRadioState> get radioStateStream => _radioStates.stream;

  /// Starts forwarding native events; idempotent.
  void startListening() {
    // The subscription lives for the whole app lifetime and is torn down in
    // [dispose]; owning it in a field is intentional, not a leak.
    // ignore: cancel_subscriptions
    _listening ??= _platform.events.listen(
      (map) {
        final decoded = _decodeEvent(map);
        if (decoded == null) return;
        _logger.debug('event: ${decoded.runtimeType}', tag: _tag);
        _events.add(decoded);
        if (decoded is RadioStateChangedEvent) {
          _lastRadio = decoded.radio;
          _radioStates.add(decoded.radio);
        }
      },
      onError: (Object error) {
        _logger.error('event stream failed: $error', tag: _tag);
      },
    );
  }

  /// Releases the event subscription and streams.
  void dispose() {
    _listening?.cancel();
    _events.close();
    _radioStates.close();
  }

  BluetoothTransportEvent? _decodeEvent(Map<String, Object?> map) {
    switch (map['event']) {
      case BluetoothEventTypes.stateChanged:
        return RadioStateChangedEvent(BluetoothCodecs.radioState(map));
      case BluetoothEventTypes.scanResult:
        return ScanResultEvent(
          BluetoothCodecs.scanResult(_mapOf(map['result'])),
        );
      case BluetoothEventTypes.scanStateChanged:
        return ScanStateChangedEvent(
          scanning: map['scanning'] == true,
          scanId: map['scanId'] as String?,
        );
      case BluetoothEventTypes.advertisingChanged:
        return AdvertisingStateChangedEvent(
          active: map['active'] == true,
          advertisingId: map['advertisingId'] as String?,
        );
      case BluetoothEventTypes.connectionChanged:
        return ConnectionChangedEvent(
          deviceId: map['deviceId'] as String? ?? '',
          state: map['state'] as String? ?? 'idle',
          mtu: (map['mtu'] as num?)?.toInt(),
          errorCode: map['errorCode'] as String?,
        );
      case BluetoothEventTypes.mtuNegotiated:
        return MtuResultEvent(
          map['deviceId'] as String? ?? '',
          (map['requestedMtu'] as num?)?.toInt() ?? 23,
          (map['actualMtu'] as num?)?.toInt() ?? 23,
        );
      case BluetoothEventTypes.rssi:
        return RssiEvent(BluetoothCodecs.rssiReading(map));
      case BluetoothEventTypes.characteristicChanged:
        return CharacteristicChangedEvent(
          deviceId: map['deviceId'] as String? ?? '',
          serviceUuid: map['serviceUuid'] as String? ?? '',
          characteristicUuid: map['characteristicUuid'] as String? ?? '',
          value: BluetoothCodecs.bytes(map['value']),
          indication: map['indication'] == true,
        );
      case BluetoothEventTypes.permissionChanged:
        return PermissionChangedEvent(BluetoothCodecs.permissionState(map));
      case BluetoothEventTypes.transportError:
        return TransportErrorEvent(
          code: map['code'] as String? ?? BluetoothErrorCodes.gattFailed,
          message: map['message'] as String?,
          context: map['context'] as String?,
        );
      default:
        _logger.warning('unknown event: ${map['event']}', tag: _tag);
        return null;
    }
  }

  Map<String, Object?> _mapOf(Object? raw) =>
      raw is Map ? Map<String, Object?>.from(raw) : const {};

  // ---- Repository contract ---------------------------------------------------

  @override
  Future<Result<BluetoothRadioSnapshot>> getRadioSnapshot() async {
    final result = await _platform.getState();
    return result.map((map) {
      _lastRadio = map.radioState;
      _radioStates.add(_lastRadio);
      return BluetoothRadioSnapshot(
        radio: map.radioState,
        permission: map.permissionState,
        batterySaver: map.batterySaver,
        maxConcurrentConnections: map.maxConcurrent,
      );
    });
  }

  @override
  Future<Result<BluetoothPermissionState>> requestPermissions() async {
    final result = await _platform.requestPermissions();
    return result.map((map) => map.permissionState);
  }

  @override
  Future<Result<BluetoothPermissionState>> recoverPermissions() async {
    final result = await _platform.recoverPermissions();
    return result.map((map) => map.permissionState);
  }

  @override
  Future<Result<String>> startScan(ScanConfig config) =>
      _invokeId(_platform.startScan(_scanArgs(config)));

  @override
  Future<Result<void>> stopScan(String scanId) =>
      _invokeVoid(_platform.stopScan({'scanId': scanId}));

  @override
  Future<Result<String>> startAdvertising(AdvertisementConfig config) =>
      _invokeId(_platform.startAdvertising(_advertiseArgs(config)));

  @override
  Future<Result<void>> stopAdvertising(String advertisingId) =>
      _invokeVoid(_platform.stopAdvertising({'advertisingId': advertisingId}));

  @override
  Future<Result<void>> startGattServer({required String deviceId}) =>
      _invokeVoid(_platform.startGattServer({'deviceId': deviceId}));

  @override
  Future<Result<void>> stopGattServer() =>
      _invokeVoid(_platform.stopGattServer());

  @override
  Future<Result<void>> connect(
    BluetoothDevice device,
    ConnectionOptions options,
  ) => _invokeVoid(
    _platform.connect({
      'deviceId': device.id,
      'name': device.name,
      'options': {
        'autoReconnect': options.autoReconnect,
        'maxRetries': options.maxRetries,
        'connectTimeoutMs': options.connectTimeout.inMilliseconds,
        'retryDelayMs': options.retryDelay.inMilliseconds,
        'retryBackoff': options.retryBackoff,
        'requestMtu': options.requestMtu,
      },
    }),
  );

  @override
  Future<Result<void>> disconnect(String deviceId) =>
      _invokeVoid(_platform.disconnect({'deviceId': deviceId}));

  @override
  Future<Result<RssiReading>> readRssi(String deviceId) async {
    final result = await _platform.readRssi({'deviceId': deviceId});
    return result.map(BluetoothCodecs.rssiReading);
  }

  @override
  Future<Result<MtuNegotiationResult>> requestMtu(
    String deviceId,
    int mtu,
  ) async {
    final result = await _platform.requestMtu({
      'deviceId': deviceId,
      'mtu': mtu,
    });
    return result.map((map) {
      final requested = (map['requestedMtu'] as num?)?.toInt() ?? mtu;
      final actual = (map['actualMtu'] as num?)?.toInt() ?? 23;
      return MtuNegotiationResult(
        deviceId: deviceId,
        requestedMtu: requested,
        actualMtu: actual,
        fellBack: actual < requested,
      );
    });
  }

  @override
  Future<Result<List<GattService>>> discoverServices(String deviceId) async {
    final result = await _platform.discoverServices({'deviceId': deviceId});
    return result.map((map) => BluetoothCodecs.gattServices(map['services']));
  }

  @override
  Future<Result<List<int>>> readCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    final result = await _platform.readCharacteristic({
      'deviceId': deviceId,
      'serviceUuid': serviceUuid,
      'characteristicUuid': characteristicUuid,
    });
    return result.map((map) => BluetoothCodecs.bytes(map['value']));
  }

  @override
  Future<Result<void>> writeCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    bool withoutResponse = false,
    bool reliable = false,
  }) => _invokeVoid(
    _platform.writeCharacteristic({
      'deviceId': deviceId,
      'serviceUuid': serviceUuid,
      'characteristicUuid': characteristicUuid,
      'value': value,
      'withoutResponse': withoutResponse,
      'reliable': reliable,
    }),
  );

  @override
  Future<Result<void>> setCharacteristicNotification({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required bool enabled,
    bool indications = false,
  }) => _invokeVoid(
    _platform.setNotify({
      'deviceId': deviceId,
      'serviceUuid': serviceUuid,
      'characteristicUuid': characteristicUuid,
      'enabled': enabled,
      'indications': indications,
    }),
  );

  @override
  Future<Result<void>> startForegroundService({required String reason}) =>
      _invokeVoid(_platform.startForegroundService({'reason': reason}));

  @override
  Future<Result<void>> stopForegroundService() =>
      _invokeVoid(_platform.stopForegroundService());

  // ---- Shared invocation helpers ----------------------------------------------

  Future<Result<String>> _invokeId(
    Future<Result<Map<String, Object?>>> call,
  ) async {
    final result = await call;
    return result.fold((map) {
      final id = map['id'] as String?;
      if (id == null || id.isEmpty) {
        return const Err<String>(
          PlatformFailure(message: 'ble.invalid_response'),
        );
      }
      return Ok(id);
    }, Err<String>.new);
  }

  Future<Result<void>> _invokeVoid(
    Future<Result<Map<String, Object?>>> call,
  ) async {
    final result = await call;
    if (result.isErr) {
      return Err(result.failure!);
    }
    return const Ok(null);
  }

  Map<String, Object?> _scanArgs(ScanConfig config) => {
    'mode': config.mode.rawName,
    'serviceUuids': config.serviceUuids,
    'adaptive': config.adaptive,
    'duplicateFilter': config.duplicateFilter,
    'timeoutMs': config.timeout?.inMilliseconds,
    'rssiIntervalMs': config.rssiReportInterval?.inMilliseconds,
    'background': config.background,
  };

  Map<String, Object?> _advertiseArgs(AdvertisementConfig config) => {
    'mode': config.mode.rawName,
    'serviceUuid': config.serviceUuid,
    'manufacturerId': config.manufacturerId,
    'manufacturerData': config.manufacturerData,
    'localName': config.localName,
    'txPower': config.txPower,
    'background': config.background,
    'rotationCount': config.rotationCount,
  };
}
