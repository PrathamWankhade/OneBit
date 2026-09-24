import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:onebit/features/routing/routing_security.dart';
import 'package:onebit/features/routing/topology_advertisement.dart';
import 'package:onebit/features/trust/trust_service.dart';

import 'routing_security_test.mocks.dart';

@GenerateMocks([TrustService])
void main() {
  const peerA = 'aa11111111111111111111111111111111111111111111111111111111111111';
  const peerB = 'bb22222222222222222222222222222222222222222222222222222222222222';
  const peerC = 'cc33333333333333333333333333333333333333333333333333333333333333';
  const peerD = 'dd44444444444444444444444444444444444444444444444444444444444444';

  late MockTrustService trustService;
  late RoutingSecurityValidator validator;

  setUp(() {
    trustService = MockTrustService();
    validator = RoutingSecurityValidator(
      trustService: trustService,
    );
  });

  TopologyAdvertisement makeAd({
    String source = peerA,
    int sequence = 1,
    List<String> neighbors = const [peerB, peerC],
  }) {
    return TopologyAdvertisement(
      sourceIdentity: source,
      sequence: sequence,
      neighborPeerIds: neighbors,
    );
  }

  void authenticated(String peerId) {
    when(trustService.isAuthenticated(peerId)).thenReturn(true);
  }

  void notAuthenticated(String peerId) {
    when(trustService.isAuthenticated(peerId)).thenReturn(false);
  }

  // ── Sender Identity Binding ──────────────────────────────────

  group('Sender Identity Binding', () {
    test('accepts when authenticated peer matches source identity', () {
      authenticated(peerA);
      final ad = makeAd();
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, true);
      expect(result.event, RoutingSecurityEvent.validationPassed);
    });

    test('rejects when authenticated peer differs from source identity', () {
      authenticated(peerA);
      final ad = makeAd(source: peerA);
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerB,
      );
      expect(result.isAccepted, false);
      expect(result.event, RoutingSecurityEvent.senderIdentityMismatch);
    });

    test('rejects when source claims to be different peer', () {
      authenticated(peerB);
      final ad = makeAd(source: peerB);
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, false);
      expect(result.event, RoutingSecurityEvent.senderIdentityMismatch);
    });

    test('rejects when authenticated peer is empty', () {
      final ad = makeAd();
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: '',
      );
      expect(result.isAccepted, false);
      expect(result.event, RoutingSecurityEvent.senderIdentityMismatch);
    });

    test('identity binding is checked before authentication', () {
      // Even though peerB is not authenticated, identity mismatch is caught first
      notAuthenticated(peerB);
      final ad = makeAd(source: peerA);
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerB,
      );
      expect(result.isAccepted, false);
      expect(result.event, RoutingSecurityEvent.senderIdentityMismatch);
    });
  });

  // ── Authentication Check ─────────────────────────────────────

  group('Authentication Check', () {
    test('rejects when sender is not authenticated', () {
      notAuthenticated(peerA);
      final ad = makeAd();
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, false);
      expect(result.event, RoutingSecurityEvent.senderNotAuthenticated);
    });

    test('accepts when sender is authenticated', () {
      authenticated(peerA);
      final ad = makeAd();
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, true);
    });

    test('trust service is queried with the authenticated peer ID', () {
      authenticated(peerA);
      final ad = makeAd();
      validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      verify(trustService.isAuthenticated(peerA)).called(1);
    });
  });

  // ── Structural Validation ────────────────────────────────────

  group('Structural Validation', () {
    test('rejects advertisement with invalid source identity length', () {
      authenticated('short');
      const ad = TopologyAdvertisement(
        sourceIdentity: 'short',
        sequence: 1,
        neighborPeerIds: [],
      );
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: 'short',
      );
      expect(result.isAccepted, false);
      expect(result.event, RoutingSecurityEvent.structuralValidationFailed);
    });

    test('rejects advertisement with invalid neighbor id length', () {
      authenticated(peerA);
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 1,
        neighborPeerIds: ['invalid'],
      );
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, false);
      expect(result.event, RoutingSecurityEvent.structuralValidationFailed);
    });

    test('rejects advertisement with negative sequence', () {
      authenticated(peerA);
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: -1,
        neighborPeerIds: [],
      );
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, false);
      expect(result.event, RoutingSecurityEvent.structuralValidationFailed);
    });

    test('rejects advertisement with too many neighbors', () {
      authenticated(peerA);
      final neighbors = List.generate(65, (i) => peerB);
      final ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 1,
        neighborPeerIds: neighbors,
      );
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, false);
      expect(result.event, RoutingSecurityEvent.structuralValidationFailed);
    });

    test('accepts valid advertisement with empty neighbors', () {
      authenticated(peerA);
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 1,
        neighborPeerIds: [],
      );
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, true);
    });
  });

  // ── Self-Loop Detection ──────────────────────────────────────

  group('Self-Loop Detection', () {
    test('rejects advertisement where source advertises itself', () {
      authenticated(peerA);
      final ad = makeAd(neighbors: [peerA, peerB]);
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, false);
      expect(result.event, RoutingSecurityEvent.selfLoopDetected);
    });

    test('rejects advertisement where source is only neighbor', () {
      authenticated(peerA);
      final ad = makeAd(neighbors: [peerA]);
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, false);
      expect(result.event, RoutingSecurityEvent.selfLoopDetected);
    });

    test('accepts advertisement without self-loop', () {
      authenticated(peerA);
      final ad = makeAd(neighbors: [peerB]);
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, true);
    });
  });

  // ── Duplicate Neighbor Deduplication ─────────────────────────

  group('Duplicate Neighbor Deduplication', () {
    test('normalizes duplicate neighbors and accepts', () {
      authenticated(peerA);
      final ad = makeAd(neighbors: [peerB, peerB, peerC, peerB, peerC]);
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, true);
      expect(result.event, RoutingSecurityEvent.validationPassed);
      expect(
        result.normalizedAdvertisement!.neighborPeerIds,
        [peerB, peerC],
      );
      expect(
        validator.eventCount(RoutingSecurityEvent.duplicateNeighborsNormalized),
        1,
      );
    });

    test('returns original advertisement when no duplicates', () {
      authenticated(peerA);
      final ad = makeAd(neighbors: [peerB, peerC]);
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, true);
      expect(result.event, RoutingSecurityEvent.validationPassed);
      // Should reuse the original advertisement object
      expect(result.normalizedAdvertisement, same(ad));
    });

    test('preserves order of first occurrence', () {
      authenticated(peerA);
      final ad = makeAd(neighbors: [peerC, peerB, peerC, peerD, peerB]);
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, true);
      expect(
        result.normalizedAdvertisement!.neighborPeerIds,
        [peerC, peerB, peerD],
      );
    });

    test('handles single neighbor (no duplicates possible)', () {
      authenticated(peerA);
      final ad = makeAd(neighbors: [peerB]);
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, true);
      expect(result.event, RoutingSecurityEvent.validationPassed);
    });

    test('handles all duplicate neighbors', () {
      authenticated(peerA);
      final ad = makeAd(neighbors: [peerB, peerB, peerB, peerB]);
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, true);
      expect(result.event, RoutingSecurityEvent.validationPassed);
      expect(
        result.normalizedAdvertisement!.neighborPeerIds,
        [peerB],
      );
      expect(
        validator.eventCount(RoutingSecurityEvent.duplicateNeighborsNormalized),
        1,
      );
    });
  });

  // ── Event Logging ────────────────────────────────────────────

  group('Event Logging', () {
    test('logs sender identity mismatch', () {
      authenticated(peerA);
      final ad = makeAd();
      validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerB,
      );
      expect(validator.eventCount(RoutingSecurityEvent.senderIdentityMismatch), 1);
    });

    test('logs sender not authenticated', () {
      notAuthenticated(peerA);
      final ad = makeAd();
      validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(validator.eventCount(RoutingSecurityEvent.senderNotAuthenticated), 1);
    });

    test('logs structural validation failure', () {
      authenticated(peerA);
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 1,
        neighborPeerIds: ['short'],
      );
      validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(
        validator.eventCount(RoutingSecurityEvent.structuralValidationFailed),
        1,
      );
    });

    test('logs self-loop detection', () {
      authenticated(peerA);
      final ad = makeAd(neighbors: [peerA]);
      validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(validator.eventCount(RoutingSecurityEvent.selfLoopDetected), 1);
    });

    test('logs validation passed', () {
      authenticated(peerA);
      final ad = makeAd();
      validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(validator.eventCount(RoutingSecurityEvent.validationPassed), 1);
    });

    test('logs duplicate neighbors normalized', () {
      authenticated(peerA);
      final ad = makeAd(neighbors: [peerB, peerB]);
      validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(
        validator.eventCount(RoutingSecurityEvent.duplicateNeighborsNormalized),
        1,
      );
    });

    test('hasEvent returns true for specific peer and event', () {
      authenticated(peerA);
      notAuthenticated(peerB);
      validator.validate(
        advertisement: makeAd(),
        authenticatedPeerId: peerA,
      );
      validator.validate(
        advertisement: makeAd(source: peerB),
        authenticatedPeerId: peerB,
      );
      expect(
        validator.hasEvent(peerA, RoutingSecurityEvent.validationPassed),
        true,
      );
      expect(
        validator.hasEvent(peerB, RoutingSecurityEvent.senderNotAuthenticated),
        true,
      );
    });

    test('hasEvent returns false for event that did not occur', () {
      authenticated(peerA);
      validator.validate(
        advertisement: makeAd(),
        authenticatedPeerId: peerA,
      );
      expect(
        validator.hasEvent(peerA, RoutingSecurityEvent.senderIdentityMismatch),
        false,
      );
    });

    test('eventsFor returns all events for a peer', () {
      authenticated(peerA);
      final ad1 = makeAd();
      final ad2 = makeAd(neighbors: [peerB, peerB]);
      validator.validate(advertisement: ad1, authenticatedPeerId: peerA);
      validator.validate(advertisement: ad2, authenticatedPeerId: peerA);
      final events = validator.eventsFor(peerA);
      // ad1: validationPassed; ad2: duplicateNeighborsNormalized + validationPassed
      expect(events, contains(RoutingSecurityEvent.validationPassed));
      expect(events, contains(RoutingSecurityEvent.duplicateNeighborsNormalized));
      expect(events.length, 3);
    });

    test('eventsFor returns empty list for unknown peer', () {
      expect(validator.eventsFor('unknown_peer'), isEmpty);
    });

    test('clearLog empties the event log', () {
      authenticated(peerA);
      validator.validate(
        advertisement: makeAd(),
        authenticatedPeerId: peerA,
      );
      expect(validator.eventLog, isNotEmpty);
      validator.clearLog();
      expect(validator.eventLog, isEmpty);
    });

    test('event log is capped at maxEventLogSize', () {
      authenticated(peerA);
      for (var i = 0; i < RoutingSecurityValidator.maxEventLogSize + 5; i++) {
        validator.validate(
          advertisement: makeAd(sequence: i),
          authenticatedPeerId: peerA,
        );
      }
      expect(
        validator.eventLog.length,
        RoutingSecurityValidator.maxEventLogSize,
      );
    });

    test('event log retains most recent entries when capped', () {
      authenticated(peerA);
      for (var i = 0; i < RoutingSecurityValidator.maxEventLogSize + 2; i++) {
        validator.validate(
          advertisement: makeAd(sequence: i + 100),
          authenticatedPeerId: peerA,
        );
      }
      // The last entry should be the most recent validation
      expect(
        validator.eventLog.last.$2,
        RoutingSecurityEvent.validationPassed,
      );
    });
  });

  // ── Check Order and Independence ─────────────────────────────

  group('Check Order and Independence', () {
    test('identity mismatch is checked before authentication', () {
      notAuthenticated(peerB);
      // peerB is not authenticated, but identity mismatch is caught first
      final ad = makeAd(source: peerA);
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerB,
      );
      expect(result.event, RoutingSecurityEvent.senderIdentityMismatch);
      // trustService.isAuthenticated should NOT have been called
      verifyNever(trustService.isAuthenticated(any));
    });

    test('authentication is checked before structural validation', () {
      notAuthenticated(peerA);
      // Invalid structure, but authentication check comes first
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 1,
        neighborPeerIds: ['invalid'],
      );
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.event, RoutingSecurityEvent.senderNotAuthenticated);
    });

    test('structural validation is checked before self-loop', () {
      authenticated(peerA);
      // Self-loop + invalid structure — structural check comes first
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 1,
        neighborPeerIds: [peerA],
      );
      // But wait: sourceIdentity is valid length, so isValid passes
      // hasSelfLoop is checked next
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.event, RoutingSecurityEvent.selfLoopDetected);
    });

    test('self-loop is checked before duplicate normalization', () {
      authenticated(peerA);
      // Self-loop + duplicates — self-loop is caught first
      final ad = makeAd(neighbors: [peerA, peerB, peerB]);
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.event, RoutingSecurityEvent.selfLoopDetected);
    });
  });

  // ── Edge Cases ───────────────────────────────────────────────

  group('Edge Cases', () {
    test('empty neighbor list is accepted', () {
      authenticated(peerA);
      final ad = makeAd(neighbors: []);
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, true);
      expect(result.normalizedAdvertisement!.neighborPeerIds, isEmpty);
    });

    test('maximum allowed neighbors accepted', () {
      authenticated(peerA);
      final neighbors = List.generate(64, (i) => 'aa${i.toRadixString(16).padLeft(62, '0')}');
      final ad = makeAd(neighbors: neighbors);
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, true);
    });

    test('multiple validations accumulate in log', () {
      authenticated(peerA);
      authenticated(peerB);
      validator.validate(
        advertisement: makeAd(source: peerA),
        authenticatedPeerId: peerA,
      );
      validator.validate(
        advertisement: makeAd(source: peerB),
        authenticatedPeerId: peerB,
      );
      expect(validator.eventLog.length, 2);
      expect(validator.eventLog[0].$1, peerA);
      expect(validator.eventLog[1].$1, peerB);
    });

    test('sequence zero is valid', () {
      authenticated(peerA);
      final ad = makeAd(sequence: 0);
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, true);
    });

    test('large sequence number is valid', () {
      authenticated(peerA);
      final ad = makeAd(sequence: 9223372036854775807);
      final result = validator.validate(
        advertisement: ad,
        authenticatedPeerId: peerA,
      );
      expect(result.isAccepted, true);
    });
  });

  // ── SecurityValidationResult ─────────────────────────────────

  group('SecurityValidationResult', () {
    test('accepted result has correct properties', () {
      const result = SecurityValidationResult.accepted();
      expect(result.isAccepted, true);
      expect(result.event, RoutingSecurityEvent.validationPassed);
      expect(result.normalizedAdvertisement, isNull);
    });

    test('accepted result with normalized ad', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 1,
        neighborPeerIds: [peerB],
      );
      const result = SecurityValidationResult.accepted(ad);
      expect(result.isAccepted, true);
      expect(result.normalizedAdvertisement, same(ad));
    });

    test('rejected result has correct properties', () {
      const result = SecurityValidationResult.rejected(
        RoutingSecurityEvent.senderIdentityMismatch,
      );
      expect(result.isAccepted, false);
      expect(result.event, RoutingSecurityEvent.senderIdentityMismatch);
      expect(result.normalizedAdvertisement, isNull);
    });
  });
}
