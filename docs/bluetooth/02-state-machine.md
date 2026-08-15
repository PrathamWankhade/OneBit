# OneBit Bluetooth Transport — State Machine

The state machine is the single source of truth governing radio + GATT
lifecycle in the transport.

- **Authority**: `BluetoothStateMachine` in Dart
  (`lib/features/bluetooth/domain/bluetooth_state_machine.dart`). It is
  pure, synchronous, side-effect free and exhaustively unit-tested. Every
  native `stateChanged`/`connectionChanged` event is fed into `handle`.
- **Mirror**: `BluetoothStateMachine.kt` on the native side so the Kotlin
  managers can gate operations without round-trips.
- **UI**: controllers watch a stream of machine snapshots.

---

## 1. States

| State | Meaning |
| --- | --- |
| `bluetoothOff` | Adapter off or unknown; radio cannot start. |
| `initializing` | Adapter on; permissions being refreshed, managers wiring. |
| `ready` | Radio initialized. Idle — a scan or advertising cycle may start. |
| `scanning` | Passive/active scan running under a `ScanConfig`. |
| `advertising` | Advertising under an `AdvertisementConfig`. |
| `deviceFound` | First confirmed peer seen during a scan (terminal for the discovery event; scanning continues). |
| `connecting` | Connect requested; GATT connection in progress. |
| `connected` | GATT link established; MTU negotiation next. |
| `mtuNegotiation` | MTU exchange in progress (bounded by configurable timeout). |
| `serviceDiscovery` | GATT services being discovered after MTU settled. |
| `ready` | Link usable: MTU negotiated **and** services discovered. Bytes can now flow. |
| `disconnecting` | Explicit disconnect in flight. |
| `disconnected` | Link closed cleanly. |
| `reconnecting` | Scheduled automatic reconnect+ backoff. |
| `error` | Unrecoverable transport failure (adapter died, fatal GATT error). |

`unavailable` (adapter missing/unsupported) is modelled as
`bluetoothUnavailable` — a terminal state distinct from `bluetoothOff`.

---

## 2. Transition graph

```
 bluetoothOff ──adapterOn──► initializing ──initialized──► ready
     ▲                            │                          │
     │                            │ initializedFailed       │ (advertising or scanning
     │                            ▼                          │   cycles, may interleave)
     │                      bluetoothUnavailable            │
     │                            │                          │
     └──────────adapterOff◄───────┴──adapterOffExitNote──────┘

 ready ──scanStarted──► scanning ──deviceFound──► connectRequested──► connecting
    ▲                      │                                            │
    │◄──scanStopped───── ┘                                           connected
    │
    ├─advertisingStarted──► advertising ──advertisingStopped──► ready
    │
 connecting ──connected──► connected ──mtuStarted──► mtuNegotiation
 mtuNegotiation ──mtuNegotiated + gattDiscovered──► ready   (guard: both)
 mtuNegotiation ──mtuFailed──► ready? No: mtuFailed is recoverable —
                                          negotiated MTU falls back, machine
                                          continues to discovery; hard
                                          failure → disconnected.

 ready ──disconnectRequested──► disconnecting ──disconnected
 disconnected ──connectRequested──► connecting
 disconnected ──reconnectRequested (auto, with backoff)──► reconnecting ──► connecting
 connecting/connected/... ──connectionLost──► reconnecting (if retries remain)
                                              ► disconnected (retries exhausted)

 any ──fatalAdapterError──► bluetoothUnavailable
 any ──adapterOff──► bluetoothOff (connection teardown implied)
```

## 3. Events (`BluetoothEvent`)

| Event | Payload |
| --- | --- |
| `adapterOn` / `adapterOff` | init cause |
| `initialized` / `initFailed(cause)` | — |
| `advertisingStarted` / `advertisingStopped` | config/rotation info |
| `scanStarted` / `scanStopped` | scanId |
| `deviceFound` | device |
| `connectRequested` | deviceId |
| `connected` | deviceId |
| `mtuStarted` / `mtuNegotiated(mtu)` | deviceId |
| `mtuFailed(cause)` | deviceId |
| `servicesDiscovered` | deviceId |
| `linkReady` | deviceId |
| `disconnectRequested` / `disconnected` | deviceId |
| `reconnectRequested` | deviceId, attempt |
| `connectionLost(cause)` | deviceId |
| `fatalAdapterError(cause)` | cause |

## 4. Guards (hang these rules)

1. `initializing → ready` only if radio initialized and permissions
   sufficient; otherwise → `bluetoothUnavailable`.
2. `connected → serviceDiscovery` requires MTU negotiation to have
   completed (or been skipped gracefully after a hard failure with
   fallback MTU).
3. `serviceDiscovery → ready` requires at least one GATT service with a
   registered transport characteristic.
4. `ready` holds both `mtuReady` and `gattReady`; the machine rejects
   any event that would otherwise fake an early ready for display.
5. `reconnecting` has a finite attempt budget; exhaustion lands on
   `disconnected` (recovery responsibility moves to the caller).
6. `adapterOff` tears down machines (sets the active device to none).

Each transition is logged with the tag `ble.state` before broadcasting.

## 5. Lifecycle mapping

| Android event | Machine event |
| --- | --- |
| `BluetoothAdapter.onStateChanged(STATE_ON)` | `adapterOn` |
| `BluetoothAdapter.onStateChanged(STATE_OFF)` | `adapterOff` |
| scan callback quirk | `scanStarted`/`scanStopped` |
| `AdvertisingSetCallback` start | `advertisingStarted` |
| GATT connection state connected | `connected` |
| GATT MTU changed callback | `mtuNegotiated` or `mtuFailed` |
| GATT services discovered | `servicesDiscovered` |
| GATT connection state disconnected | `disconnected` or `connectionLost` |
| any fatal BluetoothException | `fatal` |

## 6. Device-level state

Scanning/listening state (per device, presented on the developers screen)
is a **snapshot** derived from the machine: `connectionState` field holds
the most recent connection event per `deviceId`. The machine itself holds
application-scoped transport state; per-device allows multiple
concurrent connections (max is currently `maxConcurrentConnections` in
`ConnectionOptions`, default 4).