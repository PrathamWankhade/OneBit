import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/bluetooth/data/bluetooth_codecs.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_permission_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_radio_state.dart';
import 'package:onebit/features/bluetooth/domain/gatt_models.dart';

void main() {
  group('BluetoothCodecs', () {
    test('radio state falls back to unknown', () {
      expect(
        BluetoothCodecs.radioState({'state': 'ready'}),
        BluetoothRadioState.ready,
      );
      expect(BluetoothCodecs.radioState({}), BluetoothRadioState.unknown);
      expect(
        BluetoothCodecs.radioState({'state': 'gibberish'}),
        BluetoothRadioState.unknown,
      );
    });

    test('permission state round trip', () {
      expect(
        BluetoothCodecs.permissionState({'permission': 'denied'}),
        BluetoothPermissionState.denied,
      );
      expect(
        BluetoothCodecs.permissionState({}),
        BluetoothPermissionState.notDetermined,
      );
    });

    test('scan result decodes advertisement and bytes', () {
      final decoded = BluetoothCodecs.scanResult({
        'device': {'id': 'aa:bb:cc:dd:ee:ff', 'name': 'onebit-node'},
        'rssiDb': -61,
        'timestamp': 1700000000000,
        'connectable': true,
        'advertisement': {
          'localName': 'onebit-node',
          'txPowerLevel': -8,
          'serviceUuids': ['00001111-0000-1000-8000-00805f9b34fb'],
          'manufacturerData': {
            '276': [1, 2, 3],
          },
          'serviceData': {
            '00001111-0000-1000-8000-00805f9b34fb': [9, 8],
          },
        },
      });

      expect(decoded.device.id, 'aa:bb:cc:dd:ee:ff');
      expect(decoded.device.name, 'onebit-node');
      expect(decoded.rssiDb, -61);
      expect(decoded.connectable, isTrue);
      expect(decoded.advertisement.localName, 'onebit-node');
      expect(decoded.advertisement.txPowerLevel, -8);
      expect(decoded.advertisement.serviceUuids.single, contains('1111'));
      expect(decoded.advertisement.manufacturerData[276], [1, 2, 3]);
      expect(decoded.advertisement.serviceData.values.single, [9, 8]);
    });

    test('scan result tolerates missing fields', () {
      final decoded = BluetoothCodecs.scanResult(const {});
      expect(decoded.device.id, '');
      expect(decoded.rssiDb, -127);
      expect(decoded.advertisement.isEmpty, isTrue);
    });

    test('gatt services decode with properties and descriptors', () {
      final services = BluetoothCodecs.gattServices([
        {
          'uuid': 'svc-1',
          'isPrimary': true,
          'characteristics': [
            {
              'uuid': 'char-1',
              'properties': 0x1A,
              'descriptors': ['d1', 'd2'],
              'value': [5, 6],
            },
          ],
        },
      ]);

      expect(services.single.uuid, 'svc-1');
      final characteristic = services.single.characteristics.single;
      expect(characteristic.uuid, 'char-1');
      expect(characteristic.descriptors, ['d1', 'd2']);
      expect(characteristic.value, [5, 6]);
      expect(characteristic.supports(GattProperty.write), isTrue);
      expect(characteristic.supports(GattProperty.notify), isTrue);
      expect(characteristic.supports(GattProperty.indicate), isFalse);
    });

    test('rssi reading decodes smoothing and quality', () {
      final reading = BluetoothCodecs.rssiReading({
        'deviceId': 'd-1',
        'rssi': -52,
        'smoothed': -53.5,
        'timestamp': 1700000000000,
      });
      expect(reading.deviceId, 'd-1');
      expect(reading.rssiDb, -52);
      expect(reading.smoothedDb, -53.5);
      expect(reading.quality.name, 'excellent');
    });

    test('bytes decode from int lists and stay empty on junk', () {
      expect(BluetoothCodecs.bytes([1, 2, 3]), [1, 2, 3]);
      expect(BluetoothCodecs.bytes(Uint8List.fromList([7])), [7]);
      expect(BluetoothCodecs.bytes('nope'), isEmpty);
      expect(BluetoothCodecs.bytes(null), isEmpty);
    });
  });
}
