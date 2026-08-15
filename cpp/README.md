# C++ Core (reserved)

The native core library (`libonebit_native.so`) lands in **Phase 3** with:
COBS framing, packet codec, hash routines, and the crypto primitives that
later phases delegate to C++.

Phase 1 ships **no C++ code**. The Dart seam already exists:
`FfiBridge` (`lib/core/platform/native_ffi_bridge.dart`) — this build
truthfully reports the core as unavailable via `UnavailableFfiBridge`.

- `include/` — public C ABI headers (`onebit_native.h`).
- `src/` — implementation units.
- Wiring: CMake `externalNativeBuild` added to `android/app/build.gradle.kts`
  when the first translation unit lands.
