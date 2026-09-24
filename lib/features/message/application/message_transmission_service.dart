/// I9.4 — Route-based message transmission service.
///
/// Performs the first outbound transmission of a OneBit message:
/// route lookup → next-hop resolution → envelope encode → BLE send.
///
/// ## Architecture
///
/// ```text
/// MessageController
///       ↓
/// MessageTransmissionService
///       ↓
/// I8 Route Table (bestRoute)
///       ↓
/// Selected Next Hop
///       ↓
/// I7 PeerConnectionManager (deviceForPeer)
///       ↓
/// I7 BleService (sendReliable)
///       ↓
/// Immediate Peer
/// ```
///
/// This service does NOT own:
/// - Route calculation (I8)
/// - BLE connection establishment (I7)
/// - Session creation (I7)
/// - Retry logic (future I9.11)
/// - Relay forwarding (I9.5)
/// - Acknowledgements (I9.10)
/// - Deduplication (I9.12)
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/message/models/message_envelope.dart';
import 'package:onebit/features/message/models/message_envelope_codec.dart';
import 'package:onebit/features/message/models/message_envelope_validator.dart';
import 'package:onebit/features/message/models/onebit_message.dart';
import 'package:onebit/features/protocol/onebit_packet.dart';
import 'package:onebit/features/protocol/packet_codec.dart';
import 'package:onebit/features/reliable/transfer.dart';
import 'package:onebit/features/routing/route.dart';

/// The outcome of a transmission attempt.
///
/// This is NOT delivery confirmation — it means the originating
/// device either succeeded or failed to hand the envelope to the
/// selected immediate next hop through the existing transport.
sealed class TransmissionResult {
  const TransmissionResult();

  /// Envelope accepted and handed to transport.
  const factory TransmissionResult.sentToNextHop({
    required String nextHopPeerId,
    required int routeMetric,
  }) = TransmissionSent;

  /// No route exists to the destination.
  const factory TransmissionResult.noRoute() = TransmissionNoRoute;

  /// Route exists but the next hop is not connected.
  const factory TransmissionResult.nextHopUnavailable({
    required String nextHopPeerId,
  }) = TransmissionNextHopUnavailable;

  /// Transport-level failure.
  const factory TransmissionResult.transportFailed({
    required String reason,
  }) = TransmissionTransportFailed;

  /// Message envelope could not be encoded.
  const factory TransmissionResult.encodingFailed({
    required String reason,
  }) = TransmissionEncodingFailed;

  /// Message rejected by validation.
  const factory TransmissionResult.rejected({
    required String reason,
  }) = TransmissionRejected;
}

class TransmissionSent extends TransmissionResult {
  const TransmissionSent({
    required this.nextHopPeerId,
    required this.routeMetric,
  });
  final String nextHopPeerId;
  final int routeMetric;
}

class TransmissionNoRoute extends TransmissionResult {
  const TransmissionNoRoute();
}

class TransmissionNextHopUnavailable extends TransmissionResult {
  const TransmissionNextHopUnavailable({required this.nextHopPeerId});
  final String nextHopPeerId;
}

class TransmissionTransportFailed extends TransmissionResult {
  const TransmissionTransportFailed({required this.reason});
  final String reason;
}

class TransmissionEncodingFailed extends TransmissionResult {
  const TransmissionEncodingFailed({required this.reason});
  final String reason;
}

class TransmissionRejected extends TransmissionResult {
  const TransmissionRejected({required this.reason});
  final String reason;
}

/// Function signature for resolving a PeerId to a BLE device ID.
typedef DeviceResolver = String? Function(String peerIdentityId);

/// Function signature for checking if a peer is connected.
typedef PeerConnectedCheck = bool Function(String peerIdentityId);

/// Function signature for looking up a route.
typedef RouteLookup = Route? Function(String destinationPeerId);

/// Route-based message transmission service.
///
/// Performs one transmission attempt per call. Does NOT retry.
/// Does NOT implement store-and-forward. Does NOT implement
/// application-level acknowledgement.
class MessageTransmissionService {
  MessageTransmissionService({
    required this.localPeerId,
    required this._bleService,
    required this._routeLookup,
    required this._deviceResolver,
    required this._isPeerConnected,
  });

  final String localPeerId;
  final BleService _bleService;
  final RouteLookup _routeLookup;
  final DeviceResolver _deviceResolver;
  final PeerConnectedCheck _isPeerConnected;

  int _packetIdCounter = 0;

  /// Transmit a message to its next hop.
  ///
  /// Performs the full transmission pipeline:
  /// 1. Validate message
  /// 2. Look up route via I8
  /// 3. Resolve next-hop BLE device
  /// 4. Encode envelope via I9.2 codec
  /// 5. Wrap in OneBit packet
  /// 6. Send via I7 reliable transport
  ///
  /// Returns a [TransmissionResult] indicating the outcome.
  Future<TransmissionResult> transmit({
    required OneBitMessage message,
    required MessageEnvelope envelope,
  }) async {
    // 1. Validate: must not be local message.
    if (message.isLocalTo(localPeerId)) {
      return const TransmissionResult.rejected(
        reason: 'Cannot transmit message to self',
      );
    }

    // 2. Validate envelope structure.
    final validation = MessageEnvelopeValidator.validate(envelope);
    if (!validation.isValid) {
      return TransmissionResult.rejected(
        reason: 'Envelope validation failed: ${validation.reason}',
      );
    }

    // 3. Route lookup via I8.
    final route = _routeLookup(message.destinationPeerId);
    if (route == null) {
      AppLogger.info(
        'Transmission: no route to ${_shortId(message.destinationPeerId)}',
      );
      return const TransmissionResult.noRoute();
    }

    final nextHopPeerId = route.nextHopPeerId;

    // 4. Verify next hop is connected.
    if (!_isPeerConnected(nextHopPeerId)) {
      AppLogger.info(
        'Transmission: next hop ${_shortId(nextHopPeerId)} not connected',
      );
      return TransmissionResult.nextHopUnavailable(
        nextHopPeerId: nextHopPeerId,
      );
    }

    // 5. Resolve BLE device for next hop.
    final deviceId = _deviceResolver(nextHopPeerId);
    if (deviceId == null) {
      AppLogger.info(
        'Transmission: no BLE device for ${_shortId(nextHopPeerId)}',
      );
      return TransmissionResult.nextHopUnavailable(
        nextHopPeerId: nextHopPeerId,
      );
    }

    // 6. Encode envelope.
    final Uint8List envelopeBytes;
    try {
      envelopeBytes = MessageEnvelopeCodec.encode(envelope);
    } catch (e) {
      return TransmissionResult.encodingFailed(
        reason: 'Failed to encode envelope: $e',
      );
    }

    // 7. Check size against packet constraints.
    if (envelopeBytes.length > PacketConstants.maxPayloadSize) {
      return TransmissionResult.encodingFailed(
        reason: 'Envelope too large: ${envelopeBytes.length} bytes '
            '(max ${PacketConstants.maxPayloadSize})',
      );
    }

    // 8. Wrap in OneBit packet.
    final packet = OneBitPacket(
      type: PacketType.message,
      packetId: _nextPacketId(),
      payload: envelopeBytes,
    );

    final Uint8List packetBytes;
    try {
      packetBytes = PacketCodec.encode(packet);
    } catch (e) {
      return TransmissionResult.encodingFailed(
        reason: 'Failed to encode packet: $e',
      );
    }

    // 9. Send via I7 reliable transport.
    AppLogger.info(
      'Transmission: sending to ${_shortId(nextHopPeerId)} '
      '(dest=${_shortId(message.destinationPeerId)}, '
      'metric=${route.metric}, '
      'envelope=${envelopeBytes.length}B)',
    );

    final TransferResult transferResult;
    try {
      transferResult = await _bleService.sendReliable(deviceId, packetBytes);
    } catch (e) {
      AppLogger.error('Transmission: transport error', e);
      return TransmissionResult.transportFailed(
        reason: 'Transport error: $e',
      );
    }

    // 10. Map transport result.
    return switch (transferResult) {
      TransferResult.delivered => TransmissionResult.sentToNextHop(
          nextHopPeerId: nextHopPeerId,
          routeMetric: route.metric,
        ),
      TransferResult.failed => const TransmissionResult.transportFailed(
          reason: 'Transport reported failure',
        ),
      TransferResult.cancelled => const TransmissionResult.transportFailed(
          reason: 'Transport cancelled',
        ),
    };
  }

  /// Generate the next packet ID (wraps at 256).
  int _nextPacketId() {
    _packetIdCounter = (_packetIdCounter + 1) & 0xFF;
    return _packetIdCounter;
  }

  /// Truncate a PeerId for log output.
  String _shortId(String peerId) {
    if (peerId.length >= 8) return '${peerId.substring(0, 8)}...';
    return peerId;
  }
}
