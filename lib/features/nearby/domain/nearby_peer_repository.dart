import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/nearby/domain/nearby_peer.dart';

/// Repository contract for nearby-peer discovery.
///
/// The concrete implementation arrives with the Bluetooth phase; it will
/// wrap the native BLE scan pipeline behind this interface, keeping the
/// domain stable regardless of transport.
abstract interface class NearbyPeerRepository {
  /// Continuously emits the current set of observed peers.
  ///
  /// The stream starts with the currently cached snapshot (if any) and
  /// emits on every scan update. Errors surface as an [Err] emission, never
  /// as a thrown stream error.
  Stream<Result<List<NearbyPeer>>> observeNearbyPeers();
}
