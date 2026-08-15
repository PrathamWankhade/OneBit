import 'package:flutter/foundation.dart';

/// Read-only snapshot of what the current build's platform bridges provide.
///
/// Returned by the home use case so the UI can report readiness honestly
/// without probing private bridge objects.
@immutable
final class PlatformCapabilities {
  const PlatformCapabilities({
    required this.nativeCoreAvailable,
    required this.channelBridgeAvailable,
  });

  /// True when the C++ FFI core is linked and symbols resolve.
  final bool nativeCoreAvailable;

  /// True when the method-channel host registered its handler.
  final bool channelBridgeAvailable;
}
