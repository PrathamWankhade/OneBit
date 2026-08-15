/// Stable identifiers for the platform bridge channels.
///
/// Channels are versioned by product name; method names are documented next
/// to their phase so later phases extend without renaming.
abstract final class PlatformChannels {
  /// Root channel used for device-level introspecition (version, battery).
  static const String root = 'dev.onebit.onebit/native';

  /// Dedicated BLE mesh channel (registered in the Bluetooth phase).
  static const String bluetooth = 'dev.onebit.onebit/ble';

  /// Dedicated storage channel (registered in the persistence phase).
  static const String storage = 'dev.onebit.onebit/storage';

  /// Dedicated identity keystore channel (Android Keystore-backed vault).
  static const String identity = 'dev.onebit.onebit/identity';

  const PlatformChannels._();
}

/// Method names executed on [PlatformChannels.root].
abstract final class PlatformMethods {
  /// Returns a string-map with device platform metadata.
  static const String getDeviceInfo = 'getDeviceInfo';

  /// Simple liveness probe implemented by the host platform.
  static const String ping = 'ping';

  const PlatformMethods._();
}

/// Method names executed on [PlatformChannels.identity].
abstract final class IdentityKeystoreMethods {
  /// Wraps and persists a seed under `alias` (args: `alias`, `seed`).
  static const String storeSeed = 'storeSeed';

  /// Unwraps a seed stored under `alias` (args: `alias`).
  static const String loadSeed = 'loadSeed';

  /// Reports whether `alias` exists (args: `alias`).
  static const String hasIdentity = 'hasIdentity';

  /// Permanently removes `alias` (args: `alias`).
  static const String deleteIdentity = 'deleteIdentity';

  const IdentityKeystoreMethods._();
}
