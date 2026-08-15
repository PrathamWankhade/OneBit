import 'dart:async';

import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_repository.dart';
import 'package:onebit/features/nearby/domain/nearby_peer.dart';
import 'package:onebit/features/nearby/domain/nearby_peer_repository.dart';

/// Blueprint of the [NearbyPeerRepository] backed by the Bluetooth
/// transport's scan pipeline.
///
/// The transport observes *devices*; this repository projects those
/// observations into *peers* (identifiable, last-seen, signal strength)
/// exactly as the node registry expects. Peers stay in the snapshot for
/// [staleAfter] without a fresh advertisement.
final class NearbyPeerRepositoryImpl implements NearbyPeerRepository {
  NearbyPeerRepositoryImpl({
    required this._transport,
    this._staleAfter = const Duration(seconds: 90),
  });

  final BluetoothRepository _transport;
  final Duration _staleAfter;

  final Map<String, NearbyPeer> _peers = {};
  final StreamController<Result<List<NearbyPeer>>> _controller =
      StreamController<Result<List<NearbyPeer>>>.broadcast();
  StreamSubscription<BluetoothTransportEvent>? _subscription;
  Timer? _timer;

  @override
  Stream<Result<List<NearbyPeer>>> observeNearbyPeers() {
    if (_subscription == null) {
      _subscription = _transport.events.listen(
        (event) {
          switch (event) {
            case ScanResultEvent(:final result):
              _upsert(result.device.id, result.rssiDb, result.timestamp);
            case ConnectionChangedEvent(:final deviceId, :final state):
              if (state == 'disconnected' || state == 'error') {
                _peers.remove(deviceId);
                _emit();
              }
            default:
              break;
          }
        },
        onError: (Object error) {
          _controller.add(
            Err(PlatformFailure(message: 'ble.nearby.stream', cause: error)),
          );
        },
      );
      _timer = Timer.periodic(_prunePeriod(), (_) => _emit());
    }
    return _controller.stream;
  }

  /// Stale peers are swept on a schedule that tracks the staleness budget:
  /// at most every second in production, but fast enough that tests can
  /// exercise pruning with sub-second staleness.
  Duration _prunePeriod() {
    final third = _staleAfter.inMilliseconds ~/ 3;
    if (third >= 1000) return const Duration(seconds: 1);
    if (third < 16) return const Duration(milliseconds: 16);
    return Duration(milliseconds: third);
  }

  void _upsert(String deviceId, int rssi, DateTime at) {
    final existing = _peers[deviceId];
    _peers[deviceId] = NearbyPeer(
      peerId: deviceId,
      firstSeen: existing?.firstSeen ?? at,
      lastSeen: at,
      rssiDb: rssi,
    );
    _emit();
  }

  void _emit() {
    final now = DateTime.now();
    _peers.removeWhere(
      (_, peer) => now.difference(peer.lastSeen) > _staleAfter,
    );
    _controller.add(Ok(_peers.values.toList()));
  }

  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    _controller.close();
  }
}
