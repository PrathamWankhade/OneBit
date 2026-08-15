# OneBit Bluetooth Transport — Class Diagram

The transport's key classes and how they connect, for both sides of the
channel. Pure-logic classes are marked **(pure)** — they run under JVM unit
tests and Dart unit tests without any Android framework.

## 1. Dart side (`lib/features/bluetooth/`)

```
BluetoothRepository (interface)                     BluetoothService
  + events: Stream<BluetoothTransportEvent>            + start()/stop()
  + getRadioSnapshot/requestPermissions/...           + owns the event subscription;
  + connect/disconnect/readRssi/requestMtu            + started at boot; idempotent
  + read/writeCharacteristic/setNotification          + exposure: ended/ deviceId
  + startScan/startAdvertising (+GATT server,
      recover)                                        BluetoothStateMachine (pure)
        ^                                                  + handle(event): state?
        | implements
BluetoothRepositoryImpl ──uses──▶ BluetoothPlatform (facade)      ^
        |                                          BluetoothControllers (Riverpod)
        |                                BluetoothService (owns the event stream)
  (decode events)                         |wires|                     |
BluetoothCodecs ──decodes──▶ BluetoothTransportEvent ── feeds ─▶ via providers/UI
        ▲                                    │
        │ uses                              (BluetoothDevScreen panels)
MethodChannelBluetoothPlatform ──▶ "dev.onebit.onebit/ble" (MethodChannel)
                                    "dev.onebit.onebit/ble_events" (EventChannel)
```

Key ownership rules:

- Only `MethodChannelBluetoothPlatform` touches `MethodChannel`/`EventChannel`;
  tests substitute it with a fake facade.
- `BluetoothRepository` is the transport's only outward contract; consumers
  (`NearbyPeerRepositoryImpl`, controllers, `BluetoothService`) depend on it.
- `BluetoothService` is the boot-time owner of the event subscription
  (`bootstrap.dart` starts it once).

## 2. Android side (`dev.onebit.onebit.bluetooth`)

```
BluetoothChannel (MethodCallHandler)──calls──▶ BluetoothManager
   "dev.onebit.onebit/ble"                        │ orchestrator
        │                                        │ owns:
        │                                        ├── PrivateBleEmitter (→ EventChannel)
        ▼                                        ├── ScannerManager ─ Adapter
HandleResult/Result maps ◀── throws BleException  ├── AdvertiserManager ─ Adapter
   (ble.* codes)                                 │       └── AdPayloadBuilder (pure)
                                                 ├── ConnectionManager (GATT central)
                                                 │     ├── GattClientManager
                                                 │     ├── GattEventListener (callbacks/)
                                                 │     ├── MtuPolicy (pure)
                                                 │     ├── RssiSmoother (pure)
                                                 │     └── BluetoothStateMachine (pure)
                                                 ├── GattServerManager (GATT peripheral)
                                                 │     └── GattEventListener
                                                 ├── PermissionManager (androidx.core)
                                                 ├── ForegroundServiceManager
                                                 ├── ScannerManager ──▶ AdaptiveScanController
                                                 ├── CharacteristicProfile (characteristics)
                                                 └── BleLog (logging) everywhere
```

### Key collaborations (new in this phase)

| Class | Collaborator | What was hooked up |
| --- | --- | --- |
| `BluetoothManager.startAdvertising(…serviceUuid)` | `GattServerManager.start(deviceId)` | Peripheral GATT starts automatically with ads when a service UUID is supplied |
| `BluetoothManager.stopAdvertising` | `GattServerManager.stop()` | And stops with the ads |
| `BluetoothManager.startGattServer/stopGattServer` | `GattServerManager` | Standalone server control surfaced through the channel |
| `ScannerManager` | `AdaptiveScanController` | Duty-cycled windows + battery-saver suppression |
| `ScannerManager` | `ScanSettings` | `duplicateFilter` maps to `CALLBACK_TYPE_FIRST_MATCH` (active windows); passive report-delay batching keeps `ALL_MATCHES` |
| `ScannerManager` | `BluetoothManager` | Doze (`ACTION_DEVICE_IDLE_MODE_CHANGED`) pauses scans; `resume()` restarts the adaptive/fixed window |
| `GattServerManager` | `subscribers` map | CCCD descriptor write toggles per-peer notify/indicate subscriptions; echo writes push `notifyCharacteristicChanged` + `emitEcho` |
| `GattClientManager` | `BluetoothGatt` | Long writes chunk at negotiated MTU (`coerceIn(20, 509)`); reliable session via `beginReliableWrite`/`executeReliableWrite`/`abortReliableWrite`, driven by `ConnectionManager.onCharacteristicWrite` |
| `ConnectionManager` | `Link.ReliableWrite` | `writeCharacteristicAndWait(…, reliable)` sessions with commit-on-final-chunk; cap at `MAX_CONCURRENT_LINKS = 4` |
| `AdvertiserManager` | `buildSettings(mode, txPowerBoost, background)` | `background` forces `ADVERTISE_MODE_LOW_POWER` + TX boost 0 |
| `ScannerManager.onScanFailed/timeout` | `BleEmitter` | Typed `transportError` events (`ble.scan.timeout`, `ble.scan.failed`) |
| `ConnectionManager.setNotify("/onCharacteristicChanged")` | `Link.notifyKinds` | Correct `indication` flag on read (was always false) |
| `ConnectionManager.readRssiAndWait/…` | `CompletableFuture.failedFuture(BleException)` | Unknown link now fails fast, not silently empty |
| `PermissionManager` | `deniedOnce`, `ActivityCompat` | `hasPermanentlyDenied`, `missingPermissions`, `recover` |
| `CharacteristicProfile` | `GattClientManager`/`GattServerManager` | Shared CCCD + notify-kind classification |

## 3. Shared contracts

| Contract | Dart | Kotlin |
| --- | --- | --- |
| `ble.*` error codes | `BluetoothErrorCodes` | `BleErrorCodes` |
| scan modes | `lowPower`/`balanced`/`lowLatency` in ScanConfig | same wire strings |
| advertising modes | `lowPower`/`balanced`/`lowLatency` | same |
| state wire names | `BluetoothState` | `BtConnectionState.wireName` |
| event discriminator | `BluetoothEventTypes` | emitter `event` keys |
| MTU/clamps | `MtuNegotiationResult` | Kotlin mirror: `MtuPolicy`/`MtuOutcome` |