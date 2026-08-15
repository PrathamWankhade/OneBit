import 'package:flutter/services.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/platform/native_channel_bridge.dart';
import 'package:onebit/core/result/result.dart';

/// [NativeChannelBridge] implemented with the Flutter [MethodChannel].
///
/// This is the only place in the Dart codebase that touches
/// `MethodChannel`; native invocations are serialized here and returned as
/// [Result] so failures stay inside the failure framework.
final class MethodChannelNativeBridge implements NativeChannelBridge {
  MethodChannelNativeBridge(this._channel);

  final MethodChannel _channel;

  @override
  String get channelName => _channel.name;

  @override
  Future<Result<Object?>> invoke(String method, [Object? arguments]) async {
    try {
      final payload = await _channel.invokeMethod<Object?>(method, arguments);
      return Ok(payload);
    } on PlatformException catch (error) {
      return Err(
        PlatformFailure(
          message: '${error.code}: ${error.message}',
          method: method,
          cause: error,
        ),
      );
    } on MissingPluginException catch (error) {
      return Err(
        PlatformFailure(
          message: 'Channel not registered: ${_channel.name}',
          method: method,
          cause: error,
        ),
      );
    } on Exception catch (error, stackTrace) {
      return Err(
        PlatformFailure(
          message: error.toString(),
          method: method,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
