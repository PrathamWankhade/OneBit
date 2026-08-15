import 'package:flutter/foundation.dart';

/// A peer device observed by the local radio.
///
/// Domain model only — transport details (advertisement parsing, RSSI
/// smoothing) live in the data layer behind the repository contract.
@immutable
final class NearbyPeer {
  const NearbyPeer({
    required this.peerId,
    required this.firstSeen,
    required this.lastSeen,
    required this.rssiDb,
  });

  /// Stable identifier advertised by the peer.
  final String peerId;

  /// When this peer was first observed (process-local clock).
  final DateTime firstSeen;

  /// When this peer was last observed.
  final DateTime lastSeen;

  /// Latest received signal strength in dBm.
  final int rssiDb;

  /// Peer considered "fresh" when seen within the last 60 seconds.
  bool get isActive =>
      DateTime.now().difference(lastSeen).inSeconds < Duration.secondsPerMinute;
}
