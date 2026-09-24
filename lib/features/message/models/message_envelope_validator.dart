/// I9.2 — Structural validation for message envelopes.
///
/// Validates that a [MessageEnvelope] conforms to the protocol
/// contract. This is structural validation only — it does not
/// perform security, trust, or cryptographic checks.
///
/// ## Separation of Concerns
///
/// ```text
/// I9.2 structural validation
///   → Is the envelope well-formed?
///
/// I8.10 routing security
///   → Is this routing information trustworthy?
///
/// I9 security layer (future)
///   → Is this message authentic/protected?
/// ```
library;

import 'package:onebit/features/message/models/message_envelope.dart';

/// Reason an envelope fails structural validation.
enum EnvelopeValidationReason {
  /// Protocol version is not supported.
  unsupportedVersion,

  /// Source PeerId is not exactly 64 hex characters.
  invalidSourcePeerId,

  /// Destination PeerId is not exactly 64 hex characters.
  invalidDestinationPeerId,

  /// Payload exceeds the maximum allowed size.
  payloadTooLarge,

  /// Source PeerId contains non-hex characters.
  malformedSourcePeerId,

  /// Destination PeerId contains non-hex characters.
  malformedDestinationPeerId,
}

/// Result of envelope structural validation.
class EnvelopeValidationResult {
  /// The envelope passed all checks.
  const EnvelopeValidationResult.valid()
      : isValid = true,
        reason = null;

  /// The envelope failed a specific check.
  const EnvelopeValidationResult.invalid(this.reason) : isValid = false;

  /// Whether the envelope is structurally valid.
  final bool isValid;

  /// The first reason validation failed, if invalid.
  final EnvelopeValidationReason? reason;

  @override
  String toString() => isValid
      ? 'EnvelopeValidationResult.valid'
      : 'EnvelopeValidationResult.invalid($reason)';
}

/// Structural validator for [MessageEnvelope].
///
/// Validates version, PeerId format, and payload size. Does not
/// perform security, trust, or cryptographic checks.
class MessageEnvelopeValidator {
  const MessageEnvelopeValidator._();

  /// Validate a [MessageEnvelope] structurally.
  static EnvelopeValidationResult validate(MessageEnvelope envelope) {
    // Version check.
    if (envelope.protocolVersion != messageProtocolVersion) {
      return const EnvelopeValidationResult.invalid(
        EnvelopeValidationReason.unsupportedVersion,
      );
    }

    // Source PeerId length.
    if (envelope.sourcePeerId.length != peerIdHexLength) {
      return const EnvelopeValidationResult.invalid(
        EnvelopeValidationReason.invalidSourcePeerId,
      );
    }

    // Destination PeerId length.
    if (envelope.destinationPeerId.length != peerIdHexLength) {
      return const EnvelopeValidationResult.invalid(
        EnvelopeValidationReason.invalidDestinationPeerId,
      );
    }

    // Source PeerId hex format.
    if (!_isHex(envelope.sourcePeerId)) {
      return const EnvelopeValidationResult.invalid(
        EnvelopeValidationReason.malformedSourcePeerId,
      );
    }

    // Destination PeerId hex format.
    if (!_isHex(envelope.destinationPeerId)) {
      return const EnvelopeValidationResult.invalid(
        EnvelopeValidationReason.malformedDestinationPeerId,
      );
    }

    // Payload size.
    if (envelope.payload.length > maxMessagePayloadSize) {
      return const EnvelopeValidationResult.invalid(
        EnvelopeValidationReason.payloadTooLarge,
      );
    }

    return const EnvelopeValidationResult.valid();
  }

  /// Check that a string contains only hex characters.
  static bool _isHex(String s) {
    final hexRegex = RegExp(r'^[0-9a-f]+$');
    return hexRegex.hasMatch(s);
  }
}
