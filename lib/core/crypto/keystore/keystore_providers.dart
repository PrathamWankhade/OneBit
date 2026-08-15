import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/crypto/keystore/keystore_channel_bridge.dart';
import 'package:onebit/core/crypto/keystore/keystore_key_bridge.dart';
import 'package:onebit/core/platform/channel_names.dart';
import 'package:onebit/core/platform/method_channel_native_bridge.dart';

/// The real [KeystoreKeyBridge]. Override in tests with an in-memory fake.
final Provider<KeystoreKeyBridge> keystoreKeyBridgeProvider =
    Provider<KeystoreKeyBridge>((ref) {
      return KeystoreChannelBridge(
        MethodChannelNativeBridge(
          const MethodChannel(PlatformChannels.identity),
        ),
      );
    });

/// Stable identifiers for the identity vault.
abstract final class IdentityVault {
  /// Alias of the primary identity key pair inside the Android Keystore.
  static const String alias = 'onebit.identity.v1';

  /// Alias of the exchange (X25519) key pair inside the Android Keystore.
  static const String exchangeAlias = 'onebit.identity.v1.exchange';

  /// Database prefix for key-value metadata (reverse-DNS, namespaced).
  static const String prefsKeyPrefix = 'onebit.identity.v1';

  const IdentityVault._();
}
