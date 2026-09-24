import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/identity/identity_providers.dart';
import 'package:onebit/features/peer_registry/peer_entry.dart';
import 'package:onebit/features/peer_registry/peer_registry.dart';
import 'package:onebit/features/trust/trust_providers.dart';

/// Provides the in-memory peer registry.
///
/// Combines identity and trust state into a unified reactive stream
/// of [PeerEntry] objects.
final peerRegistryProvider = Provider<PeerRegistryService>((ref) {
  final registry = PeerRegistryService();
  final trustService = ref.watch(trustServiceProvider);
  final repo = ref.watch(identityRepositoryProvider);

  final subscriptions = <StreamSubscription<dynamic>>[];

  // Listen to peer identity changes from the database.
  subscriptions.add(repo.watchPeerIdentities().listen((idList) {
    registry.updateFromIdentities(idList);

    // Update trust state for each peer.
    for (final peer in idList) {
      final identityId = peer.identityId ?? peer.publicKeyHex;
      if (identityId == null) continue;

      final trust = trustService.getTrust(identityId);
      final verification = trustService.getVerification(identityId);
      registry.updateTrust(
        identityId,
        trustState: trust.state,
        isVerified: verification.isVerified,
        isAuthenticated: trust.isAuthenticated,
      );
    }
  }));

  ref.onDispose(() {
    for (final sub in subscriptions) {
      sub.cancel();
    }
    registry.dispose();
  });

  return registry;
});

/// Stream of all known peers from the registry.
///
/// UI widgets should watch this provider to reactively update
/// when peers are discovered or their trust state changes.
final peerEntriesProvider = StreamProvider<List<PeerEntry>>((ref) {
  final registry = ref.watch(peerRegistryProvider);
  return registry.peerStream;
});
