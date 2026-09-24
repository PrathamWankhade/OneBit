/// I9.5 — Intermediate relay and message forwarding.
///
/// When a peer receives a message not addressed to itself, this
/// service determines whether to forward it via I8-selected next
/// hop using existing I7 transport.
///
/// ## Architecture
///
/// ```text
/// receive envelope
///       ↓
/// validate structure
///       ↓
/// destination == local?
///       ├── YES → local destination
///       └── NO  → ask I8 → transmit via I7
/// ```
///
/// ## Invariants
///
/// - Original [MessageEnvelope.messageId] is preserved across hops
/// - Original [MessageEnvelope.sourcePeerId] is preserved (relay ≠ sender)
/// - Original [MessageEnvelope.destinationPeerId] is preserved
/// - Payload is treated as opaque — never parsed or modified
/// - No retry, no persistence, no dedup, no TTL (future increments)
/// - I8 remains the authority for route selection
library;

import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/features/message/application/message_transmission_service.dart';
import 'package:onebit/features/message/models/message_envelope.dart';
import 'package:onebit/features/message/models/message_envelope_validator.dart';
import 'package:onebit/features/message/models/message_id.dart';
import 'package:onebit/features/message/models/message_state.dart';
import 'package:onebit/features/message/models/onebit_message.dart';

/// Result of a relay evaluation.
///
/// Sealed class representing the three possible outcomes when
/// processing a received message envelope.
sealed class RelayResult {
  const RelayResult();

  /// Message is addressed to the local peer — not a relay candidate.
  const factory RelayResult.localDestination() = LocalDestination;

  /// Message was forwarded to the next hop via I7 transport.
  const factory RelayResult.forwarded({
    required String nextHopPeerId,
    required int routeMetric,
  }) = Forwarded;

  /// Relay attempt failed.
  const factory RelayResult.relayFailed({
    required String reason,
  }) = RelayFailed;
}

/// The message's final destination is this peer.
class LocalDestination extends RelayResult {
  const LocalDestination();
}

/// The message was forwarded to the next hop.
class Forwarded extends RelayResult {
  const Forwarded({
    required this.nextHopPeerId,
    required this.routeMetric,
  });

  /// The peer that will handle the next hop.
  final String nextHopPeerId;

  /// The I8 route metric to the final destination.
  final int routeMetric;
}

/// The relay attempt failed.
class RelayFailed extends RelayResult {
  const RelayFailed({required this.reason});

  /// Human-readable failure reason.
  final String reason;
}

/// Diagnostic event emitted for each relay operation.
///
/// Bounded in-memory log for developer diagnostics.
class RelayEvent {
  const RelayEvent({
    required this.messageId,
    required this.sourcePeerId,
    required this.destinationPeerId,
    required this.localPeerId,
    required this.nextHopPeerId,
    required this.routeMetric,
    required this.result,
    required this.timestamp,
  });

  final MessageId messageId;
  final String sourcePeerId;
  final String destinationPeerId;
  final String localPeerId;
  final String nextHopPeerId;
  final int routeMetric;
  final RelayResult result;
  final DateTime timestamp;
}

/// Maximum number of relay diagnostic events retained in memory.
const int _maxRelayEvents = 100;

/// Intermediate relay and message forwarding service.
///
/// Receives a [MessageEnvelope], determines whether the local peer
/// is the final destination, and forwards non-local messages via
/// the existing [MessageTransmissionService].
///
/// ## Usage
///
/// ```text
/// BLE → I7 → MessageEnvelopeCodec.decode()
///        → MessageRelayService.receiveAndRelay(envelope)
///        → if local: handle locally
///        → if remote: MessageTransmissionService.transmit()
/// ```
///
/// This service does NOT:
/// - Own BLE connections (I7)
/// - Own routing algorithms (I8)
/// - Implement retry (I9.11)
/// - Implement persistence (I9.8)
/// - Implement deduplication (I9.12)
/// - Implement TTL/hop-limit (I9.6)
class MessageRelayService {
  MessageRelayService({
    required this.localPeerId,
    required this._transmissionService,
  });

  final String localPeerId;
  final MessageTransmissionService _transmissionService;

  /// In-memory diagnostic event log (bounded at [_maxRelayEvents]).
  final List<RelayEvent> _events = [];

  /// Unmodifiable view of recent relay events.
  List<RelayEvent> get events => List.unmodifiable(_events);

  /// Process a received message envelope.
  ///
  /// 1. Validate envelope structure
  /// 2. Check if destination is the local peer
  /// 3. If local → return [LocalDestination]
  /// 4. If remote → forward via [MessageTransmissionService]
  ///
  /// The original envelope identity (messageId, source, destination)
  /// is preserved across all hops.
  Future<RelayResult> receiveAndRelay(MessageEnvelope envelope) async {
    // 1. Validate envelope structure.
    final validation = MessageEnvelopeValidator.validate(envelope);
    if (!validation.isValid) {
      final result = RelayFailed(
        reason: 'Invalid envelope: ${validation.reason}',
      );
      _recordEvent(envelope, result);
      return result;
    }

    // 2. Check if this peer is the final destination.
    if (envelope.destinationPeerId == localPeerId) {
      AppLogger.info(
        'Relay: message ${_shortId(envelope.messageId)} is for local peer',
      );
      _recordEvent(envelope, const LocalDestination());
      return const LocalDestination();
    }

    // 3. Construct OneBitMessage preserving original identity.
    //
    // The relay node does NOT become the source. The original
    // sourcePeerId and destinationPeerId are preserved exactly.
    final message = OneBitMessage(
      id: envelope.messageId,
      sourcePeerId: envelope.sourcePeerId,
      destinationPeerId: envelope.destinationPeerId,
      state: MessageState.created,
      createdAt: DateTime.now().toUtc(),
      payloadSizeBytes: envelope.payload.length,
    );

    // 4. Forward via existing I9.4 transmission service.
    //
    // This reuses the same route-lookup → device-resolve → encode
    // → BLE-send pipeline used by origin transmission.
    AppLogger.info(
      'Relay: forwarding ${_shortId(envelope.messageId)} '
      'from ${_shortId(envelope.sourcePeerId)} '
      'to ${_shortId(envelope.destinationPeerId)}',
    );

    final transmissionResult = await _transmissionService.transmit(
      message: message,
      envelope: envelope,
    );

    // 5. Map transmission result to relay result.
    final result = switch (transmissionResult) {
      TransmissionSent(:final nextHopPeerId, :final routeMetric) =>
        Forwarded(
          nextHopPeerId: nextHopPeerId,
          routeMetric: routeMetric,
        ),
      TransmissionNoRoute() => const RelayFailed(reason: 'No route'),
      TransmissionNextHopUnavailable(:final nextHopPeerId) => RelayFailed(
        reason: 'Next hop $nextHopPeerId unavailable',
      ),
      TransmissionTransportFailed(:final reason) => RelayFailed(
        reason: 'Transport failed: $reason',
      ),
      TransmissionEncodingFailed(:final reason) => RelayFailed(
        reason: 'Encoding failed: $reason',
      ),
      TransmissionRejected(:final reason) => RelayFailed(
        reason: 'Rejected: $reason',
      ),
    };

    _recordEvent(envelope, result);

    if (result is Forwarded) {
      AppLogger.info(
        'Relay: forwarded ${_shortId(envelope.messageId)} '
        'to ${_shortId(result.nextHopPeerId)} '
        '(metric=${result.routeMetric})',
      );
    } else if (result is RelayFailed) {
      AppLogger.info(
        'Relay: failed for ${_shortId(envelope.messageId)}: ${result.reason}',
      );
    }

    return result;
  }

  /// Record a diagnostic event (bounded at [_maxRelayEvents]).
  void _recordEvent(MessageEnvelope envelope, RelayResult result) {
    _events.add(RelayEvent(
      messageId: envelope.messageId,
      sourcePeerId: envelope.sourcePeerId,
      destinationPeerId: envelope.destinationPeerId,
      localPeerId: localPeerId,
      nextHopPeerId: '',
      routeMetric: 0,
      result: result,
      timestamp: DateTime.now().toUtc(),
    ));

    // Evict oldest events when limit exceeded.
    if (_events.length > _maxRelayEvents) {
      _events.removeRange(0, _events.length - _maxRelayEvents);
    }
  }

  /// Truncate a PeerId for log output.
  String _shortId(dynamic id) {
    final s = id.toString();
    if (s.length >= 8) return '${s.substring(0, 8)}...';
    return s;
  }
}
