/// I8.10 — Routing security validation.
///
/// Provides defense-in-depth for incoming routing information:
/// sender identity binding, structural normalization, and security
/// event logging. Sits between transport and [TopologyExchangeService].
///
/// ## Security Model
///
/// Routing information is untrusted input. This module applies
/// structural and binding checks before topology mutation. It does
/// NOT implement reputation, Sybil resistance, or Byzantine defense.
///
/// ## Sender Identity Binding
///
/// Every routing advertisement must arrive with a transport-layer
/// authenticated peer ID (from the BLE session). The payload's
/// `sourceIdentity` must match this authenticated peer. This prevents
/// injection attacks where a peer sends another peer's topology.
///
/// ## Reuse of Existing Infrastructure
///
/// - Structural validation: [TopologyAdvertisement.isValid]
/// - Peer identity format: 64-char hex-encoded Ed25519 public key
/// - Trust/authentication: [TrustService] (injected, not owned)
library;

import 'dart:collection';

import 'package:onebit/features/routing/routing_limits.dart';
import 'package:onebit/features/routing/topology_advertisement.dart';
import 'package:onebit/features/trust/trust_service.dart';

/// Security event types for routing validation.
///
/// Logged for diagnostics and security monitoring. Values are
/// additive — new events may be added as the routing layer evolves.
enum RoutingSecurityEvent {
  /// Payload source does not match transport-layer authenticated peer.
  senderIdentityMismatch,

  /// Sender peer is not in the authenticated peers registry.
  senderNotAuthenticated,

  /// Payload contains duplicate neighbor entries (normalized before acceptance).
  duplicateNeighborsNormalized,

  /// Advertisement contains a self-loop (source advertises itself).
  selfLoopDetected,

  /// Advertisement was accepted after passing all security checks.
  validationPassed,

  /// Structural validation failed (malformed PeerId, size bounds, etc.).
  structuralValidationFailed,
}

/// Result of security validation for an incoming topology advertisement.
class SecurityValidationResult {
  const SecurityValidationResult({
    required this.isAccepted,
    required this.event,
    this.normalizedAdvertisement,
  });

  /// Whether the advertisement passed all security checks.
  final bool isAccepted;

  /// The primary security event that occurred.
  final RoutingSecurityEvent event;

  /// If accepted with normalized neighbor list, the cleaned advertisement.
  ///
  /// `null` when `isAccepted` is `false`.
  final TopologyAdvertisement? normalizedAdvertisement;

  /// Accept result with optional neighbor normalization.
  const SecurityValidationResult.accepted([
    TopologyAdvertisement? normalized,
  ])  : isAccepted = true,
        event = RoutingSecurityEvent.validationPassed,
        normalizedAdvertisement = normalized;

  /// Rejection result with the specific security event.
  const SecurityValidationResult.rejected(this.event)
      : isAccepted = false,
        normalizedAdvertisement = null;
}

/// Stateful security validator for routing advertisements.
///
/// Applies security checks in order:
/// 1. Sender identity binding (must be authenticated)
/// 2. Structural validation (PeerId format, size bounds)
/// 3. Duplicate neighbor deduplication (normalize before acceptance)
///
/// Stateless side-effect logging is available via [eventLog].
class RoutingSecurityValidator {
  RoutingSecurityValidator({
    required this._trustService,
  });

  final TrustService _trustService;

  /// Event log for security diagnostics.
  ///
  /// Each entry is a (sourcePeerId, event) pair. The log is append-only
  /// and capped at [maxSecurityEventLog] entries.
  final List<(String, RoutingSecurityEvent)> _eventLog = [];
  static const int maxEventLogSize = RoutingLimits.maxSecurityEventLog;

  /// Read-only view of the security event log.
  UnmodifiableListView<(String, RoutingSecurityEvent)> get eventLog =>
      UnmodifiableListView(_eventLog);

  /// Validate an incoming topology advertisement.
  ///
  /// [advertisement] is the decoded topology advertisement.
  /// [authenticatedPeerId] is the transport-layer authenticated peer
  /// identity (from the BLE session that delivered this payload).
  ///
  /// Returns a [SecurityValidationResult] indicating acceptance or
  /// rejection with the specific security event.
  SecurityValidationResult validate({
    required TopologyAdvertisement advertisement,
    required String authenticatedPeerId,
  }) {
    final source = advertisement.sourceIdentity;

    // ── 1. Sender Identity Binding ──────────────────────────
    //
    // The authenticated transport peer must match the payload source.
    // This prevents injection where a peer sends another's topology.
    if (authenticatedPeerId != source) {
      _logEvent(source, RoutingSecurityEvent.senderIdentityMismatch);
      return const SecurityValidationResult.rejected(
        RoutingSecurityEvent.senderIdentityMismatch,
      );
    }

    // ── 2. Authenticated Peer Check ─────────────────────────
    //
    // Verify the sender is a known authenticated peer.
    if (!_trustService.isAuthenticated(authenticatedPeerId)) {
      _logEvent(
        source,
        RoutingSecurityEvent.senderNotAuthenticated,
      );
      return const SecurityValidationResult.rejected(
        RoutingSecurityEvent.senderNotAuthenticated,
      );
    }

    // ── 3. Structural Validation ────────────────────────────
    //
    // PeerId format, size bounds, sequence validity.
    if (!advertisement.isValid) {
      _logEvent(source, RoutingSecurityEvent.structuralValidationFailed);
      return const SecurityValidationResult.rejected(
        RoutingSecurityEvent.structuralValidationFailed,
      );
    }

    // ── 4. Self-Loop Detection ──────────────────────────────
    //
    // Source advertises itself as a neighbor (invalid routing info).
    if (advertisement.hasSelfLoop) {
      _logEvent(source, RoutingSecurityEvent.selfLoopDetected);
      return const SecurityValidationResult.rejected(
        RoutingSecurityEvent.selfLoopDetected,
      );
    }

    // ── 5. Duplicate Neighbor Deduplication ─────────────────
    //
    // Normalize the neighbor list before acceptance.
    final seen = <String>{};
    final normalizedNeighbors = <String>[];
    var hadDuplicates = false;
    for (final neighborId in advertisement.neighborPeerIds) {
      if (seen.add(neighborId)) {
        normalizedNeighbors.add(neighborId);
      } else {
        hadDuplicates = true;
      }
    }

    if (hadDuplicates) {
      _logEvent(source, RoutingSecurityEvent.duplicateNeighborsNormalized);
    }

    // ── 6. Accept ───────────────────────────────────────────
    //
    // Create normalized advertisement (or reuse original if no changes).
    final TopologyAdvertisement acceptedAd;
    if (hadDuplicates) {
      acceptedAd = TopologyAdvertisement(
        sourceIdentity: advertisement.sourceIdentity,
        sequence: advertisement.sequence,
        neighborPeerIds: normalizedNeighbors,
      );
    } else {
      acceptedAd = advertisement;
    }

    _logEvent(source, RoutingSecurityEvent.validationPassed);
    return SecurityValidationResult.accepted(acceptedAd);
  }

  /// Check if a specific security event has occurred for a peer.
  bool hasEvent(String peerId, RoutingSecurityEvent event) {
    return _eventLog.any((entry) => entry.$1 == peerId && entry.$2 == event);
  }

  /// Get all events for a specific peer.
  List<RoutingSecurityEvent> eventsFor(String peerId) {
    return _eventLog
        .where((entry) => entry.$1 == peerId)
        .map((entry) => entry.$2)
        .toList();
  }

  /// Get the count of a specific event type.
  int eventCount(RoutingSecurityEvent event) {
    return _eventLog.where((entry) => entry.$2 == event).length;
  }

  /// Clear the event log.
  void clearLog() {
    _eventLog.clear();
  }

  void _logEvent(String peerId, RoutingSecurityEvent event) {
    _eventLog.add((peerId, event));
    if (_eventLog.length > maxEventLogSize) {
      _eventLog.removeRange(0, _eventLog.length - maxEventLogSize);
    }
  }
}
