# Device evidence

`docs/device-matrix.md` is the script. This page is the record of what was
actually run, on which binary, on which phone, and what came back.

A row passes only when a run below names it and its result. An empty
result is not a pass; it is a row that has not been run.

---

## Run 001 — 2026-11-04 — Redmi Note 8 — single-device baseline

**Scope:** install the published binary, confirm the upgrade path, bring
the radio up, and capture the device facts a later two-device run will be
compared against. This run does **not** exercise any multi-device row.

### Binary under test

| Fact | Value |
| --- | --- |
| Release | `v1.1.1+3` (published, non-draft, non-prerelease) |
| Asset | `OneBit-1.1.1+3-release.apk` |
| Size | 90,816,333 bytes |
| SHA-256 | `B770D8BF120B593D6376657AF5ECAE5E35CC0365B318ED7816BA3DDDA80B3FE6` |
| Downloaded from | `https://github.com/PrathamWankhade/OneBit/releases/download/v1.1.1%2B3/OneBit-1.1.1%2B3-release.apk` |

The APK was downloaded from the published release and installed over the
previous build:

```text
adb install -r OneBit-1.1.1+3-release.apk
Performing Streamed Install
Success
```

`dumpsys package dev.onebit.onebit` after the install:

```text
versionCode=3 minSdk=28 targetSdk=36
versionName=1.1.1
firstInstallTime=2026-09-28 17:27:07
lastUpdateTime=2026-11-04 18:22:47
```

`firstInstallTime` is unchanged from the 28 September install, so this was
an upgrade in place, not a fresh install. That is the debug-keystore
upgrade path described in `docs/release.md`, confirmed on hardware.

The installed `base.apk` was hashed on the device:

```text
adb shell sha256sum /data/app/.../dev.onebit.onebit-.../base.apk
b770d8bf120b593d6376657af5ecae5e35cc0365b318ed7816ba3ddda80b3fe6
```

It matches the published asset byte for byte, so everything below describes
the exact binary a user downloads from the release page.

### Device

| Fact | Value |
| --- | --- |
| Manufacturer / model | Xiaomi / Redmi Note 8 |
| Device codename | `ginkgo` |
| Android | 11 (API 30) |
| ABI | `arm64-v8a` |
| Build fingerprint | `xiaomi/ginkgo/ginkgo:11/RKQ1.201004.002/V12.5.2.0.RCOINXM:user/release-keys` |
| BLE feature | `android.hardware.bluetooth_le` present |
| Battery at run | 100 % |
| Bluetooth at run | on (`bluetooth_on=1`) |

This is the mid-range / API 30 row of the matrix, not the oldest supported
stack (`minSdk` 28) and not the newest permission model (API 34+).

### What was run

Cold start with the screen on and Bluetooth on:

```text
adb shell am force-stop dev.onebit.onebit
adb shell monkey -p dev.onebit.onebit -c android.intent.category.LAUNCHER 1
adb logcat -d --pid=$(adb shell pidof dev.onebit.onebit)
```

### Result — PASS (single-device bring-up)

The event channel came up, the native state was queried, the foreground
service was requested, advertising started, and the GATT server registered
both services:

```text
11-04 18:23:09.868 D OneBit/BLE: event stream listening
11-04 18:23:09.871 D OneBit/BLE: method: getState
11-04 18:23:09.910 D OneBit/BLE: method: startForegroundService
11-04 18:23:09.911 D OneBit/BLE: foreground hold requested (1 merge(s))
11-04 18:23:10.062 D OneBit/BLE: method: startAdvertising
11-04 18:23:10.066 D BluetoothGattServer: registerCallback() - UUID=bdca3b59-f986-43d8-b794-5f5f3982d603
11-04 18:23:10.140 D BluetoothGattServer: onServerRegistered() - status=0 serverIf=5
11-04 18:23:10.142 D BluetoothGattServer: addService() - service: a1a00000-0000-1000-8000-00805f9b34fb
11-04 18:23:10.163 D OneBit/BLE: probe service registered
11-04 18:23:10.163 D BluetoothGattServer: addService() - service: d1a00000-0000-1000-8000-00805f9b34fb
11-04 18:23:10.165 D OneBit/BLE: communication service registered
11-04 18:23:10.181 D BluetoothGattServer: onServiceAdded() - handle=40 uuid=a1a00000-0000-1000-8000-00805f9b34fb status=0
11-04 18:23:10.200 D BluetoothGattServer: onServiceAdded() - handle=46 uuid=d1a00000-0000-1000-8000-00805f9b34fb status=0
11-04 18:23:10.207 D OneBit/BLE: advertising variant 0 up: advertising-1
```

The foreground service was held at the system level:

```text
* ServiceRecord{... dev.onebit.onebit/.bluetooth.foreground.BluetoothForegroundService}
isForeground=true foregroundId=2846
startRequested=true delayedStop=false stopIfKilled=false
```

What this establishes: on this device and this Android version, the app can
register its GATT server, add both services, and put an advertisement on
the air from the published binary. It does not establish that another
device can see or connect to it.

### Anomaly — `onServiceAdded` on the framework side

Adding the second service produces a `Binder` warning on this device:

```text
11-04 18:23:10.199 W Binder  : 	at android.bluetooth.BluetoothGattServer$1.onServiceAdded(BluetoothGattServer.java:124)
11-04 18:23:10.199 W Binder  : 	at android.bluetooth.IBluetoothGattServerCallback$Stub.onTransact(IBluetoothGattServerCallback.java:200)
```

The exception is `java.lang.IndexOutOfBoundsException: Index: 1, Size: 1`,
thrown inside `android.bluetooth.BluetoothGattServer$1.onServiceAdded` —
framework code, not OneBit's. Both services still report `status=0`, and
advertising comes up immediately afterwards, so the callback failure does
not prevent the server from working on this build.

It is recorded here rather than worked around. It is a candidate
explanation if a two-device run later fails to see a service on this OEM.
No app-side change was made for it.

### Not covered by this run

- Discovery of this device by another OneBit device.
- GATT connection, MTU negotiation, characteristic reads/writes.
- A message crossing one hop or two.
- Link loss, recovery, address rotation, duplicate suppression.
- Permission revocation and background/screen-off behaviour.

Every one of those needs a second phone. See the matrix status below.

---

## Run 002 — 2026-11-05 — cold start with the radio off

**Scope:** check what a cold start does when the radio is not available.
This is a state observation, not a matrix row.

Same binary (`versionCode=3`, `versionName=1.1.1`). At the time of the
final check the adapter was off:

```text
adb shell settings get global bluetooth_on
0
adb shell dumpsys bluetooth_manager | grep -i 'enabled:'
  enabled: false
```

The cold start issued no advertising and no GATT registration:

```text
11-05 11:39:01.945 D OneBit/BLE: event stream listening
11-05 11:39:01.952 D OneBit/BLE: method: getState
11-05 11:39:01.987 D OneBit/BLE: method: startForegroundService
11-05 11:39:01.988 D OneBit/BLE: foreground hold requested (1 merge(s))
```

That matches the advertising policy in
`lib/features/ble/advertising_supervisor.dart`: the radio goes on the air
only when the transport is operational and either the Nearby screen asks
for it or "advertise continuously" is on together with discovery. With no
operational radio there is nothing to advertise on, and the app correctly
issued no command. This run is not evidence of a defect, and it is not a
pass for any matrix row.

The foreground service was still held (`isForeground=true`,
`foregroundId=2846`) with the radio off. Battery at this check: 67 %.

A UI-driven repeat of Run 001 could not be performed because the phone was
locked (`deviceLocked=1`, keyguard showing). The lock was not bypassed.

---

## Matrix status after these runs

The eight rows in `docs/device-matrix.md` are unchanged. Run 001 proves the
bring-up half of rows 1–3 on one device; none of the rows can be marked
passed without a second phone.

| Row | What it needs | Status |
| --- | --- | --- |
| 1 — oldest stack (API 28–29) | A second phone on API 28–29 | **BLOCKED — no second device** |
| 2 — mid-range (API 30–33) | A second phone; this device can be one end | **BLOCKED — no second device** |
| 3 — newest stack (API 34+) | A second phone on API 34+ | **BLOCKED — no second device** |
| 4 — permission revoked | A queued message to a peer, then revoke/grant | **BLOCKED — no second device** |
| 5 — Bluetooth off/on | A queued message to a peer, then toggle the radio | **BLOCKED — no second device** |
| 6 — address rotation | A paired peer and a rotation | **BLOCKED — no second device** |
| 7 — two hops | Three phones in a line | **BLOCKED — no second/third device** |
| 8 — walk away | A peer and physical distance | **BLOCKED — no second device** |

The emulator cannot substitute: it has no Bluetooth adapter, so it cannot
answer any of the questions these rows ask.

---

## Reproducing Run 001

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

# 1. Install the published binary over whatever is there.
& $adb install -r OneBit-1.1.1+3-release.apk

# 2. Confirm the version and that it was an upgrade.
& $adb shell dumpsys package dev.onebit.onebit |
    Select-String 'versionName|versionCode|firstInstallTime|lastUpdateTime'

# 3. Confirm the installed bytes match the release asset.
$apk = (& $adb shell pm path dev.onebit.onebit).Trim() -replace '^package:', ''
& $adb shell "sha256sum $apk"

# 4. Cold start with Bluetooth on and the screen awake, then read the log.
& $adb logcat -c
& $adb shell am force-stop dev.onebit.onebit
& $adb shell monkey -p dev.onebit.onebit -c android.intent.category.LAUNCHER 1
Start-Sleep -Seconds 15
$p = (& $adb shell pidof dev.onebit.onebit).Trim()
& $adb logcat -d --pid=$p |
    Select-String 'OneBit/BLE|BluetoothGattServer|Binder'
```

Advertising on a cold start depends on the settings described above. If no
`startAdvertising` line appears, open **Nearby**, which is the explicit
discovery intent, or turn on **Advertise continuously** in mesh settings.
