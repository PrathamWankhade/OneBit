import 'package:flutter/foundation.dart';

/// The parsed advertisement payload of a discovered peer.
///
/// Byte-level fields the transport exposes so higher layers (identity
/// handshake, mesh) can later recognize peers without re-parsing.
@immutable
final class Advertisement {
  const Advertisement({
    this.localName,
    this.txPowerLevel,
    this.serviceUuids = const [],
    this.manufacturerData = const {},
    this.serviceData = const {},
  });

  /// Advertised friendly name, when present.
  final String? localName;

  /// Advertised transmit power in dBm, when present.
  final int? txPowerLevel;

  /// 128-bit and 16-bit service UUIDs found in the payload.
  final List<String> serviceUuids;

  /// Manufacturer-specific data keyed by the company id.
  final Map<int, Uint8List> manufacturerData;

  /// Service data keyed by service UUID string.
  final Map<String, Uint8List> serviceData;

  bool get isEmpty =>
      localName == null &&
      txPowerLevel == null &&
      serviceUuids.isEmpty &&
      manufacturerData.isEmpty &&
      serviceData.isEmpty;
}
