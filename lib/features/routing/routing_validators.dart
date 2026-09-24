import 'package:onebit/features/routing/routing_limits.dart';

/// Validation error categories for routing input.
enum RoutingValidationError {
  emptyPeerId,
  invalidPeerIdLength,
  invalidPeerIdHex,
  selfDestination,
  selfNextHop,
  metricOutOfBounds,
  metricZero,
  emptyDestination,
  emptyNextHop,
  collectionTooLarge,
  invalidSequence,
  payloadTooLarge,
  unsupportedVersion,
  requiredFieldMissing,
  selfLoop,
  duplicateEntry,
}

/// Focused validators for routing primitives.
///
/// Each validator is a pure function. Invalid input fails safely
/// with a specific error category. No validation is scattered
/// across service classes.
abstract final class RoutingValidators {
  /// Validate that [peerId] is a non-empty, 64-char lowercase hex string.
  static bool isValidPeerId(String peerId) {
    if (peerId.length != RoutingLimits.peerIdLength) return false;
    for (var i = 0; i < peerId.length; i++) {
      final c = peerId.codeUnitAt(i);
      final isDigit = c >= 0x30 && c <= 0x39; // 0-9
      final isLowerHex = c >= 0x61 && c <= 0x66; // a-f
      if (!isDigit && !isLowerHex) return false;
    }
    return true;
  }

  /// Validate a route metric is within [1, maxRouteMetric].
  static bool isValidMetric(int metric) {
    return metric >= 1 && metric <= RoutingLimits.maxRouteMetric;
  }

  /// Validate a sequence number is non-negative.
  static bool isValidSequence(int sequence) => sequence >= 0;

  /// Check whether a collection length is within [maxSize].
  static bool isWithinBounds(int length, int maxSize) => length <= maxSize;

  /// Validate a topology advertisement is structurally sound
  /// before expensive processing.
  static List<RoutingValidationError> validateAdvertisement({
    required String sourceIdentity,
    required int sequence,
    required List<String> neighbors,
    required int protocolVersion,
    int? payloadSize,
  }) {
    final errors = <RoutingValidationError>[];

    if (!isValidPeerId(sourceIdentity)) {
      errors.add(RoutingValidationError.invalidPeerIdLength);
    }

    if (!isValidSequence(sequence)) {
      errors.add(RoutingValidationError.invalidSequence);
    }

    if (neighbors.length > RoutingLimits.maxNeighborsPerSource) {
      errors.add(RoutingValidationError.collectionTooLarge);
    }

    if (protocolVersion < 1) {
      errors.add(RoutingValidationError.unsupportedVersion);
    }

    for (final neighbor in neighbors) {
      if (!isValidPeerId(neighbor)) {
        errors.add(RoutingValidationError.invalidPeerIdLength);
        break;
      }
      if (neighbor == sourceIdentity) {
        errors.add(RoutingValidationError.selfLoop);
        break;
      }
    }

    if (payloadSize != null &&
        payloadSize > RoutingLimits.maxAdvertisementPayloadSize) {
      errors.add(RoutingValidationError.payloadTooLarge);
    }

    return errors;
  }

  /// Validate a route before insertion into the routing table.
  static List<RoutingValidationError> validateRoute({
    required String destinationPeerId,
    required String nextHopPeerId,
    required int metric,
    required String? localPeerId,
  }) {
    final errors = <RoutingValidationError>[];

    if (destinationPeerId.isEmpty) {
      errors.add(RoutingValidationError.emptyDestination);
    } else if (!isValidPeerId(destinationPeerId)) {
      errors.add(RoutingValidationError.invalidPeerIdLength);
    } else if (localPeerId != null && destinationPeerId == localPeerId) {
      errors.add(RoutingValidationError.selfDestination);
    }

    if (nextHopPeerId.isEmpty) {
      errors.add(RoutingValidationError.emptyNextHop);
    } else if (!isValidPeerId(nextHopPeerId)) {
      errors.add(RoutingValidationError.invalidPeerIdLength);
    } else if (localPeerId != null && nextHopPeerId == localPeerId) {
      errors.add(RoutingValidationError.selfNextHop);
    }

    if (metric <= 0) {
      errors.add(RoutingValidationError.metricZero);
    } else if (metric > RoutingLimits.maxRouteMetric) {
      errors.add(RoutingValidationError.metricOutOfBounds);
    }

    return errors;
  }
}
