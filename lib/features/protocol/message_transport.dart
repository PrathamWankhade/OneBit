import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/message/application/message_relay_service.dart';
import 'package:onebit/features/message/models/message_envelope_codec.dart';
import 'package:onebit/features/protocol/message_codec.dart';
import 'package:onebit/features/protocol/onebit_packet.dart';
import 'package:onebit/features/protocol/packet_codec.dart';
import 'package:onebit/features/reliable/transfer.dart';

/// Bridges the message database layer with the BLE transport stack.
///
/// Send path:
/// ```
/// Message → MessageCodec → OneBitPacket → ReliableTransfer → BLE
/// ```
///
/// Receive path:
/// ```
/// BLE → ReliableTransfer → PacketCodec
///   ├─ I9.2 envelope → MessageRelayService (relay or local)
///   └─ Legacy format → MessageCodec → Database
/// ```
class MessageTransport {
  MessageTransport({
    required this._bleService,
    required this._database,
    this._relayService,
  });

  final BleService _bleService;
  final AppDatabase _database;
  final MessageRelayService? _relayService;

  StreamSubscription<ReliableDataReceived>? _receiveSub;
  int _packetIdCounter = 0;

  /// Start listening for incoming messages from peers.
  void startListening() {
    _receiveSub?.cancel();
    _receiveSub = _bleService.reliableDataReceived.listen(
      _handleIncoming,
      onError: (e) => AppLogger.error('MessageTransport receive error', e),
    );
    AppLogger.info('MessageTransport: listening for incoming messages');
  }

  /// Stop listening for incoming messages.
  void stopListening() {
    _receiveSub?.cancel();
    _receiveSub = null;
  }

  /// Send a message to a connected peer.
  ///
  /// Returns [TransferResult.delivered] on success, or
  /// [TransferResult.failed] / [TransferResult.cancelled] on failure.
  Future<TransferResult> sendMessage({
    required String peerDeviceId,
    required int conversationId,
    required String content,
  }) async {
    // Create the external message ID for deduplication.
    // Use local message ID + timestamp for uniqueness.
    final localMsgId = await _database.insertMessage(
      conversationId: conversationId,
      content: content,
    );
    final externalId = 'm_$localMsgId';

    // Update the message with the external ID.
    // (We need this for future reference, though the transport
    //  layer already knows the ID.)

    // Serialize the message.
    final messageBytes = MessageCodec.encode(
      externalMessageId: externalId,
      content: content,
      timestampMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );

    // Validate the encoded message fits in a single packet.
    if (messageBytes.length > PacketConstants.maxPayloadSize) {
      await _updateMessageStatus(localMsgId, 'failed');
      AppLogger.error(
        'MessageTransport: encoded message too large '
        '${messageBytes.length} bytes (max ${PacketConstants.maxPayloadSize})',
      );
      return TransferResult.failed;
    }

    // Wrap in a OneBit packet.
    final packet = OneBitPacket(
      type: PacketType.message,
      packetId: _nextPacketId(),
      payload: messageBytes,
    );

    // Encode the packet.
    final packetBytes = PacketCodec.encode(packet);

    // Send through reliable transport.
    AppLogger.info(
      'MessageTransport: sending message to $peerDeviceId, '
      '${content.length} chars, packet ${packet.packetId}',
    );

    final result = await _bleService.sendReliable(peerDeviceId, packetBytes);

    // Update message status based on result.
    final status = result == TransferResult.delivered ? 'sent' : 'failed';
    await _updateMessageStatus(localMsgId, status);

    AppLogger.info('MessageTransport: send result=$status');
    return result;
  }

  /// Handle an incoming reliable data payload from a peer.
  void _handleIncoming(ReliableDataReceived data) {
    try {
      // Decode the OneBit packet.
      final packet = PacketCodec.decode(Uint8List.fromList(data.payload));

      // Validate packet type.
      if (packet.type != PacketType.message) {
        AppLogger.warning(
          'MessageTransport: ignoring non-message packet type '
          '0x${packet.type.toRadixString(16)}',
        );
        return;
      }

      // Try I9.2 envelope decode first.
      final envelopePayload = Uint8List.fromList(packet.payload);
      if (_relayService != null && _isI9Envelope(envelopePayload)) {
        _handleI9Envelope(data.deviceId, envelopePayload);
      } else {
        // Fall back to legacy MessageCodec format.
        _handleLegacyMessage(data.deviceId, packet);
      }
    } catch (e) {
      AppLogger.error('MessageTransport: failed to decode incoming message', e);
    }
  }

  /// Check if the payload starts with a valid I9.2 envelope version byte.
  bool _isI9Envelope(Uint8List payload) {
    if (payload.isEmpty) return false;
    // I9.2 envelope version byte is 0x01.
    return payload[0] == 0x01;
  }

  /// Handle an incoming I9.2 envelope via the relay service.
  void _handleI9Envelope(String deviceId, Uint8List payload) {
    try {
      final envelope = MessageEnvelopeCodec.decode(payload);

      AppLogger.info(
        'MessageTransport: received I9.2 envelope from $deviceId, '
        'id=${envelope.messageId.value.substring(0, 8)}... '
        'src=${envelope.sourcePeerId.substring(0, 8)}... '
        'dst=${envelope.destinationPeerId.substring(0, 8)}...',
      );

      // Delegate to relay service (handles local delivery vs forwarding).
      _relayService!.receiveAndRelay(envelope);
    } catch (e) {
      AppLogger.error(
        'MessageTransport: failed to decode I9.2 envelope',
        e,
      );
    }
  }

  /// Handle an incoming legacy MessageCodec message.
  void _handleLegacyMessage(String deviceId, OneBitPacket packet) {
    final decoded = MessageCodec.decode(Uint8List.fromList(packet.payload));

    AppLogger.info(
      'MessageTransport: received legacy message from $deviceId, '
      'id=${decoded.externalMessageId}',
    );

    _processIncomingMessage(deviceId, decoded);
  }

  /// Process a decoded incoming message and persist it.
  Future<void> _processIncomingMessage(
    String deviceId,
    DecodedMessage decoded,
  ) async {
    // Find or create a conversation for this peer.
    var conversation = await _database.getConversationByPeerDevice(deviceId);
    if (conversation == null) {
      // Use truncated device ID as a fallback name (last 5 chars of MAC).
      final shortId =
          deviceId.length > 5 ? deviceId.substring(deviceId.length - 5) : deviceId;
      final convId = await _database.createConversationWithPeer(
        'OneBit ($shortId)',
        deviceId,
      );
      conversation = await _database.getConversation(convId);
      AppLogger.info(
        'MessageTransport: created conversation $convId for peer $deviceId',
      );
    }

    // Insert the message with deduplication.
    final convId = conversation!.id;
    final msgId = await _database.insertReceivedMessage(
      conversationId: convId,
      content: decoded.content,
      externalMessageId: decoded.externalMessageId,
    );

    if (msgId != null) {
      AppLogger.info(
        'MessageTransport: persisted message $msgId in '
        'conversation $convId',
      );
    } else {
      AppLogger.info(
        'MessageTransport: duplicate message ${decoded.externalMessageId} '
        'ignored',
      );
    }
  }

  /// Update a message's status.
  Future<void> _updateMessageStatus(int messageId, String status) async {
    await (_database.update(_database.messages)
          ..where((t) => t.id.equals(messageId)))
        .write(MessagesCompanion(
      status: Value(status),
    ));
  }

  /// Generate the next packet ID (wraps at 256).
  int _nextPacketId() {
    _packetIdCounter = (_packetIdCounter + 1) & 0xFF;
    return _packetIdCounter;
  }

  /// Dispose resources.
  void dispose() {
    stopListening();
  }
}
