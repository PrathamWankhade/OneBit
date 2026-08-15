# OneBit Bluetooth Transport — Sequence Diagrams

End-to-end flows (Dart → channel → Kotlin → Bluetooth stack) for the parts of
the transport built in Phase 4: GATT-server advertising, adaptive scanning,
permission recovery, and the app-boot service. All methods return `Result<T>`;
natives failures surface as `ble.*` codes, never as thrown exceptions Dart-side.

## 1. Peripheral start (advertising + GATT server)

```
App/boot ─▶ BluetoothService.start()
   │ reconfigure via repository.startAdvertising(AdvertisementConfig(
   │   serviceUuid: PROBE_SERVICE, rotationCount: 3, localName: …))
   ▼
BluetoothRepositoryImpl.startAdvertising(config)
   │  args = codec → wire map (mode, serviceUuid, manufacturerId,
   │                        localName, txPowerBoost, background, rotation)
   ▼
MethodChannelBluetoothPlatform.invoke("startAdvertising", args)
   │  result: "advertising-3"
   ▼
BluetoothChannel → BluetoothManager.startAdvertising(args)
   │  ① serviceUuid present → GattServerManager.start(deviceId)
   │       → BluetoothGattServer.registerService(probe/echo/…)
   │  ② AdvertiserManager.startAdvertising(mode, …)  [variant 0]
   │  ③ if rotationShown → schedule variant rotation on the handler
   ▼
Bluetooth stack: startAdvertising(callback)
   │ onStartSuccess → "advertisingChanged" event {active:true, id}
   ▼
EventChannel → BluetoothCodecs → AdvertisingStateChangedEvent
   ├─▶ BluetoothAdvertisingController (dev screen "Advertise" panel)
   └─▶ BluetoothService logs "advertising up"

… variant switch (rotation scheduler):
   rotationIndex++ → stopVariant() → startVariant(variantIndex)
   └─ new seq byte (AdPayloadBuilder.rotationVariant) appended to manufacturer data
```

## 2. Central scan — adaptive duty cycle and timeout

```
Dev screen ─▶ ScanController.startScan(ScanConfig(mode, adaptive: true))
   ▼
BluetoothRepositoryImpl.startScan → platform.invoke("startScan")
   ▼ (empty args → ignore, data path)
BluetoothManager.startScan → ScannerManager.startScan(…, adaptive=true)
   ▼
ScannerManager picks a window via AdaptiveScanController:
   onDeviceSeen(nowMs) → burst (2000ms window / 3000ms cycle, active scan)
   foreground         → 3000/10000 (passive)
   background         → 2000/30000
   battery-saver      → suppresses burst (ex startBeacon background → idle 2s/60s)
   ▼
handler.postDelayed cycle runnable → startWindow(startScan/stopScan) per schedule
   ▼
scanCallback (BluetoothLeScanner): foundDevice → rssi cadence (RssiSmoother)
   ▼
emitter.send("scanResult", …) → EventChannel → ScanResultEvent
   ├─ BluetoothScanController feed
   └─ NearbyPeerRepositoryImpl → peers catalog

On dead-line (scan timeout):
   ScannerManager.stopScan(id, timedOut=true)
   ├─ emit "scanStateChanged": scanning=false
   └─ emit "transportError": code="ble.scan.timeout", context="scan"
```

## 3. Scan failure surfaces (was silent)

```
adapter startScan SecurityException/onScanFailed
   ▼
ScannerManager.onScanFailed
   → BleException(PERMISSION_RECOVERY_REQUIRED | LOCATION_REQUIRED, "scan…")
   → emit "transportError": {event:"transportError", code:"ble.*", message…}
   → Dart: TransportErrorEvent(code, message, context)
```

## 4. Permission recovery

```
Dev screen [Radio] ── Recover ──▶ BluetoothPermissionController.recover()
   ▼
repository.recoverPermissions()
   ▼
platform.invoke("recoverPermissions") → channel → BluetoothManager.recoverPermissions()
   └─ PermissionManager.recover(activity) → request() (only missing perms)
   ▼ (onResult) → state "granted"|"denied"|"permanentlyDenied"
   → BluetoothPermissionState → controller AsyncData
```

## 5. Connected batch write / read with MTU

(unchanged contract; + pointed readRssi/discovery now fails fast)

```
  (peer)          GattClientManager             ConnectionManager
   │            onServicesDiscovered/subscribe flows into Completables
   ▼── writeCharacteristic ─▶  char.writeValue
   ▼── readCharacteristic  ─▶  handler
rssiAndWait(deviceId)     —— no link? ——▶ failedFuture(BleException CONNECTION_LOST)
   ▼── async response     onCharacteristicChanged (indication tracked from notifyKinds)
```

## 6. Boot wiring

```
bootstrap.dart
   ├─ appLoggerProvider etc.
   ├─ …read bluetoothServiceProvider (BluetoothService)
   ├─ start() ─▶ getRadioSnapshot(): on radio ready, subscribe repository.events
   └─ appShellProvider → OneBitApp (home)
```