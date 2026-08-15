# OneBit Bluetooth Transport — Architecture

Phase 4 delivers the complete Bluetooth Low Energy transport layer for
OneBit. This document is the source of truth for **what the layer is**, how
it is built, and — just as importantly — **what it is not**.

---

## 1. Scope and boundaries

Bluetooth LE is **only** the transport: it moves bytes between two directly
connected devices. The layer must never know anything about messages, users,
chats, routing, packets, trust, identity verification, encryption or the
mesh. Those arrive in later phases on top of this transport contract.

| In scope (transport) | Out of scope (later phases) |
| --- | --- |
| Advertising, scanning, discovery | Mesh routing, TTL, duplicate detection |
| Connect / disconnect / reconnect | Packet framing, store & forward |
| MTU negotiation, RSSI monitoring | Message layer, chat semantics |
| GATT service/characteristic IO | Payload encryption |
| Connection state lifecycle | Identity verification / trust |
| Permissions, foreground service, background behavior | Neighbor tables, relay decisions |
| Battery-aware radio control | |

The transport moves **raw bytes**. The only metadata it attaches to a byte
transfer is the transport's own: which device, which GATT characteristic,
what RSSI was observed, what MTU is active.

---

## 2. Architecture overview

```
┌──────────────────────────────────────────────────────────────┐
│  Flutter (Dart)                                              │
│                                                              │
│  features/bluetooth/                                         │
│    presentation/  Riverpod controllers + developer UI        │
│    domain/        models, BluetoothStateMachine, contract    │
│    data/          BluetoothPlatform facade, codecs, impls    │
│         │                                                    │
│         │  MethodChannel  "dev.onebit.onebit/ble"            │
│         │  EventChannel   "dev.onebit.onebit/ble_events"     │
│         ▼                                                    │
├──────────────────────────────────────────────────────────────┤
│  Android (Kotlin)  dev.onebit.onebit.bluetooth               │
│                                                              │
│  BluetoothChannel → BluetoothManager (orchestrator)          │
│        │          │          │          │                    │
│        ▼          ▼          ▼          ▼                    │
│  ScannerManager  AdvertiserManager  ConnectionManager  ...   │
│        │          │          │          │                    │
│        ▼          ▼          ▼          ▼                    │
│  Android BluetoothStack (BluetoothLeScanner,                │
│    BluetoothLeAdvertiser, BluetoothGatt, ...)                │
└──────────────────────────────────────────────────────────────┘
```

**Rules that cannot be broken:**

1. Everything Bluetooth stays inside native Android. Flutter never calls
   Android BLE APIs directly and never links the `flutter_blue`-style
   plugins.
2. Dart talks to the native side exclusively through the two channels
   above, and only through the `BluetoothPlatform` facade — no widget or
   controller touches `MethodChannel` directly.
3. The native side serializes every callback into a stable event map;
   Dart decodes maps into domain models via `BluetoothCodecs`. There is no
   shared model class between the two runtimes, by design.
4. Failures cross the channel as typed error codes mapped by the Dart
   repository into the existing `Failure` hierarchy (`PlatformFailure` with
   the BLE code preserved).
5. The transport never imports mesh/identity packages in either runtime.

---

## 3. Layers

### 3.1 Native layer (Kotlin)

Located under `android/app/src/main/kotlin/dev/onebit/onebit/bluetooth/`.

| Manager | Responsibility |
| --- | --- |
| `BluetoothManager` | Orchestrator. Owns the radio lifecycle, wires all sub-managers, owns the `BluetoothStateMachine` mirror, forwards callbacks to the event sink. |
| `ScannerManager` | Passive/active scans, filters, duplicate filtering (`CALLBACK_TYPE_FIRST_MATCH` in active windows), duty-cycled adaptive intervals (`AdaptiveScanController`), timeout (`ble.scan.timeout`), device cache, RSSI cadence, Doze pause/resume (`ACTION_DEVICE_IDLE_MODE_CHANGED`). |
| `AdvertiserManager` | Advertisement payload builder (`AdPayloadBuilder`), power modes, background advertising (forces `ADVERTISE_MODE_LOW_POWER` + TX boost 0), payload rotation (variant cadence per mode). |
| `ConnectionManager` | Auto/manual connect, retry with backoff, connect timeout, disconnect, reconnect, max concurrent connections (`MAX_CONCURRENT_LINKS = 4` enforced at connect), MTU/RSSI/discovery futures (fail-fast on unknown links), long-write chunking + reliable-write sessions. |
| `GattClientManager` | GATT client per connection: discovery, read/write (chunked at negotiated MTU), long/reliable writes (`beginReliableWrite`/`executeReliableWrite`/`abortReliableWrite`), notify/indicate subscriptions (`GattEventListener` from `callbacks/`). |
| `GattServerManager` | GATT server (peripheral): service/characteristic registration, probe/echo read/write handlers, CCCD-subscriber tracking, notify/indicate push per peer; started/stopped with advertising or standalone via channel. |
| `MtuPolicy` | MTU clamping + graceful fallback (`fellBack`). |
| `RssiSmoother` | EMA RSSI sampling + unstable-flag. |
| `CharacteristicProfile` | Per-characteristic metadata: notify-kind classification, property helpers, shared CCCD UUID. |
| `PermissionManager` | Runtime permissions, permanently-denied awareness, recovery, degradation without crashes. |
| `ForegroundServiceManager` | Foreground service (`connectedDevice` type), OEM/battery-saver awareness. |
| `BleEmitter` | Outbound event sink fed into the event channel. |

Cross-cutting: `errors/` (stable `ble.*` codes), `utils/`
(`ByteUtils`, `UuidUtils`), `logging/` (tagged logcat), `callbacks/`
(shared `GattEventListener`).

### 3.2 Flutter layer (Dart)

Located under `lib/features/bluetooth/`:

- **domain/** — pure Dart, zero Flutter imports except `foundation` for
  immutability: models (`BluetoothDevice`, `ScanResult`, `Advertisement`,
  `BluetoothConnectionState`, ...), configuration value objects, the
  `BluetoothStateMachine`, and the `BluetoothRepository` contract.
- **data/** — `BluetoothPlatform` (abstract native facade),
  `MethodChannelBluetoothPlatform` (the single place that touches the
  method/event channels), `BluetoothCodecs` (map ↔ model), and the
  repository implementations (`BluetoothRepositoryImpl`,
  `NearbyPeerRepositoryImpl`).
- **presentation/** — Riverpod providers, controllers (radio state, scan
  results, advertising/GATT server, connections, RSSI), and developer
  testing screens only.
- **`bluetooth_service.dart`** — boot-time transport lifecycle
  (`BluetoothService`). Started once from `bootstrap.dart`, idempotent,
  non-throwing; owns the event subscription and keeps the transport alive
  for the app session. A "Bluetooth transport (dev)" card on the home
  console links to the developer screen.

---

## 4. Method channel contract

**Channel:** `dev.onebit.onebit/ble` (registered in `BluetoothChannel`).
**Events:** `dev.onebit.onebit/ble_events`.

All arguments/results are JSON-serializable maps. Canonical payload shapes
are defined in `lib/features/bluetooth/data/bluetooth_methods.dart`
(method names) and mirrored as `BleMethods`/`BleEventTypes` in Kotlin.

| Method | Args | Result |
| --- | --- | --- |
| `getState` | — | `{state, permissions, batterySaver, maxConcurrent, recoveryRequired}` |
| `requestPermissions` | `{includeLocation}` | `{permission}` |
| `recoverPermissions` | — | `{permission}` |
| `startScan` | `ScanConfig` map | `{scanId}` |
| `stopScan` | `{scanId}` | `{}` |
| `startAdvertising` | `AdvertisementConfig` map | `{advertisingId}` |
| `stopAdvertising` | `{advertisingId}` | `{}` |
| `startGattServer` | `{deviceId}` | `{}` |
| `stopGattServer` | — | `{}` |
| `connect` | `{deviceId, options}` | `{deviceId}` |
| `disconnect` | `{deviceId}` | `{}` |
| `readRssi` | `{deviceId}` | `{rssi}` |
| `requestMtu` | `{deviceId, mtu}` | `{mtu, actualMtu}` |
| `discoverServices` | `{deviceId}` | `[ServiceData]` |
| `readCharacteristic` | `{deviceId, serviceUuid, characteristicUuid}` | `{value}` |
| `writeCharacteristic` | `{deviceId, serviceUuid, characteristicUuid, value, withoutResponse, reliable}` | `{written}` |
| `setNotify` | `{deviceId, serviceUuid, characteristicUuid, enabled, indications}` | `{enabled}` |
| `startForegroundService` | `{reason}` | `{}` |
| `stopForegroundService` | — | `{}` |

**Event types:** `stateChanged`, `scanResult`, `scanStateChanged`,
`advertisingChanged`, `connectionChanged`, `mtuNegotiated`, `rssi`,
`characteristicChanged`, `permissionChanged`, `transportError`.

---

## 5. State machine

Full documentation lives in `docs/bluetooth/02-state-machine.md`. Summary:

```
bluetoothOff → initializing → ready
                                 ├→ scanning → (deviceFound)
                                 ├→ advertising
                                 ├→ connecting → connected → mtuNegotiation
                                 │      → serviceDiscovery → ready
                                 │      → disconnected → reconnecting → connecting
                                 └→ unavailable (adapter missing / unsupported)
```

The machine is **one truth in Dart** (`BluetoothStateMachine` in domain,
pure, unit-tested) and is **mirrored natively** (`BluetoothStateMachine.kt`)
so the native side can gate radio operations without round-trips. Guards
prevent illegal transitions (e.g. `ready` requires both MTU negotiated and
services discovered); every transition is logged and emitted as a
`stateChanged` event.

---

## 6. Class diagram (Flutter)

```
BluetoothRepository (abstract)
      ▲
BluetoothRepositoryImpl ──┐
                         uses
      BluetoothPlatform (abstract)
           ▲                    ▲
MethodChannelBluetoothPlatform     (tests) FakeBluetoothPlatform
           │ owns
      EventChannelStream ──► Stream<Map<String,Object?>>
           │ decodes
      BluetoothCodecs (static codecs)
           │ models
BluetoothDevice ScanResult Advertisement ConnectionOptions ScanConfig ...
           ▲
BluetoothStateMachine (states × events, guards)  ◄── feeds stateChanged
```

## 7. Sequence diagram — connect + ready

```
Dart repo      MethodChannel     BluetoothManager  ConnectionManager  GATT  Dart SM
   │ connect(dev)     │                │                 │             │      │
   ├─────────────────►│ invoke connect │                 │             │      │
   │                  ├───────────────►│                 │             │      │
   │                  │                │ connect(dev)    │             │      │
   │                  │                ├────────────────►│             │      │
   │                  │                │                 ├────►gatt.connect
   │                  │                │                 │◄────onConnected
   │                  │  event connectionChanged:connected                    │
   │                  ├───────────────────────────────────────────────────────►│
   │                  │                │ mtu.negotiate(dev)                    │
   │                  │                ├────────────────►│                     │
   │                  │  event mtuNegotiated:512                              │
   │                  ├───────────────────────────────────────────────────────►│
   │                  │                │ gatt.discoverServices()               │
   │                  │  event connectionChanged:serviceDiscovery              │
   │                  │  event connectionChanged:ready                         │
   │◄─ Ok(deviceId) ──┤                                                         │
   │       │ ◄────────────────────────── events stream: connectionChanged ready
```

## 8. Battery optimization strategy

- **Adaptive scanning**: background/foreground duty cycles are controlled
  by `AdaptiveScanController` — longer windows and intervals when idle,
  burst scans when the app is foregrounded or a device was just seen.
- **Advertising**: background advertising uses the largest advertising
  interval permitted, rotation of the payload across a set of rotators
  (up to 3 to survive scan-frequency interference), and stops when the
  screen is off and no discovery is pending.
- **Pause rules**: scanning stops on battery saver unless an explicit
  high-priority scan is requested; all managers honor the `BatteryAware`
  facade and `onLowMemory`/Doze callbacks.
- **Wakeups**: no polling loops; every read is driven by Android callbacks.
  RSSI monitoring throttles to configurable intervals (default 1 Hz
  connected, 4 Hz scanning) and stops on screen-off unless a listener exists.

## 9. Error handling

Every native failure returns a stable code (see
`errors/BleErrorCodes.kt` / `bluetooth_errors.dart`), e.g.
`ble.disabled`, `ble.permission.denied`, `ble.permission.recovery`,
`ble.permission.location`, `ble.unsupported`, `ble.scan.timeout`,
`ble.scan.failed`, `ble.connection.lost`, `ble.mtu.failed`,
`ble.gatt.failed`, `ble.advertise.failed`, `ble.timeout`.
Fail-fail-fast futures (`readRssi`, `discoverServices` on an unknown link)
return `ble.connection.lost` instead of silently empty results.
The Dart repository maps these onto `PlatformFailure(message: code)`
while preserving the raw details, so UI code switches on the code, never
on strings.

---

## 10. Future mesh integration

The transport exposes, and nothing else:

- **Raw byte pipes** per connection: write/notify/indicate over a
  registered set of characteristic UUIDs (`Uuids.kt`).
- **Link quality data**: smoothed RSSI per device (`LinkQuality`),
  produced specifically so the routing layer can rank neighbors.
- **A device cache** (seen devices with last-seen timestamps) the node
  registry can seed from.
- **Radio state + battery awareness** for the mesh scheduler.

The mesh phase will consume these through `BluetoothRepository` +
`NearbyPeerRepository`; the transport layer itself is done.
