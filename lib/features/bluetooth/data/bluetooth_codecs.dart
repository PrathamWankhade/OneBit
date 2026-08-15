import 'dart:typed_data';

import 'package:onebit/features/bluetooth/domain/advertisement.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_device.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_permission_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_radio_state.dart';
import 'package:onebit/features/bluetooth/domain/gatt_models.dart';
import 'package:onebit/features/bluetooth/domain/rssi_reading.dart';
import 'package:onebit/features/bluetooth/domain/scan_result.dart';

/// Maps transport payloads (JSON-serializable) to domain models and back.
///
/// The native side is the only producer of these shapes; the codecs are the
/// only consumer. Unknown/missing keys degrade to safe defaults instead of
/// throwing, because native callbacks may omit optional fields.
abstract final class BluetoothCodecs {
  const BluetoothCodecs._();

  // ---- Decoding -------------------------------------------------------------

  static BluetoothRadioState radioState(Map<String, Object?> map) =>
      BluetoothRadioState.fromWire(map['state'] as String?);

  static BluetoothPermissionState permissionState(Map<String, Object?> map) =>
      BluetoothPermissionState.fromWire(map['permission'] as String?);

  static BluetoothDevice device(Map<String, Object?> map) => BluetoothDevice(
    id: map['id'] as String? ?? '',
    name: map['name'] as String?,
    addressType: BluetoothAddressType.fromWire(map['addressType'] as String?),
  );

  static ScanResult scanResult(Map<String, Object?> map) {
    final deviceMap = _mapOf(map['device']);
    final adMap = _mapOf(map['advertisement']);
    final manufacturer = <int, Uint8List>{};
    final rawManufacturer = _mapOf(adMap['manufacturerData']);
    for (final entry in rawManufacturer.entries) {
      final id = int.tryParse(entry.key);
      if (id != null) manufacturer[id] = _bytesOf(entry.value);
    }
    final serviceData = <String, Uint8List>{
      for (final entry in _mapOf(adMap['serviceData']).entries)
        entry.key: _bytesOf(entry.value),
    };
    return ScanResult(
      device: device(deviceMap),
      rssiDb: (map['rssiDb'] as num?)?.toInt() ?? -127,
      timestamp: _dateOf(map['timestamp']),
      connectable: map['connectable'] == true,
      advertisement: Advertisement(
        localName: adMap['localName'] as String?,
        txPowerLevel: (adMap['txPowerLevel'] as num?)?.toInt(),
        serviceUuids: _stringsOf(adMap['serviceUuids']),
        manufacturerData: manufacturer,
        serviceData: serviceData,
      ),
    );
  }

  static RssiReading rssiReading(Map<String, Object?> map) => RssiReading(
    deviceId: map['deviceId'] as String? ?? '',
    rssiDb: (map['rssi'] as num?)?.toInt() ?? -127,
    smoothedDb: (map['smoothed'] as num?)?.toDouble() ?? -127,
    timestamp: _dateOf(map['timestamp']),
  );

  static List<GattService> gattServices(Object? raw) {
    if (raw is! List) return const [];
    final services = <GattService>[];
    for (final entry in raw) {
      final map = _mapOf(entry);
      final characteristics = <GattCharacteristic>[];
      for (final rawCharacteristic in _listOf(map['characteristics'])) {
        final cMap = _mapOf(rawCharacteristic);
        characteristics.add(
          GattCharacteristic(
            uuid: cMap['uuid'] as String? ?? '',
            properties: (cMap['properties'] as num?)?.toInt() ?? 0,
            descriptors: _stringsOf(cMap['descriptors']),
            value: _bytesOf(cMap['value']),
          ),
        );
      }
      services.add(
        GattService(
          uuid: map['uuid'] as String? ?? '',
          isPrimary: map['isPrimary'] == true,
          characteristics: characteristics,
        ),
      );
    }
    return services;
  }

  static List<int> bytes(Object? raw) => _bytesOf(raw);

  // ---- Helpers --------------------------------------------------------------

  static Map<String, Object?> _mapOf(Object? raw) =>
      raw is Map ? Map<String, Object?>.from(raw) : const {};

  static List<Object?> _listOf(Object? raw) => raw is List ? raw : const [];

  static Uint8List _bytesOf(Object? raw) {
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    if (raw is List) {
      return Uint8List.fromList([for (final e in raw) (e as num).toInt()]);
    }
    return Uint8List(0);
  }

  static List<String> _stringsOf(Object? raw) =>
      _listOf(raw).whereType<String>().toList();

  static DateTime _dateOf(Object? raw) {
    final millis = (raw as num?)?.toInt();
    return millis == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.fromMillisecondsSinceEpoch(millis);
  }
}
