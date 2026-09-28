import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/message/application/message_relay_service.dart';
import 'package:onebit/features/message/application/message_transmission_service.dart';
import 'package:onebit/features/message/models/message_envelope.dart';
import 'package:onebit/features/message/models/message_envelope_codec.dart';
import 'package:onebit/features/message/models/message_id.dart';
import 'package:onebit/features/message/models/message_state.dart';
import 'package:onebit/features/message/models/onebit_message.dart';
import 'package:onebit/features/protocol/message_codec.dart';
import 'package:onebit/features/protocol/onebit_packet.dart';
import 'package:onebit/features/protocol/packet_codec.dart';
import 'package:onebit/features/reliable/transfer.dart';
import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/routing_validators.dart';

/// Resolves a BLE device address to a peer's cryptographic identity.
typedef DeviceToIdentity = String? Function(String deviceId);

/// Resolves a peer's cryptographic identity to its BLE device address.
typedef IdentityToDevice = String? Function(String peerIdentityId);

/// Looks up the best route to a destination.
typedef RouteLookup = Route? Function(String destinationPeerId);

/// Bridges the message database layer with the BLE transport stack.
///
/// Send path — picks whichever of these can actually reach the peer:
/// ```
/// mesh:   Message → MessageEnvelope → MessageTransmissionService
///                    → route lookup → next hop → BLE
/// direct: Message → MessageCodec → OneBitPacket → BLE
/// ```
///
/// The mesh path is preferred whenever we know the peer's identity and
/// hold a route to it, because an envelope can be relayed through
/// intermediate nodes. The direct path is the fallback for legacy
/// conversations (keyed by BLE address) and for peers we have no route to.
///
/// Receive path:
/// ```
/// BLE → ReliableTransfer → PacketCodec
///   ├─ topology advertisement → MeshRouter (handled by its own listener)
///   ├─ I9 envelope → addressed to us? persist it : MessageRelayService
///   └─ legacy format → MessageCodec → Database
/// ```
class MessageTransport {
  MessageTransport({
    required this._bleService,
    required this._database,
    this._relayService,
    this._localPeerId = '',
    this._identityForDevice,
    this._deviceForPeer,
    this._routeLookup,
    this._transmissionService,
  });

  final BleService _bleService;
  final AppDatabase _database;
  final MessageRelayService? _relayService;

  /// Our own cryptographic identity. Empty until the identity loads,
  /// in which case the mesh path stays disabled.
  final String _localPeerId;

  final DeviceToIdentity? _identityForDevice;
  final IdentityToDevice? _deviceForPeer;
  final RouteLookup? _routeLookup;
  final MessageTransmissionService? _transmissionService;

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

  // ── Sending ───────────────────────────────────────────────

  /// Send a message to a peer.
  ///
  /// [peerDeviceId] is whatever the conversation stores — historically a
  /// BLE address, now the peer's identity once we have learned it. Both
  /// are accepted and resolved to an identity for routing.
  ///
  /// Returns [TransferResult.delivered] on success, or
  /// [TransferResult.failed] / [TransferResult.cancelled] on failure.
  Future<TransferResult> sendMessage({
    required String peerDeviceId,
    required int conversationId,
    required String content,
  }) async {
    final localMsgId = await _database.insertMessage(
      conversationId: conversationId,
      content: content,
    );
    final externalId = 'm_$localMsgId';

    final Uint8List messageBytes;
    try {
      messageBytes = MessageCodec.encode(
        externalMessageId: externalId,
        content: content,
        timestampMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    } catch (e) {
      await _updateMessageStatus(localMsgId, 'failed');
      AppLogger.error('MessageTransport: could not encode message', e);
      return TransferResult.failed;
    }

    final peerIdentity = _resolveIdentity(peerDeviceId);

    // One peer, one thread: as soon as we know the cryptographic
    // identity behind a BLE address, retire the address key so the
    // conversation survives Bluetooth address rotation.
    if (peerIdentity != null && peerDeviceId != peerIdentity) {
      await _migrateConversationKey(conversationId, peerIdentity);
    }

    // Prefer the mesh — an envelope can cross hops we are not on.
    if (peerIdentity != null) {
      final viaMesh = await _sendViaMesh(peerIdentity, messageBytes);
      if (viaMesh != null) {
        await _updateMessageStatus(
          localMsgId,
          viaMesh == TransferResult.delivered ? 'sent' : 'failed',
        );
        AppLogger.info('MessageTransport: mesh send result=$viaMesh');
        return viaMesh;
      }
      // Mesh could not carry it — fall through to a direct send.
    }

    return _sendDirect(
      peerDeviceId: peerDeviceId,
      peerIdentity: peerIdentity,
      localMsgId: localMsgId,
      messageBytes: messageBytes,
    );
  }

  /// Route the message through I8/I9. Returns null when the mesh cannot
  /// carry it — too large, no usable next hop, or no transmission
  /// service — so the caller can fall back to a direct send.
  Future<TransferResult?> _sendViaMesh(
    String destination,
    Uint8List messageBytes,
  ) async {
    final transmission = _transmissionService;
    final routeLookup = _routeLookup;
    if (transmission == null ||
        routeLookup == null ||
        !_canUseMesh(destination)) {
      return null;
    }
    if (routeLookup(destination) == null) return null;

    final messageId = MessageId();
    final envelope = MessageEnvelope(
      protocolVersion: messageProtocolVersion,
      messageId: messageId,
      sourcePeerId: _localPeerId,
      destinationPeerId: destination,
      payload: messageBytes,
    );

    // The envelope adds an 85-byte header to an already framed message.
    // Anything that does not fit must go direct (or be chunked later).
    if (!envelope.isValid ||
        envelope.estimatedSize > PacketConstants.maxPayloadSize) {
      return null;
    }

    final message = OneBitMessage(
      id: messageId,
      sourcePeerId: _localPeerId,
      destinationPeerId: destination,
      state: MessageState.created,
      createdAt: DateTime.now().toUtc(),
      payloadSizeBytes: messageBytes.length,
    );

    final TransmissionResult outcome;
    try {
      outcome = await transmission.transmit(
        message: message,
        envelope: envelope,
      );
    } catch (e) {
      AppLogger.error('MessageTransport: mesh transmit threw', e);
      return null;
    }

    return switch (outcome) {
      TransmissionSent() => TransferResult.delivered,
      // Anything else means the mesh did not carry it — let the direct
      // path have a go rather than reporting a failure we can avoid.
      _ => null,
    };
  }

  /// Send straight to the peer's BLE address.
  Future<TransferResult> _sendDirect({
    required String peerDeviceId,
    required String? peerIdentity,
    required int localMsgId,
    required Uint8List messageBytes,
  }) async {
    final deviceId = _resolveDevice(peerDeviceId, peerIdentity);
    if (deviceId == null) {
      await _updateMessageStatus(localMsgId, 'failed');
      AppLogger.info(
        'MessageTransport: no reachable device for $peerDeviceId',
      );
      return TransferResult.failed;
    }

    if (messageBytes.length > PacketConstants.maxPayloadSize) {
      await _updateMessageStatus(localMsgId, 'failed');
      AppLogger.error(
        'MessageTransport: encoded message too large '
        '${messageBytes.length} bytes (max ${PacketConstants.maxPayloadSize})',
      );
      return TransferResult.failed;
    }

    final packet = OneBitPacket(
      type: PacketType.message,
      packetId: _nextPacketId(),
      payload: messageBytes,
    );

    final Uint8List packetBytes;
    try {
      packetBytes = PacketCodec.encode(packet);
    } catch (e) {
      await _updateMessageStatus(localMsgId, 'failed');
      AppLogger.error('MessageTransport: could not encode packet', e);
      return TransferResult.failed;
    }

    AppLogger.info(
      'MessageTransport: sending direct to $deviceId, '
      '${messageBytes.length} bytes, packet ${packet.packetId}',
    );

    final result = await _bleService.sendReliable(deviceId, packetBytes);

    final status = result == TransferResult.delivered ? 'sent' : 'failed';
    await _updateMessageStatus(localMsgId, status);

    AppLogger.info('MessageTransport: send result=$status');
    return result;
  }

  // ── Receiving ─────────────────────────────────────────────

  /// Handle an incoming reliable data payload from a peer.
  ///
  /// Topology advertisements are not ours — MeshRouter consumes those
  /// from the same broadcast stream.
  void _handleIncoming(ReliableDataReceived data) {
    try {
      final packet = PacketCodec.decode(Uint8List.fromList(data.payload));

      if (packet.type == PacketType.topologyAdvertisement) return;

      if (packet.type != PacketType.message) {
        AppLogger.warning(
          'MessageTransport: ignoring non-message packet type '
          '0x${packet.type.toRadixString(16)}',
        );
        return;
      }

      final payload = Uint8List.fromList(packet.payload);
      if (_isI9Envelope(payload)) {
        _handleI9Envelope(data.deviceId, payload);
      } else {
        _handleLegacyMessage(data.deviceId, packet);
      }
    } catch (e) {
      AppLogger.error('MessageTransport: failed to decode incoming message', e);
    }
  }

  /// Check if the payload starts with a valid I9.2 envelope version byte.
  ///
  /// A legacy `MessageCodec` frame opens with the big-endian length of the
  /// external message id, which is a handful of bytes in practice, so the
  /// version byte is a safe discriminator — the length floor below rules out
  /// even a short frame being mistaken for an envelope.
  bool _isI9Envelope(Uint8List payload) {
    if (payload.length < envelopeHeaderSize) return false;
    return payload[0] == messageProtocolVersion;
  }

  /// Handle an incoming I9.2 envelope: persist it if it is for us,
  /// otherwise hand it to the relay for forwarding.
  void _handleI9Envelope(String deviceId, Uint8List payload) {
    try {
      final envelope = MessageEnvelopeCodec.decode(payload);

      AppLogger.info(
        'MessageTransport: received I9.2 envelope from $deviceId, '
        'id=${envelope.messageId.value.substring(0, 8)}... '
        'src=${envelope.sourcePeerId.substring(0, 8)}... '
        'dst=${envelope.destinationPeerId.substring(0, 8)}...',
      );

      // Only consume it if it is actually addressed to us; anything else
      // belongs to the relay.
      if (_localPeerId.isNotEmpty &&
          envelope.destinationPeerId == _localPeerId) {
        _deliverEnvelope(envelope);
        return;
      }

      final relay = _relayService;
      if (relay == null) {
        AppLogger.warning(
          'MessageTransport: no relay service — dropping envelope for '
          '${envelope.destinationPeerId.substring(0, 8)}...',
        );
        return;
      }
      relay.receiveAndRelay(envelope);
    } catch (e) {
      AppLogger.error(
        'MessageTransport: failed to decode I9.2 envelope',
        e,
      );
    }
  }

  /// Persist an envelope addressed to the local peer.
  Future<void> _deliverEnvelope(MessageEnvelope envelope) async {
    final DecodedMessage decoded;
    try {
      decoded = MessageCodec.decode(envelope.payload);
    } catch (e) {
      AppLogger.error('MessageTransport: undecodable envelope payload', e);
      return;
    }

    await _persistIncoming(
      peerKey: envelope.sourcePeerId,
      fallbackDeviceId: _deviceForPeer?.call(envelope.sourcePeerId),
      decoded: decoded,
    );
  }

  /// Handle an incoming legacy MessageCodec message.
  void _handleLegacyMessage(String deviceId, OneBitPacket packet) {
    final decoded = MessageCodec.decode(Uint8List.fromList(packet.payload));

    AppLogger.info(
      'MessageTransport: received legacy message from $deviceId, '
      'id=${decoded.externalMessageId}',
    );

    _persistIncoming(peerKey: deviceId, fallbackDeviceId: deviceId, decoded: decoded);
  }

  /// Persist a decoded incoming message against the right conversation.
  ///
  /// [peerKey] is the peer's identity when we have it, otherwise the BLE
  /// address. A conversation previously keyed by the BLE address is
  /// migrated to the identity so one peer keeps one thread even after
  /// Bluetooth rotates the address.
  Future<void> _persistIncoming({
    required String peerKey,
    String? fallbackDeviceId,
    required DecodedMessage decoded,
  }) async {
    var conversation = await _database.getConversationByPeerDevice(peerKey);

    if (conversation == null) {
      final legacyKey =
          (fallbackDeviceId != null && fallbackDeviceId != peerKey)
              ? fallbackDeviceId
              : null;
      if (legacyKey != null) {
        final legacy = await _database.getConversationByPeerDevice(legacyKey);
        if (legacy != null) {
          await (_database.update(_database.conversations)
                ..where((t) => t.id.equals(legacy.id)))
              .write(ConversationsCompanion(
            peerDeviceId: Value(peerKey),
            updatedAt: Value(DateTime.now()),
          ));
          conversation = legacy;
          AppLogger.info(
            'MessageTransport: conversation ${legacy.id} re-keyed to identity',
          );
        }
      }
    }

    if (conversation == null) {
      final label = RoutingValidators.isValidPeerId(peerKey)
          ? 'OneBit (${peerKey.substring(0, 6)})'
          : _shortAddress(peerKey);
      final convId = await _database.createConversationWithPeer(label, peerKey);
      conversation = await _database.getConversation(convId);
      AppLogger.info(
        'MessageTransport: created conversation $convId for peer $peerKey',
      );
    }

    final convId = conversation!.id;
    final msgId = await _database.insertReceivedMessage(
      conversationId: convId,
      content: decoded.content,
      externalMessageId: decoded.externalMessageId,
    );

    if (msgId != null) {
      AppLogger.info(
        'MessageTransport: persisted message $msgId in conversation $convId',
      );
    } else {
      AppLogger.info(
        'MessageTransport: duplicate message ${decoded.externalMessageId} '
        'ignored',
      );
    }
  }

  /// Re-key a conversation from a BLE address to the peer's identity.
  Future<void> _migrateConversationKey(int conversationId, String peerKey) async {
    try {
      await (_database.update(_database.conversations)
            ..where((t) => t.id.equals(conversationId)))
          .write(ConversationsCompanion(
        peerDeviceId: Value(peerKey),
        updatedAt: Value(DateTime.now()),
      ));
    } catch (e) {
      AppLogger.warning('MessageTransport: could not re-key conversation: $e');
    }
  }

  // ── Resolution helpers ────────────────────────────────────

  /// Whether the mesh path is available for [destination].
  bool _canUseMesh(String destination) =>
      _localPeerId.isNotEmpty &&
      _transmissionService != null &&
      RoutingValidators.isValidPeerId(_localPeerId) &&
      RoutingValidators.isValidPeerId(destination);

  /// Resolve whatever the conversation stores into a peer identity.
  String? _resolveIdentity(String key) {
    if (RoutingValidators.isValidPeerId(key)) return key;
    final resolved = _identityForDevice?.call(key);
    if (resolved == null) return null;
    return RoutingValidators.isValidPeerId(resolved) ? resolved : null;
  }

  /// Resolve a conversation key plus identity into a BLE device address.
  String? _resolveDevice(String key, String? identity) {
    if (RoutingValidators.isValidPeerId(key)) {
      final device = _deviceForPeer?.call(key);
      if (device != null) return device;
      return identity != null && identity != key
          ? _deviceForPeer?.call(identity)
          : null;
    }
    return key;
  }

  static String _shortAddress(String address) {
    final short =
        address.length > 5 ? address.substring(address.length - 5) : address;
    return 'OneBit ($short)';
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
