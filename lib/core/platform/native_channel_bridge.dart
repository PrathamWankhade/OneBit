import 'package:onebit/core/result/result.dart';

/// Contract for talking to the native Android/Kotlin host.
///
/// Every native capability the Dart layer needs goes through this interface
/// so business code never depends on `MethodChannel` directly and tests can
/// substitute fakes freely. The concrete transport lives in
/// `method_channel_native_bridge.dart`.
abstract interface class NativeChannelBridge {
  /// Name of the platform channel this bridge targets.
  String get channelName;

  /// Invokes [method] on the native host.
  ///
  /// - Returns `Ok(payload)` with the platform's JSON-ish response.
  /// - Returns `Err(PlatformFailure)` when the platform throws or the
  ///   channel is not registered on the host side.
  Future<Result<Object?>> invoke(String method, [Object? arguments]);
}
