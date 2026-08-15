# OneBit Bluetooth Transport — Repository Interfaces

The `BluetoothRepository` contract (Dart) — the one seam the app uses for the
transport — plus the native equivalents it maps to. Callers get `Result<T>`;
every failure is a stable `ble.*` code. Nothing is thrown across the layer.

## 1. Events (`BluetoothRepository.events`)

A `Stream<BluetoothTransportEvent>`. Sealed hierarchy (see
`domain/bluetooth_repository.dart`):

| Event | Payload notes | Emitted native via `event` key |
| --- | --- | --- |
| `RadioStateChangedEvent` | radio `BluetoothRadioState` | `stateChanged` |
| `PermissionChangedEvent` | permission state | `permissionChanged` |
| `AdvertisingStateChangedEvent` | `active`, `advertisingId` | `advertisingChanged` |
| `ScanResultEvent` | `ScanResult` (device, rssi, ts, connectable) | `scanResult` |
| `ConnectionChangedEvent` | device id, state wire name | `connectionChanged` |
| `MtuResultEvent` | `MtuNegotiationResult` | `mtuResult` |
| `RssiEvent` | `RssiReading` | `rssiChanged` |
| `TransportErrorEvent` | `code`/`message`/`context` | `transportError` |

**New in Phase 4:** `TransportErrorEvent` — carries `ble.scan.timeout` (scan
deadline), `ble.scan.failed`, `ble.permission.recovery`/`.location`
(SecurityException), and future transport failures, with a `context` hint
(`"scan"`, `"permission"`, …).

## 2. Commands

| Method | Args | Result | Notes |
| --- | --- | --- | --- |
| `getRadioSnapshot()` | — | `BluetoothRadioSnapshot` (radio + permission + batterySaver + maxConcurrent) | native adds `recoveryRequired` |
| `requestPermissions()` | — | `BluetoothPermissionState` | triggers platform dialog |
| `recoverPermissions()` | — | `BluetoothPermissionState` | requests only missing; degrades gracefully when permanently denied |
| `startScan(ScanConfig)` | mode (`passive`/`active`), `adaptive`, … | scan id | duty-cycled when adaptive |
| `stopScan(String id)` | | `void` | |
| `startAdvertising(AdvertisementConfig)` | localName, txPowerBoost, serviceUuid, manufacturerId/Data, rotationCount | advertising id | auto-starts GATT server when serviceUuid set |
| `stopAdvertising(String id)` | | `void` | stops GATT server too |
| `startGattServer({deviceId})` | | `void` | standalone server (also reached via advertising) |
| `stopGattServer()` | | `void` | |
| `connect(device, ConnectionOptions)` | | `void` | |
| `disconnect(deviceId)` | | `void` | |
| `discoverServices(deviceId)` | | `List<GattService>` | fail-fast on unknown link |
| `readCharacteristic(...)` | serviceUuid/characteristicUuid/value/id | bytes | |
| `writeCharacteristic(...)` | + withoutResponse / reliable | `void` | |
| `setCharacteristicNotification(...)` | enabled, indications | `void` | tracks indication flavor |
| `readRssi(deviceId)` | | `RssiReading` | fail-fast on unknown link |
| `requestMtu(deviceId, mtu)` | | `MtuNegotiationResult` | clamps to 23, `fellBack` flag |
| `startForegroundService(reason)` / `stopForegroundService()` | | `void` | |

## 3. Wire fidelity — native must never drift

Every method/event name carries an exact string. `BluetoothMethods` /
`BluetoothEventTypes` (data/bluetooth_methods.dart) and `BluetoothChannel`
(channel file) must stay in lock-step:

- methods: `getState, requestPermissions, recoverPermissions, startScan,
  stopScan, startAdvertising, stopAdvertising, startGattServer, stopGattServer,
  connect, disconnect, discoverServices, readCharacteristic, writeCharacteristic,
  setCharacteristicNotification, readRssi, requestMtu, startForegroundService,
  stopForegroundService`
- events: `stateChanged, permissionChanged, advertisingChanged, scanResult,
  connectionChanged, mtuResult, rssiChanged, transportError`

`BluetoothErrorCodes.ble.*` (Dart) == `BleErrorCodes` values (Kotlin):
`ble.unsupported, ble.permission.denied, ble.permission.recovery, ble.permission.location,
ble.bluetooth.off, ble.scan.timeout, ble.scan.failed, ble.advertising.failed,
ble.connection.lost, ble.mtu.failed, ble.rssi.failed, ble.gatt.failed,…`