import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/identity/identity_providers.dart';
import 'package:onebit/features/peer_registry/peer_registry_providers.dart';
import 'package:onebit/features/trust/peer_trust.dart';
import 'package:onebit/features/trust/peer_verification.dart';
import 'package:onebit/features/trust/trust_service.dart';

/// Provides the trust service.
///
/// Injects the [IdentityRepository] for trust persistence.
/// Trust records are loaded lazily on first access and persisted
/// after each trust state mutation.
final trustServiceProvider = Provider<TrustService>((ref) {
  final service = TrustService(ref.watch(identityRepositoryProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Stream of trust change events, keyed by peer identity ID.
///
/// Emitted whenever [TrustService] mutates trust or verification state.
/// Used to synchronize the [PeerRegistryService] with trust changes.
final trustChangeProvider = StreamProvider<TrustChangeEvent>((ref) {
  final service = ref.watch(trustServiceProvider);
  return service.changeStream;
});

/// Watches the trust change stream and syncs to the peer registry.
///
/// When trust is established, revoked, or verified for a peer,
/// the registry is updated so UI widgets reactively rebuild.
final trustSyncProvider = Provider<void>((ref) {
  final change = ref.watch(trustChangeProvider);
  change.whenData((event) {
    final registry = ref.read(peerRegistryProvider);
    final trustService = ref.read(trustServiceProvider);
    final trust = trustService.getTrust(event.peerIdentityId);
    final verification =
        trustService.getVerification(event.peerIdentityId);
    registry.updateTrust(
      event.peerIdentityId,
      trustState: trust.state,
      isVerified: verification.isVerified,
      isAuthenticated: trust.isAuthenticated,
    );
  });
});

/// Get trust state for a specific peer.
PeerTrust peerTrustFor(WidgetRef ref, String peerIdentityId) {
  final service = ref.read(trustServiceProvider);
  return service.getTrust(peerIdentityId);
}

/// Get verification state for a specific peer.
PeerVerification peerVerificationFor(
  WidgetRef ref,
  String peerIdentityId,
) {
  final service = ref.read(trustServiceProvider);
  return service.getVerification(peerIdentityId);
}

/// Whether a specific peer is trusted.
bool peerIsTrusted(WidgetRef ref, String peerIdentityId) {
  final service = ref.read(trustServiceProvider);
  return service.isTrusted(peerIdentityId);
}

/// Whether a specific peer can be used for secure communication.
bool peerCanCommunicate(WidgetRef ref, String peerIdentityId) {
  final service = ref.read(trustServiceProvider);
  return service.canCommunicate(peerIdentityId);
}
