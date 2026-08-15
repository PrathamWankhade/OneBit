import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:onebit/core/crypto/keystore/keystore_key_bridge.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/platform/native_channel_bridge.dart';
import 'package:onebit/core/result/result.dart';

/// [KeystoreKeyBridge] that routes through the native [NativeChannelBridge].
///
/// All private material crosses the channel as URL-safe Base64; the host
/// never returns plaintext bytes for the wrapped seed.
@immutable
final class KeystoreChannelBridge implements KeystoreKeyBridge {
  const KeystoreChannelBridge(this._bridge);

  final NativeChannelBridge _bridge;

  /// Error code the Kotlin host raises for a missing alias.
  static const String missingKeyCode = 'KEY_NOT_FOUND';

  @override
  String get channelName => _bridge.channelName;

  @override
  Future<Result<void>> storeSeed({
    required String alias,
    required Uint8List seed,
  }) async {
    final result = await _bridge.invoke('storeSeed', <String, Object?>{
      'alias': alias,
      'seed': base64Url.encode(seed).replaceAll('=', ''),
    });
    return switch (result) {
      Ok() => const Ok(null),
      Err() => Err(result.failure!),
    };
  }

  @override
  Future<Result<Uint8List>> loadSeed({required String alias}) async {
    final result = await _bridge.invoke('loadSeed', <String, Object?>{
      'alias': alias,
    });
    return result.fold(
      (payload) {
        if (payload is! String) {
          return Err(
            SerializationFailure(
              source: channelName,
              message: 'loadSeed returned a non-string',
            ),
          );
        }
        return Ok(Uint8List.fromList(_decode(payload)));
      },
      (failure) {
        if (_isMissingKey(failure)) {
          return Err(
            IdentityFailure(
              code: 'key_not_found',
              cause: failure,
              message: 'Identity key ($alias) not present in Keystore',
            ),
          );
        }
        return Err(failure);
      },
    );
  }

  @override
  Future<Result<bool>> hasIdentity({required String alias}) async {
    final result = await _bridge.invoke('hasIdentity', <String, Object?>{
      'alias': alias,
    });
    return result.map((payload) => payload == true);
  }

  @override
  Future<Result<void>> deleteIdentity({required String alias}) async {
    final result = await _bridge.invoke('deleteIdentity', <String, Object?>{
      'alias': alias,
    });
    return switch (result) {
      Ok() => const Ok(null),
      Err() => Err(result.failure!),
    };
  }

  static bool _isMissingKey(Failure failure) =>
      failure is PlatformFailure &&
      failure.message?.contains(missingKeyCode) == true;

  static Uint8List _decode(String encoded) {
    final padding = (4 - encoded.length % 4) % 4;
    return Uint8List.fromList(
      base64Url.decode(encoded.padRight(encoded.length + padding, '=')),
    );
  }
}
