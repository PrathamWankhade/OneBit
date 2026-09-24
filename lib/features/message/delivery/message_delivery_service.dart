/// I9.1 — Message delivery service boundary.
///
/// Defines the delivery orchestration interface. The delivery service
/// owns message lifecycle state transitions and coordinates between
/// the application layer and I8 routing.
///
/// ## Responsibilities
///
/// - Accept delivery requests from the application
/// - Manage message lifecycle state transitions
/// - Request route lookup from I8
/// - Expose delivery state for diagnostics
///
/// ## Does NOT Own
///
/// - BLE connections (I7)
/// - Sessions (I6/I7)
/// - Route calculation (I8)
/// - Trust decisions (I6)
/// - Encryption primitives (I5/I6)
/// - Message persistence (future I9)
/// - Retry logic (future I9)
/// - Acknowledgements (future I9)
/// - Relay forwarding (I9.5)
library;

import 'package:onebit/features/message/delivery/message_delivery_result.dart';
import 'package:onebit/features/message/models/message_state.dart';
import 'package:onebit/features/message/models/message_id.dart';
import 'package:onebit/features/message/models/onebit_message.dart';
import 'package:onebit/features/routing/route.dart';

/// Function signature for route lookup.
///
/// The delivery service uses this to request routing information
/// from I8 without owning route calculation.
typedef RouteLookup = Route? Function(String destinationPeerId);

/// Message delivery service — orchestrates message delivery.
///
/// Sits between the application layer and I8 routing. Accepts
/// delivery requests, manages lifecycle state, and coordinates
/// route lookup.
///
/// ## Architecture
///
/// ```text
/// Application
///     ↓
/// MessageDeliveryService
///     ↓
/// I8 Route Table
///     ↓
/// Next Hop
/// ```
///
/// The service does not implement actual transmission — that
/// belongs to later increments (I9.4).
class MessageDeliveryService {
  MessageDeliveryService({
    required this.localPeerId,
    required this._routeLookup,
  });

  /// Local node's cryptographic peer identity.
  ///
  /// Used to determine if a message targets this node.
  final String localPeerId;

  final RouteLookup _routeLookup;

  /// Whether this service has been disposed.
  bool _isDisposed = false;

  /// Message states indexed by MessageId.
  final Map<String, OneBitMessage> _messages = {};

  /// Whether the service has been disposed.
  bool get isDisposed => _isDisposed;

  /// Accept a message for delivery.
  ///
  /// Validates the message, transitions it through the initial
  /// lifecycle states, and returns a result indicating whether
  /// the message was accepted.
  ///
  /// This does NOT mean the message has been delivered — it means
  /// the delivery service has accepted it for processing.
  MessageDeliveryResult acceptMessage(OneBitMessage message) {
    if (_isDisposed) {
      return MessageDeliveryResult.unavailable(message.id);
    }

    // Validate destination.
    if (message.destinationPeerId.isEmpty) {
      return MessageDeliveryResult.invalid(
        message.id,
        'Empty destination',
      );
    }

    // Validate source.
    if (message.sourcePeerId.isEmpty) {
      return MessageDeliveryResult.invalid(
        message.id,
        'Empty source',
      );
    }

    // Check expiration.
    if (message.isExpired()) {
      return MessageDeliveryResult.expired(message.id);
    }

    // Check if already in a terminal state.
    if (message.isTerminal) {
      return MessageDeliveryResult.invalid(
        message.id,
        'Message in terminal state: ${message.state.name}',
      );
    }

    // Transition: CREATED → QUEUED → ROUTE_LOOKUP.
    var msg = message.copyWith(state: MessageState.queued);
    msg = msg.copyWith(state: MessageState.routeLookup);

    // Perform route lookup.
    final route = _routeLookup(message.destinationPeerId);

    if (route == null) {
      // No route available.
      msg = msg.copyWith(state: MessageState.noRoute);
      _messages[message.id.value] = msg;
      return MessageDeliveryResult.noRoute(message.id);
    }

    // Route found — transition to READY.
    msg = msg.copyWith(state: MessageState.ready);
    _messages[message.id.value] = msg;

    return MessageDeliveryResult.accepted(message.id);
  }

  /// Get the current state of a message.
  OneBitMessage? getMessage(MessageId messageId) =>
      _messages[messageId.value];

  /// Get all tracked messages.
  List<OneBitMessage> get allMessages => _messages.values.toList();

  /// Get all messages in a specific state.
  List<OneBitMessage> messagesInState(MessageState state) =>
      _messages.values.where((m) => m.state == state).toList();

  /// Number of tracked messages.
  int get messageCount => _messages.length;

  /// Dispose resources.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _messages.clear();
  }
}
