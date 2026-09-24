/// I9.3/I9.4 — Riverpod providers for the message feature.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/ble/ble_providers.dart';
import 'package:onebit/features/identity/identity_providers.dart';
import 'package:onebit/features/message/application/message_controller.dart';
import 'package:onebit/features/message/application/message_transmission_service.dart';
import 'package:onebit/features/message/application/outbound_message_store.dart';
import 'package:onebit/features/message/models/message_state.dart';
import 'package:onebit/features/peer_registry/peer_connection_providers.dart';
import 'package:onebit/features/routing/providers/routing_providers.dart';

/// The runtime outbound message store (singleton, not persisted).
final outboundMessageStoreProvider =
    ChangeNotifierProvider<OutboundMessageStore>((ref) {
  return OutboundMessageStore();
});

/// The local PeerId derived from the local identity.
final localPeerIdForMessageProvider = Provider<String>((ref) {
  final identity = ref.watch(localIdentityProvider);
  return identity.valueOrNull?.identityId ?? '';
});

/// The I9.4 message transmission service.
///
/// Wires I8 route lookup, I7 peer connection, and I7 BLE transport
/// into a single transmission pipeline.
final messageTransmissionServiceProvider =
    Provider<MessageTransmissionService?>((ref) {
  final localPeerId = ref.watch(localPeerIdForMessageProvider);
  if (localPeerId.isEmpty) return null;

  final bleService = ref.watch(bleServiceProvider);
  final routingTable = ref.watch(routingTableProvider);
  final connectionManager = ref.watch(peerConnectionManagerProvider);

  return MessageTransmissionService(
    localPeerId: localPeerId,
    bleService: bleService,
    routeLookup: (dest) => routingTable.bestRoute(dest),
    deviceResolver: (peerId) => connectionManager.deviceForPeer(peerId),
    isPeerConnected: (peerId) => connectionManager.isPeerConnected(peerId),
  );
});

/// The message creation controller.
final messageControllerProvider = Provider<MessageController>((ref) {
  final store = ref.watch(outboundMessageStoreProvider);
  final localPeerId = ref.watch(localPeerIdForMessageProvider);
  final transmissionService = ref.watch(messageTransmissionServiceProvider);
  return MessageController(
    store: store,
    localPeerId: localPeerId,
    transmissionService: transmissionService,
  );
});

/// State for the message composer UI.
class MessageComposerState {
  const MessageComposerState({
    this.isCreating = false,
    this.lastError,
  });

  final bool isCreating;
  final String? lastError;

  MessageComposerState copyWith({
    bool? isCreating,
    String? Function()? lastError,
  }) {
    return MessageComposerState(
      isCreating: isCreating ?? this.isCreating,
      lastError: lastError != null ? lastError() : this.lastError,
    );
  }
}

/// Notifier for the message composer UI state.
///
/// Handles the I9.4 create-and-transmit flow:
/// 1. Create message (sync)
/// 2. Trigger background transmission (async)
/// 3. Update message state as transmission progresses
class MessageComposerNotifier extends StateNotifier<MessageComposerState> {
  MessageComposerNotifier(this._ref)
      : super(const MessageComposerState());

  final Ref _ref;

  MessageController get _controller =>
      _ref.read(messageControllerProvider);

  /// Create and send a message.
  ///
  /// Creates the message synchronously, then triggers async
  /// transmission in the background. The message state will be
  /// updated as transmission progresses.
  void sendMessage({
    required String destinationPeerId,
    required String content,
  }) {
    state = state.copyWith(isCreating: true, lastError: null);

    final result = _controller.createMessage(
      destinationPeerId: destinationPeerId,
      content: content,
    );

    switch (result) {
      case MessageCreationSuccess(:final outbound):
        state = state.copyWith(isCreating: false);
        // Trigger async transmission in the background.
        unawaited(_transmitInBackground(outbound));
      case MessageCreationFailure(:final error):
        state = state.copyWith(
          isCreating: false,
          lastError: () => error,
        );
    }
  }

  /// Trigger background transmission for a created message.
  ///
  /// Uses the existing message from the store — does NOT create
  /// a second message.
  Future<void> _transmitInBackground(OutboundMessage outbound) async {
    try {
      final controller = _ref.read(messageControllerProvider);
      final transmissionService = controller.transmissionService;
      if (transmissionService == null) return;

      // Update state: CREATED → READY.
      var msg = outbound.message;
      msg = msg.copyWith(state: MessageState.queued);
      msg = msg.copyWith(state: MessageState.routeLookup);

      // Transmit.
      final result = await transmissionService.transmit(
        message: msg,
        envelope: outbound.envelope,
      );

      // Update state based on result.
      msg = switch (result) {
        TransmissionSent() => msg.copyWith(state: MessageState.delivered),
        TransmissionNoRoute() => msg.copyWith(state: MessageState.noRoute),
        TransmissionNextHopUnavailable() =>
          msg.copyWith(state: MessageState.failed),
        TransmissionTransportFailed() =>
          msg.copyWith(state: MessageState.failed),
        TransmissionEncodingFailed() =>
          msg.copyWith(state: MessageState.failed),
        TransmissionRejected() => msg.copyWith(state: MessageState.rejected),
      };

      // Update the message in the store.
      final store = _ref.read(outboundMessageStoreProvider);
      store.update(OutboundMessage(
        message: msg,
        text: outbound.text,
        createdAt: outbound.createdAt,
      ));
    } catch (e) {
      // Transmission failure is reflected in message state,
      // not in composer state.
    }
  }

  /// Clear any error state.
  void clearError() {
    state = state.copyWith(lastError: () => null);
  }
}

/// Provider for the message composer state.
final messageComposerProvider =
    StateNotifierProvider<MessageComposerNotifier, MessageComposerState>(
  (ref) {
    return MessageComposerNotifier(ref);
  },
);
