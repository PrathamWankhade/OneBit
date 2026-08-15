import 'package:flutter/foundation.dart';

/// Outcome of an MTU negotiation.
@immutable
final class MtuNegotiationResult {
  const MtuNegotiationResult({
    required this.deviceId,
    required this.requestedMtu,
    required this.actualMtu,
    required this.fellBack,
  });

  /// Device the MTU was negotiated for.
  final String deviceId;

  /// The value we asked for.
  final int requestedMtu;

  /// The value the peer accepted (≥ 23).
  final int actualMtu;

  /// True when [actualMtu] is below [requestedMtu] and the peer applied a
  /// smaller cap — normal and not an error.
  final bool fellBack;

  @override
  String toString() =>
      'MTU $actualMtu (asked $requestedMtu${fellBack ? ', fallback' : ''})';
}
