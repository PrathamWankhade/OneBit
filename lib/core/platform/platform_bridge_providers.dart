import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/platform/channel_names.dart';
import 'package:onebit/core/platform/method_channel_native_bridge.dart';
import 'package:onebit/core/platform/native_channel_bridge.dart';
import 'package:onebit/core/platform/native_ffi_bridge.dart';

/// The real [NativeChannelBridge] wired to the Android host.
///
/// Override in tests with a fake implementation.
final Provider<NativeChannelBridge> nativeChannelBridgeProvider =
    Provider<NativeChannelBridge>((ref) {
      return MethodChannelNativeBridge(
        const MethodChannel(PlatformChannels.root),
      );
    });

/// The [FfiBridge] for this build.
///
/// Phase 1 returns the truthful [UnavailableFfiBridge]; once the C++ core is
/// linked, swap this provider implementation in — nothing else changes.
final Provider<FfiBridge> ffiBridgeProvider = Provider<FfiBridge>(
  (ref) => const UnavailableFfiBridge(),
);
