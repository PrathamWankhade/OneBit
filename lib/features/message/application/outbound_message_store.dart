/// I9.3/I9.4 — Runtime store for outbound messages.
///
/// Holds created messages in memory. Not persisted — messages
/// disappear on app restart. Persistent storage belongs to I9.13.
///
/// Implements [ChangeNotifier] so the UI rebuilds when message
/// states change during I9.4 transmission.
library;

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:onebit/features/message/models/message_envelope.dart';
import 'package:onebit/features/message/models/message_id.dart';
import 'package:onebit/features/message/models/onebit_message.dart';

/// A read-only view of an outbound message with its envelope metadata.
class OutboundMessage {
  const OutboundMessage({
    required this.message,
    required this.text,
    required this.createdAt,
  });

  /// The domain message.
  final OneBitMessage message;

  /// The plaintext content (for UI display).
  final String text;

  /// When this outbound message was created (local wall clock).
  final DateTime createdAt;

  MessageId get id => message.id;
  String get sourcePeerId => message.sourcePeerId;
  String get destinationPeerId => message.destinationPeerId;

  /// Build the transport envelope for this message.
  MessageEnvelope get envelope => MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: message.id,
        sourcePeerId: message.sourcePeerId,
        destinationPeerId: message.destinationPeerId,
        payload: Uint8List.fromList(text.codeUnits),
      );
}

/// Runtime store for outbound messages.
///
/// Indexed by destination PeerId for efficient per-conversation lookup.
/// All messages are kept in memory only — no persistence.
///
/// Extends [ChangeNotifier] so the UI rebuilds when message
/// states change during I9.4 transmission.
class OutboundMessageStore extends ChangeNotifier {
  OutboundMessageStore();

  /// All outbound messages indexed by MessageId value.
  final Map<String, OutboundMessage> _byId = {};

  /// Message IDs grouped by destination PeerId.
  final Map<String, List<String>> _byDestination = {};

  /// Add an outbound message to the store.
  void add(OutboundMessage outbound) {
    final idValue = outbound.id.value;
    _byId[idValue] = outbound;

    final dest = outbound.destinationPeerId;
    _byDestination.putIfAbsent(dest, () => []).add(idValue);
    notifyListeners();
  }

  /// Update an existing outbound message in the store.
  ///
  /// Replaces the message with the same ID. If the message does
  /// not exist, this is a no-op.
  void update(OutboundMessage outbound) {
    final idValue = outbound.id.value;
    if (!_byId.containsKey(idValue)) return;
    _byId[idValue] = outbound;
    notifyListeners();
  }

  /// Get an outbound message by its ID.
  OutboundMessage? getById(MessageId id) => _byId[id.value];

  /// Get all outbound messages for a specific destination.
  List<OutboundMessage> getByDestination(String peerId) {
    final ids = _byDestination[peerId];
    if (ids == null) return const [];
    return ids.map((id) => _byId[id]).whereType<OutboundMessage>().toList();
  }

  /// Get all outbound messages.
  List<OutboundMessage> get all =>
      UnmodifiableListView(_byId.values);

  /// Number of stored messages.
  int get length => _byId.length;

  /// Whether the store is empty.
  bool get isEmpty => _byId.isEmpty;

  /// Whether a message with the given ID exists.
  bool contains(MessageId id) => _byId.containsKey(id.value);

  /// Remove all messages.
  void clear() {
    _byId.clear();
    _byDestination.clear();
    notifyListeners();
  }
}
