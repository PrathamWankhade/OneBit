# Device matrix

The test suite proves the stack's logic, not a phone's radio. Bluetooth
is where Android OEMs differ most: the MTU a link negotiates, whether a
write above it is fragmented or refused, what a revoked permission looks
like, and how aggressively a backgrounded app is frozen. None of that can
be observed from a desktop test runner, so this page is the script for
running OneBit on hardware — and an honest record of what has and has not
been run.

> **Status: one single-device baseline recorded, no multi-device row run.**
> On 2026-11-04 the published `1.1.1+3` binary was installed on a Redmi
> Note 8 (Android 11) and brought its GATT server and advertisement up —
> see [device-evidence.md](device-evidence.md). That is the bring-up half
> of rows 1–3 only. Every row below still needs a second phone, and is
> marked **BLOCKED** in the evidence record until one is attached. The
> automated coverage listed in each row is green in CI; the hardware
> column stays empty until someone runs the row and fills in the date and
> build.

## What the automated tests already pin

Run all of it with `flutter test` (Dart) and
`cd android && ./gradlew :app:testDebugUnitTest` (JVM); CI runs both.

| Behaviour | Where it is pinned |
| --- | --- |
| MTU negotiation falls back to 23 on failure | `android/app/src/test/.../MtuPolicyTest.kt`, `mtu/MtuPolicy.kt` |
| A write never exceeds the negotiated MTU minus 3 | `bluetooth/gatt/GattClientManager.kt` (`payloadLimit`), `MtuPolicyTest` |
| A payload larger than one packet is split and reassembled | `test/packet_chunking_test.dart`, I10.5 in `test/cross_layer_integration_test.dart` |
| A message too large for one packet crosses two hops whole | I10.5 — "a body too large for one packet…" |
| A BLE address rotation keeps one identity and one thread | I10.2 — "a new BLE address carries the same identity across every hop" |
| Radio/permission states are modelled, not guessed | `android/app/src/test/.../BluetoothStateMachineTest.kt`, `bluetooth/state/BluetoothStateMachine.kt` |
| A radio that disappears keeps the outbox; its return delivers once | I10.5 — "a radio that goes away holds the outbox…" |
| Routes are learned from advertisements and used | I10.1 in `test/cross_layer_integration_test.dart` |
| The outbox and the relay shelf are both bounded | I10.3 in `test/cross_layer_integration_test.dart` |
| Every word under a bubble is earned end to end | I10.4 in `test/cross_layer_integration_test.dart` |

## The matrix

Run each row with two or three phones. At least one pair must be
different OEMs: two identical phones hide exactly the differences this
page exists to find.

| # | Device class | Android | Why this row | What to do | Pass |
| --- | --- | --- | --- | --- | --- |
| 1 | Low-end phone, BLE 4.2 | 9–10 (API 28–29) | Oldest supported stack (`minSdk` is 28); MTU often stays at 23 | Send a 1500-character message to a peer two hops away | Arrives whole; no truncation; bubble ends at Delivered then Read |
| 2 | Mid-range phone, BLE 5.0 | 11–13 (API 30–33) | The common case; MTU usually negotiates to 185+ | Same message; watch for a `mtuNegotiated` value above 23 | Arrives whole; the log shows the negotiated MTU, not the default |
| 3 | Current phone, BLE 5.3 | 14–16 (API 34+) | Newest permission model and background limits | Same message, then background the app mid-send and reopen it | Send resumes or is queued, never lost; badge clears when the thread is opened |
| 4 | Any row, permission revoked | any | "Nearby devices" can be revoked while the app is open | Revoke the permission with a message queued, then grant it again | The queue survives; the message leaves after the grant; exactly one copy arrives |
| 5 | Any row, Bluetooth off/on | any | The adapter can vanish mid-flight | Turn Bluetooth off with a message queued, then on | Bubble says Retrying while off; Delivered after on; no duplicates |
| 6 | Any two rows, address rotation | any | Android rotates BLE addresses; identity must not | Pair, chat, wait for rotation (or toggle Bluetooth), chat again | One thread, one identity, no duplicate conversation |
| 7 | Any row, two hops | any | A real relay is a third phone, not a mock | Three phones in a line, A and C out of range of each other | A↔C messages cross through B; status words match what B actually did |
| 8 | Any row, walk away | any | Links drop with distance, not with a flag | Start a send, walk out of range, come back | Retrying while out of range; Delivered on return; no duplicate rows |

## Recording a run

Results go in [`device-evidence.md`](device-evidence.md), one section per
run, with the device, Android version, build, date, result and the log
excerpt that supports it. Copy this table into the pull request or issue
that reports the run as well, one row per device. A row with an empty
result is a row that was not run.

| Date | Build (`OneBit-x.y.z+n`) | Device / OEM | Android | Negotiated MTU | Rows run | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| — | — | — | — | — | — | not run | — |

The build name is stamped on the APK by
`android/app/build.gradle.kts` (`OneBit-<version>+<build>-<mode>.apk`) and
shown in **Settings → About**, so a report can always name the exact
binary it describes.

## What this page does not claim

- It does not claim any multi-device row has been tested. The single-device
  bring-up in [device-evidence.md](device-evidence.md) is recorded there;
  the rows above stay empty until a two- or three-phone run fills them.
- It does not claim OEM-specific behaviour is handled. If a row fails,
  that is the finding — write it down with the MTU and the Android
  version rather than working around it silently.
- It does not replace the automated suite. The rows above are the parts
  of the stack that only a radio can answer for.
