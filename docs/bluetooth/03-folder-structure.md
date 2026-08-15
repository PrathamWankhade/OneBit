# OneBit Bluetooth Transport — Folder Structure

Every file in the transport layer, what it owns, and what stays out of it.

---

## 1. Dart — `lib/features/bluetooth/`

Clean Architecture: `presentation` (Riverpod + UI), `domain` (contract, models,
state, pure logic), `data` (channels, codecs, repository implementations).

```
lib/features/bluetooth/
├── bluetooth_service.dart          Transport lifecycle. Owns the MVP-worthy
│                                   connection between the repository event
│                                   stream and the rest of the app; started once
│                                   at boot (`bootstrap.dart`), idempotent,
│                                   never throws.
├── domain/                         Model layer: no Flutter, no channels.
│   ├── bluetooth_repository.dart   The transport contract — all methods return
│   │                               Result<T>, all events are typed. The single
│   │                               seam between the transport and the app.
│   ├── bluetooth_state_machine.dart  App-focus state machine (pure, feed-only).
│   ├── bluetooth_connection_state.dart  Wire-state enum (idle…error).
│   ├── bluetooth_events.dart       Feed events for the state machine.
│   ├── bluetooth_errors.dart      `ble.*` stable error codes.
│   ├── bluetooth_radio_state.dart   Radio lifecycle wire enum.
│   ├── bluetooth_permission_state.dart  Permission wire enum.
│   ├── bluetooth_views.dart       View models consumed by controllers/UI.
│   ├── advertisement.dart          Advertisement payload model.
│   ├── advertisement_config.dart   startAdvertising args (mode, rotation…).
│   ├── scan_config.dart            scan args (mode, adaptive…).
│   ├── scan_result.dart            Discovered-device snapshot.
│   ├── bluetooth_device.dart       Peer identity (id, name).
│   ├── connection_options.dart     connect args (autoreconnect, background…).
│   ├── gatt_models.dart            GattService/Characteristic models.
│   ├── mtu_negotiation_result.dart MTU outcome model.
│   └── rssi_reading.dart           RSSI reading model.
├── data/
│   ├── bluetooth_methods.dart      Channel method + event-type name constants.
│   ├── bluetooth_platform.dart     Facade: the only Dart surface that speaks
│   │                               to the native channels.
│   ├── method_channel_bluetooth_platform.dart  MethodChannel/EventChannel binding.
│   ├── bluetooth_codecs.dart       Wire decode helpers (maps → models).
│   ├── bluetooth_repository_impl.dart  BluetoothRepository over the platform.
│   └── nearby_peer_repository_impl.dart  Maps transport events onto the peer catalog.
└── presentation/
    ├── bluetooth_providers.dart    Riverpod providers + controllers wiring.
    ├── bluetooth_controllers.dart  Controllers (permission, scan, link, advertising).
    └── bluetooth_dev_screen.dart   Developer screen (radio/advertising/scan/logs).
```

## 2. Android — `android/app/src/main/kotlin/dev/onebit/onebit/bluetooth/`

```
bluetooth/
├── BluetoothChannel.kt             MethodChannel "dev.onebit.onebit/ble" —
│                                   dispatch + wire maps in, Result maps out.
├── BluetoothManager.kt            Orchestrator: owns scanner, advertiser, GATT
│                                   server, connection mgr, permissions, state
│                                   epochs; forwards events to the event sink.
├── BleEmitter.kt                  Outbound event sink → EventChannel.
├── callbacks/
│   └── GattEventListener.kt       The one callback interface shared by the GATT
│                                  client and server paths.
├── characteristics/
│   └── CharacteristicProfile.kt   Per-characteristic metadata: NotifyKind
│                                  classifier, property helpers, CCCD UUID.
├── advertising/
│   ├── AdvertiserManager.kt       startAdvertising/stop/dispose, power
│   │                               modes, payload rotation (variant cadence).
│   └── AdPayloadBuilder.kt        Pure AD-field builder (len|type|value) +
│                                  rotation-variant byte, JVM-testable.
├── scanner/
│   ├── ScannerManager.kt          Adaptive scan: duty-cycled windows, filters,
│   │                               RSSI cadence, scan timeout error event.
│   └── AdaptiveScanController.kt  Pure scheduling (burst/foreground/background/
│                                  idle) + battery-saver suppression.
├── connection/
│   └── ConnectionManager.kt       Physical links: read/write/notification,
│                                   MTU, RSSI, discovery, futures, indication
│                                   tracking; fail-fast on unknown links.
├── gatt/
│   ├── GattClientManager.kt         Peripheral link (central role): chunked/reliable writes.
│   └── GattServerManager.kt        Server-side GATT (peripheral role): probe/echo, CCCD subscribers, notify push.
├── mtu/
│   └── MtuPolicy.kt              MTU clamping + fallback outcome (pure).
├── rssi/
│   └── RssiSmoother.kt           EMA estimate + unstable flag (pure).
├── state/
│   └── BluetoothStateMachine.kt Per-link native state mirror (pure).
├── permissions/
│   └── PermissionManager.kt      Runtime permissions, permanentDenied tracking,
│                                 recovery.
├── foreground/
│   ├── ForegroundServiceManager.kt  Connected-device FGS lifecycle.
│   └── BluetoothForegroundService.kt
├── errors/
│   └── BleErrorCodes.kt          `ble.*` wire codes mirror BleErrors on Dart.
├── logging/
│   ├── BleLog.kt                    Tagged native logger (Kotlin→Logcat).
│   ├── LogcatSink.kt
├── utils/
│   ├── UuidUtils.kt              UUID normalization/short forms (pure).
│   └── ByteUtils.kt              Byte helpers (u16 LE, concat, …).
└── uuids/
    └── Uuids.kt                  OneBit probe/echo/id UUID constants.
```

## 3. Channel contract

| Side | Chunk |
| --- | --- |
| MethodChannel | `dev.onebit.onebit/ble` |
| EventChannel | `dev.onebit.onebit/ble_events` |
| Dart constants | `BluetoothMethods` + `BluetoothEventTypes` (data/bluetooth_methods.dart) |
| Kotlin constants | `BluetoothChannel` companions (channel file) |

Method names must match **exactly** across those two constant files; event
payloads carry an `event` discriminator understood by `BluetoothCodecs` and
`BluetoothChannel`'s emitter maps.