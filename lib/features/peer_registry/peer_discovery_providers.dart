import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/identity/identity_providers.dart';
import 'package:onebit/features/peer_registry/discovered_peer.dart';
import 'package:onebit/features/peer_registry/peer_discovery_manager.dart';

/// Provider for the peer discovery manager instance.
///
/// Manages deduplication of BLE discoveries at the logical peer identity level.
/// Never auto-trusts, auto-connects, or auto-pairs — discovery only identifies
/// BLE advertisements.
final peerDiscoveryManagerProvider = Provider<PeerDiscoveryManager>((ref) {
  final resolver = ref.watch(bleIdentityResolverProvider);

  final manager = PeerDiscoveryManager(
    resolvedStream: resolver.resolvedStream,
  );

  ref.onDispose(manager.dispose);
  return manager;
});

/// Stream of discovery events (appeared, updated, identityChanged, disappeared).
final discoveryEventStreamProvider = StreamProvider<DiscoveryEvent>((ref) {
  final manager = ref.watch(peerDiscoveryManagerProvider);
  return manager.eventStream;
});

/// Stream of all currently discovered peers.
///
/// UI widgets should watch this provider to reactively update when
/// new peers are discovered or existing peers are updated.
final discoveredPeersProvider = StreamProvider<List<DiscoveredPeer>>((ref) {
  final manager = ref.watch(peerDiscoveryManagerProvider);
  return manager.peersStream;
});

/// Current snapshot of all discovered peers.
final discoveredPeersSnapshotProvider = Provider<List<DiscoveredPeer>>((ref) {
  final manager = ref.watch(peerDiscoveryManagerProvider);
  return manager.peers;
});

/// Look up a discovered peer by identity ID.
DiscoveredPeer? discoveredPeerById(WidgetRef ref, String identityId) {
  final manager = ref.read(peerDiscoveryManagerProvider);
  return manager.peerById(identityId);
}

/// Look up a discovered peer by BLE device ID.
DiscoveredPeer? discoveredPeerByDevice(WidgetRef ref, String deviceId) {
  final manager = ref.read(peerDiscoveryManagerProvider);
  return manager.peerByDevice(deviceId);
}

/// Number of currently discovered peers.
int discoveredPeerCount(WidgetRef ref) {
  final manager = ref.read(peerDiscoveryManagerProvider);
  return manager.peerCount;
}

/// Number of known (trusted) peers among discovered peers.
int knownDiscoveredPeerCount(WidgetRef ref) {
  final peers = ref.read(discoveredPeersSnapshotProvider);
  return peers.where((p) => p.isKnownPeer).length;
}

/// Number of unknown peers among discovered peers.
int unknownDiscoveredPeerCount(WidgetRef ref) {
  final peers = ref.read(discoveredPeersSnapshotProvider);
  return peers.where((p) => !p.isKnownPeer && p.hasIdentity).length;
}
