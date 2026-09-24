/// I9.3/I9.4 — Message creation and transmission controller.
///
/// Handles the outbound message creation workflow:
/// validate → create MessageId → create Message → create Envelope → register.
///
/// I9.4 adds: route lookup → next-hop resolution → BLE transmit.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:onebit/features/message/application/outbound_message_store.dart';
import 'package:onebit/features/message/application/message_transmission_service.dart';
import 'package:onebit/features/message/models/message_envelope.dart';
import 'package:onebit/features/message/models/message_envelope_validator.dart';
import 'package:onebit/features/message/models/message_id.dart';
import 'package:onebit/features/message/models/message_state.dart';
import 'package:onebit/features/message/models/onebit_message.dart';

/// Result of a message creation attempt.
sealed class MessageCreationResult {
  const MessageCreationResult();

  /// Message created successfully.
  const factory MessageCreationResult.success(OutboundMessage outbound) =
      MessageCreationSuccess;

  /// Message creation failed.
  const factory MessageCreationResult.failure(String error) =
      MessageCreationFailure;
}

class MessageCreationSuccess extends MessageCreationResult {
  const MessageCreationSuccess(this.outbound);
  final OutboundMessage outbound;
}

class MessageCreationFailure extends MessageCreationResult {
  const MessageCreationFailure(this.error);
  final String error;
}

/// Result of a message send attempt (create + transmit).
sealed class MessageSendResult {
  const MessageSendResult();

  /// Message created and transmission initiated.
  const factory MessageSendResult.success(OutboundMessage outbound) =
      MessageSendSuccess;

  /// Message creation failed.
  const factory MessageSendResult.failure(String error) =
      MessageSendFailure;
}

class MessageSendSuccess extends MessageSendResult {
  const MessageSendSuccess(this.outbound);
  final OutboundMessage outbound;
}

class MessageSendFailure extends MessageSendResult {
  const MessageSendFailure(this.error);
  final String error;
}

/// Controller for creating outbound messages.
///
/// I9.3: Creates messages and stores them locally.
/// I9.4: Also triggers route-based transmission via BLE.
class MessageController {
  MessageController({
    required this._store,
    required this._localPeerId,
    this.transmissionService,
  });

  final OutboundMessageStore _store;
  final String _localPeerId;
  final MessageTransmissionService? transmissionService;

  /// The local node's PeerId.
  String get localPeerId => _localPeerId;

  /// Create an outbound message without transmitting.
  ///
  /// Validates input, constructs the message and envelope,
  /// and registers the message in the store.
  MessageCreationResult createMessage({
    required String destinationPeerId,
    required String content,
  }) {
    final result = _validateAndCreate(destinationPeerId, content);
    if (result is MessageCreationSuccess) {
      _store.add(result.outbound);
    }
    return result;
  }

  /// Create and transmit an outbound message.
  ///
  /// Creates the message, stores it, then triggers transmission
  /// via the I9.4 transmission pipeline. The message state is
  /// updated based on the actual transmission result.
  Future<MessageSendResult> sendMessage({
    required String destinationPeerId,
    required String content,
  }) async {
    final createResult = _validateAndCreate(destinationPeerId, content);
    if (createResult is MessageCreationFailure) {
      return MessageSendFailure(createResult.error);
    }

    final success = createResult as MessageCreationSuccess;
    final outbound = success.outbound;
    _store.add(outbound);

    // If no transmission service, message stays in created state.
    if (transmissionService == null) {
      return MessageSendSuccess(outbound);
    }

    // Update state: CREATED → READY (skipping intermediate states
    // for the simple case — delivery service handles full lifecycle).
    var msg = outbound.message;
    msg = msg.copyWith(state: MessageState.queued);
    msg = msg.copyWith(state: MessageState.routeLookup);
    _updateOutboundMessage(outbound, msg);

    // Transmit.
    final result = await transmissionService!.transmit(
      message: msg,
      envelope: outbound.envelope,
    );

    // Update state based on transmission result.
    msg = switch (result) {
      TransmissionSent() => msg.copyWith(state: MessageState.transmitting),
      TransmissionNoRoute() => msg.copyWith(state: MessageState.noRoute),
      TransmissionNextHopUnavailable() =>
        msg.copyWith(state: MessageState.failed),
      TransmissionTransportFailed() => msg.copyWith(state: MessageState.failed),
      TransmissionEncodingFailed() => msg.copyWith(state: MessageState.failed),
      TransmissionRejected() => msg.copyWith(state: MessageState.rejected),
    };

    // For successful transmission, transition to delivered (first-hop).
    if (result is TransmissionSent) {
      msg = msg.copyWith(state: MessageState.delivered);
    }

    _updateOutboundMessage(outbound, msg);

    return MessageSendSuccess(outbound);
  }

  /// Validate and create a message without storing or transmitting.
  MessageCreationResult _validateAndCreate(
    String destinationPeerId,
    String content,
  ) {
    // Validate destination.
    if (destinationPeerId.isEmpty) {
      return const MessageCreationResult.failure('Empty destination');
    }
    if (destinationPeerId.length != peerIdHexLength) {
      return const MessageCreationResult.failure('Invalid destination PeerId');
    }

    // Validate content.
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return const MessageCreationResult.failure('Message cannot be empty');
    }

    // Check payload size.
    final payloadBytes = Uint8List.fromList(trimmed.codeUnits);
    if (payloadBytes.length > maxMessagePayloadSize) {
      return const MessageCreationResult.failure('Message is too large');
    }

    // Create message.
    final messageId = MessageId();
    final now = DateTime.now().toUtc();
    final message = OneBitMessage(
      id: messageId,
      sourcePeerId: _localPeerId,
      destinationPeerId: destinationPeerId,
      createdAt: now,
      payloadSizeBytes: payloadBytes.length,
    );

    // Create envelope.
    final envelope = MessageEnvelope(
      protocolVersion: messageProtocolVersion,
      messageId: messageId,
      sourcePeerId: _localPeerId,
      destinationPeerId: destinationPeerId,
      payload: payloadBytes,
    );

    // Validate envelope.
    final validation = MessageEnvelopeValidator.validate(envelope);
    if (!validation.isValid) {
      return MessageCreationResult.failure(
        'Envelope validation failed: ${validation.reason}',
      );
    }

    // Register in store.
    final outbound = OutboundMessage(
      message: message,
      text: trimmed,
      createdAt: now,
    );

    return MessageCreationResult.success(outbound);
  }

  /// Update the message in the store with new state.
  void _updateOutboundMessage(OutboundMessage outbound, OneBitMessage msg) {
    // Create a new OutboundMessage with updated state.
    final updated = OutboundMessage(
      message: msg,
      text: outbound.text,
      createdAt: outbound.createdAt,
    );
    _store.update(updated);
  }

  /// Get all messages for a specific destination.
  List<OutboundMessage> getMessagesForDestination(String peerId) =>
      _store.getByDestination(peerId);
}
