import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/crypto/e2ee_frame.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/message/application/message_relay_service.dart';
import 'package:onebit/features/message/application/message_transmission_service.dart';
import 'package:onebit/features/message/models/message_envelope.dart';
import 'package:onebit/features/message/models/message_envelope_codec.dart';
import 'package:onebit/features/message/models/message_id.dart';
import 'package:onebit/features/message/models/message_state.dart';
import 'package:onebit/features/message/models/onebit_message.dart';
import 'package:onebit/features/protocol/attachment_segment.dart';
import 'package:onebit/features/protocol/key_announcement.dart';
import 'package:onebit/features/protocol/message_codec.dart';
import 'package:onebit/features/protocol/onebit_packet.dart';
import 'package:onebit/features/protocol/packet_chunking.dart';
import 'package:onebit/features/protocol/packet_codec.dart';
import 'package:onebit/features/protocol/receipt_tag.dart';
import 'package:onebit/features/reliable/transfer.dart';
import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/routing_validators.dart';
import 'package:path_provider/path_provider.dart';

/// Resolves a BLE device address to a peer's cryptographic identity.
typedef DeviceToIdentity = String? Function(String deviceId);

/// Resolves a peer's cryptographic identity to its BLE device address.
typedef IdentityToDevice = String? Function(String peerIdentityId);

/// Looks up the best route to a destination.
typedef RouteLookup = Route? Function(String destinationPeerId);

/// Loads our X25519 key-agreement pair. Null when no identity is loaded
/// — the transport then behaves exactly as it did before encryption.
typedef LocalKeyAgreement = Future<SimpleKeyPair> Function();

/// Signs bytes with the local Ed25519 identity key.
typedef LocalSigner = Future<Uint8List> Function(Uint8List message);

/// Where received attachment files land. Overridable in tests, where
/// the platform plugin has nothing to answer with.
typedef AttachmentDirectory = Future<Directory> Function();

/// The app documents directory: the same folder the sender's copy
/// lives in and the thread's renderers read from.
Future<Directory> _defaultAttachmentDirectory() =>
    getApplicationDocumentsDirectory();

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
///
/// ## Outbox
///
/// Every outbound row starts life in the `queued` state, and is moved
/// to `sent` or `failed` once an attempt settles. `failed` is reserved
/// for failures a retry could not fix (it will not encode, it will not
/// fit); "the peer was not on the air" stays `queued` and is retried by
/// [flushQueued] whenever [_routeEvents] or [_connectionEvents] says the
/// reachable set may have changed.
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
    this._routeEvents,
    this._connectionEvents,
    this._localKeyAgreement,
    this._localSign,
    this._attachmentDirectory,
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

  /// Agreement pair and signer for end-to-end encryption. Both absent
  /// in tests and before the identity loads — everything then travels
  /// exactly as it used to.
  final LocalKeyAgreement? _localKeyAgreement;
  final LocalSigner? _localSign;

  /// Where completed attachments are written. Null in production,
  /// which uses the app documents directory — and in any test that
  /// never completes one, where the platform plugin has nothing to
  /// answer with.
  final AttachmentDirectory? _attachmentDirectory;

  /// Our X25519 pair once loaded. Stable per identity, so one load
  /// serves the life of the transport.
  SimpleKeyPair? _keyAgreementPair;

  /// X25519 keys learned from direct-link frames whose sender has no
  /// resolved Ed identity yet: BLE address → key. The database only
  /// ever holds keys attributed to an identity.
  final Map<String, Uint8List> _transientKeys = {};

  /// Peers that proved they hold our key by decrypting one of our
  /// frames. Only they are spared the announcement that rides along
  /// with plaintext sends.
  final Set<String> _peersKnowingUs = {};

  /// Last announcement per peer, so a peer that never answers does not
  /// get one stapled to every single message.
  final Map<String, DateTime> _lastAnnounced = {};

  /// Announces that the route table was recomputed — a neighbour
  /// appeared, left, or advertised somebody new.
  final Stream<void>? _routeEvents;

  /// Announces that the set of connected peers changed.
  final Stream<void>? _connectionEvents;

  StreamSubscription<ReliableDataReceived>? _receiveSub;
  StreamSubscription<void>? _routeSub;
  StreamSubscription<void>? _connectionSub;

  /// Puts the slices of a chunked payload back together as they arrive.
  final _chunks = PacketChunkReassembler();

  int _packetIdCounter = 0;
  bool _flushing = false;

  /// Start listening for incoming messages from peers.
  void startListening() {
    _receiveSub?.cancel();
    _receiveSub = _bleService.reliableDataReceived.listen(
      _handleIncoming,
      onError: (e) => AppLogger.error('MessageTransport receive error', e),
    );

    // Both events mean the same thing to the outbox: a message that had
    // nowhere to go may have somewhere now. Re-entrancy is guarded, so
    // a burst of them costs one pass, not one per event.
    _routeSub?.cancel();
    _routeSub = _routeEvents?.listen(
      (_) => unawaited(flushQueued()),
      onError: (Object e) => AppLogger.error('MessageTransport route sub', e),
    );
    _connectionSub?.cancel();
    _connectionSub = _connectionEvents?.listen(
      (_) => unawaited(flushQueued()),
      onError: (Object e) =>
          AppLogger.error('MessageTransport connection sub', e),
    );

    AppLogger.info('MessageTransport: listening for incoming messages');
  }

  /// Stop listening for incoming messages.
  void stopListening() {
    _receiveSub?.cancel();
    _receiveSub = null;
    _routeSub?.cancel();
    _routeSub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
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
  /// The row is born in the outbox (`queued`) so that a send interrupted
  /// by a crash is still picked up by a later flush.
  Future<TransferResult> sendMessage({
    required String peerDeviceId,
    required int conversationId,
    required String content,
  }) async {
    final localMsgId = await _database.insertMessage(
      conversationId: conversationId,
      content: content,
      status: 'queued',
    );
    return _deliver(
      peerDeviceId: peerDeviceId,
      conversationId: conversationId,
      localMsgId: localMsgId,
      content: content,
    );
  }

  /// Re-attempt every message waiting for its peer.
  ///
  /// Called when a peer connects or the route table is recomputed: both
  /// mean a message that had nowhere to go may have somewhere now. Each
  /// attempt resolves the destination afresh, so a conversation keyed by
  /// a BLE address retries under whatever identity the peer has since
  /// proven.
  Future<void> flushQueued() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final queued = await _database.queuedMessages();
      for (final row in queued) {
        final conversation =
            await _database.getConversation(row.conversationId);
        final peerDeviceId = conversation?.peerDeviceId;
        if (peerDeviceId == null || peerDeviceId.isEmpty) continue;

        await _deliver(
          peerDeviceId: peerDeviceId,
          conversationId: row.conversationId,
          localMsgId: row.id,
          content: row.content,
        );
      }
    } catch (e) {
      AppLogger.error('MessageTransport: outbox flush failed', e);
    } finally {
      _flushing = false;
    }
  }

  /// The wire identity of a message row.
  ///
  /// Derived from the primary key rather than stored, so a retry carries
  /// exactly the id the receiver saw the first time — that is what lets a
  /// receiving conversation drop the duplicate if the first attempt did
  /// get through after all. It is also the name a receipt runs back on:
  /// the peer reports `m_7`, and `_localRowIdFor` turns that into row 7.
  String _externalIdFor(int messageId) => 'm_$messageId';

  /// Send a file as a visible manifest plus hidden slices.
  ///
  /// Every row travels the ordinary path — queued, encrypted when the
  /// peer's key is held, receipted, retried by the outbox — so a file
  /// needs no second transport. The manifest renders in the thread;
  /// the slices never do. Returns the worst outcome across the parts:
  /// anything not `delivered` stays queued for a later flush.
  Future<TransferResult> sendAttachment({
    required String peerDeviceId,
    required int conversationId,
    required String kind,
    required String fileName,
    required Uint8List bytes,
    List<String> extra = const [],
  }) async {
    if (bytes.isEmpty) {
      AppLogger.error('MessageTransport: refusing empty attachment');
      return TransferResult.failed;
    }

    final name = AttachmentManifest.sanitize(fileName);
    final segId = _newSegId();
    late final List<String> slices;
    try {
      slices = SegTag.encodeSlices(segId: segId, fileName: name, bytes: bytes);
    } catch (e) {
      AppLogger.error('MessageTransport: attachment does not fit frames', e);
      return TransferResult.failed;
    }

    Future<TransferResult> sendRow(String content) async {
      final localMsgId = await _database.insertMessage(
        conversationId: conversationId,
        content: content,
        status: 'queued',
      );
      return _deliver(
        peerDeviceId: peerDeviceId,
        conversationId: conversationId,
        localMsgId: localMsgId,
        content: content,
      );
    }

    var result = await sendRow(
      AttachmentManifest.encode(
        kind: kind,
        fileName: name,
        segId: segId,
        count: slices.length,
        extra: extra,
      ),
    );
    for (final slice in slices) {
      final leg = await sendRow(slice);
      if (leg != TransferResult.delivered) result = leg;
    }
    return result;
  }

  /// Sixteen hex chars of channel randomness naming one attachment.
  String _newSegId() {
    final random = math.Random.secure();
    final bytes = Uint8List(8);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return IdentityRepository.bytesToHex(bytes);
  }

  /// Push one already-stored message out to its peer.
  ///
  /// Shared by the first attempt and every retry, because both must
  /// resolve the destination and pick a route from scratch.
  ///
  /// Failures are classified so the outbox knows what to do next:
  /// * `failed` — deterministic; encoding this again will fail again.
  /// * `queued` — transient; the peer was not reachable this time and a
  ///   later flush should try again.
  Future<TransferResult> _deliver({
    required String peerDeviceId,
    required int conversationId,
    required int localMsgId,
    required String content,
  }) async {
    final externalId = _externalIdFor(localMsgId);

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

    // Encrypt when we hold the peer's key; otherwise send as before
    // and staple our signed key to the exchange so the peer can
    // encrypt back. Either way the bytes below are what travels.
    final protected = await _protectForPeer(
      peerKey: peerDeviceId,
      peerIdentity: peerIdentity,
      frame: messageBytes,
    );
    final outbound = protected.payload;
    if (protected.encrypted) {
      await _database.setMessageEncrypted(localMsgId);
    }

    // Prefer the mesh — an envelope can cross hops we are not on.
    if (peerIdentity != null) {
      final viaMesh = await _sendViaMesh(peerIdentity, outbound);
      if (viaMesh != null) {
        await _updateMessageStatus(
          localMsgId,
          viaMesh == TransferResult.delivered ? 'sent' : 'queued',
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
      messageBytes: outbound,
    );
  }

  /// Our X25519 pair once loaded, or null when encryption is
  /// unavailable — no identity yet, or none wired in at all.
  Future<SimpleKeyPair?> _loadKeyAgreement() async {
    if (_keyAgreementPair != null) return _keyAgreementPair;
    final load = _localKeyAgreement;
    if (load == null) return null;
    try {
      return _keyAgreementPair = await load();
    } catch (e) {
      AppLogger.warning('MessageTransport: no local agreement key ($e)');
      return null;
    }
  }

  /// Encrypt [frame] for the peer when we hold their key.
  ///
  /// Anything else travels exactly as it used to, plus a signed key
  /// announcement so the peer can encrypt back: their reply is what
  /// teaches us their key, and the first message of a thread is
  /// therefore the last thing in it that goes out readable.
  Future<({Uint8List payload, bool encrypted})> _protectForPeer({
    required String peerKey,
    required String? peerIdentity,
    required Uint8List frame,
  }) async {
    final agreement = await _loadKeyAgreement();
    if (agreement == null) return (payload: frame, encrypted: false);

    String? keyHex;
    if (peerIdentity != null) {
      keyHex = await _database.peerKeyAgreementKey(peerIdentity);
    }
    keyHex ??= _transientHex(
      _resolveDevice(peerKey, peerIdentity) ?? peerKey,
    );

    if (keyHex == null) {
      await _maybeAnnounce(peerKey: peerKey, peerIdentity: peerIdentity);
      return (payload: frame, encrypted: false);
    }

    try {
      final encrypted = await E2eeFrame.encrypt(
        localKeyPair: agreement,
        peerPublicKey: IdentityRepository.hexToBytes(keyHex),
        frame: frame,
      );
      await _maybeAnnounce(peerKey: peerKey, peerIdentity: peerIdentity);
      return (payload: encrypted, encrypted: true);
    } catch (e) {
      AppLogger.error(
        'MessageTransport: encrypt failed, sending plaintext',
        e,
      );
      return (payload: frame, encrypted: false);
    }
  }

  /// Publish our signed X25519 key unless the peer proved they hold
  /// it — or we knocked recently. Announcements are idempotent, so a
  /// repeat only costs a packet, but a peer that never answers should
  /// not get one stapled to every message.
  Future<void> _maybeAnnounce({
    required String peerKey,
    required String? peerIdentity,
  }) async {
    final attribution = peerIdentity ?? peerKey;
    if (_peersKnowingUs.contains(attribution)) return;

    final now = DateTime.now();
    final last = _lastAnnounced[attribution];
    if (last != null && now.difference(last) < const Duration(hours: 1)) {
      return;
    }

    final agreement = await _loadKeyAgreement();
    final sign = _localSign;
    if (agreement == null || sign == null) return;

    late Uint8List pubBytes;
    late Uint8List signature;
    try {
      pubBytes =
          Uint8List.fromList((await agreement.extractPublicKey()).bytes);
      signature = await sign(pubBytes);
    } catch (e) {
      AppLogger.error('MessageTransport: could not sign announcement', e);
      return;
    }

    final frame = KeyAnnouncement.encodeFrame(
      x25519Hex: IdentityRepository.bytesToHex(pubBytes),
      signature: signature,
      timestampMs: now.toUtc().millisecondsSinceEpoch,
    );

    final routedIdentity = peerIdentity ?? _resolveIdentity(peerKey);
    if (routedIdentity != null &&
        await _sendViaMesh(routedIdentity, frame) != null) {
      _lastAnnounced[attribution] = now;
      return;
    }

    final deviceId =
        _resolveDevice(peerKey, routedIdentity) ?? peerKey;
    if (!RoutingValidators.isValidPeerId(deviceId)) {
      await sendInPackets(
        frame,
        type: PacketType.message,
        packetId: _nextPacketId(),
        send: (bytes) => _bleService.sendReliable(deviceId, bytes),
      );
      _lastAnnounced[attribution] = now;
    } else {
      AppLogger.info('MessageTransport: no route for a key announcement');
    }
  }

  /// A learned key for a BLE address, if one arrived unattributed.
  String? _transientHex(String deviceId) {
    final key = _transientKeys[deviceId];
    return key == null ? null : IdentityRepository.bytesToHex(key);
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

    // The envelope adds an 86-byte header to an already framed message.
    // Past one packet it is carried across as many as it needs — but
    // `isValid` still has to hold, because the receiving end validates
    // the envelope before it will look at what is inside it.
    if (!envelope.isValid) return null;

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
      await _updateMessageStatus(localMsgId, 'queued');
      AppLogger.info(
        'MessageTransport: no reachable device for $peerDeviceId — queued',
      );
      return TransferResult.failed;
    }

    if (messageBytes.length > maxChunkedPayload) {
      await _updateMessageStatus(localMsgId, 'failed');
      AppLogger.error(
        'MessageTransport: encoded message too large '
        '${messageBytes.length} bytes (max $maxChunkedPayload)',
      );
      return TransferResult.failed;
    }

    AppLogger.info(
      'MessageTransport: sending direct to $deviceId, '
      '${messageBytes.length} bytes',
    );

    final result = await sendInPackets(
      messageBytes,
      type: PacketType.message,
      packetId: _nextPacketId(),
      send: (bytes) => _bleService.sendReliable(deviceId, bytes),
    );

    // A BLE send that did not land is almost always a link that went
    // away mid-flight — the peer may well be back by the next flush.
    final status = result == TransferResult.delivered ? 'sent' : 'queued';
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

      final payload = _chunks.accept(
        data.deviceId,
        packet.packetId,
        Uint8List.fromList(packet.payload),
      );
      if (payload == null) return; // still assembling

      if (_isI9Envelope(payload)) {
        _handleI9Envelope(data.deviceId, payload);
      } else {
        _handleLegacyMessage(data.deviceId, payload);
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
    var payload = envelope.payload;

    // The outer layer comes off first: what decrypts was encrypted
    // for us, and its header teaches us the sender's key.
    final opened = await _tryDecrypt(payload);
    if (opened != null) {
      await _database.storePeerKeyAgreementPublicKey(
        identityId: envelope.sourcePeerId,
        keyAgreementPublicKey:
            IdentityRepository.bytesToHex(opened.senderKey).toLowerCase(),
      );
      _peersKnowingUs.add(envelope.sourcePeerId);
      payload = opened.frame;
    }

    // A receipt arrives before the message decoder ever sees it — the
    // frame ends in a byte that decode would call trailing.
    final receipt = ReceiptTag.decodeFrame(payload);
    if (receipt != null) {
      await _applyReceipt(receipt);
      return;
    }

    // A key announcement is verified against the identity the envelope
    // already names, then stored — never displayed, never persisted.
    final announcement = KeyAnnouncement.decodeFrame(payload);
    if (announcement != null) {
      await _applyAnnouncement(
        announcement,
        senderPeerId: envelope.sourcePeerId,
      );
      return;
    }

    final DecodedMessage decoded;
    try {
      decoded = MessageCodec.decode(payload);
    } catch (e) {
      AppLogger.error('MessageTransport: undecodable envelope payload', e);
      return;
    }

    // A slice is machinery, not mail: persist it silently and complete
    // the file when its parts are all present.
    final envelopeSegment = SegTag.parse(decoded.content);
    if (envelopeSegment != null) {
      await _handleSegment(
        peerKey: envelope.sourcePeerId,
        fallbackDeviceId: _deviceForPeer?.call(envelope.sourcePeerId),
        decoded: decoded,
        segment: envelopeSegment,
        isEncrypted: opened != null,
      );
      return;
    }

    await _persistIncoming(
      peerKey: envelope.sourcePeerId,
      fallbackDeviceId: _deviceForPeer?.call(envelope.sourcePeerId),
      decoded: decoded,
      isEncrypted: opened != null,
    );
  }

  /// Handle an incoming legacy MessageCodec message.
  Future<void> _handleLegacyMessage(
    String deviceId,
    Uint8List payload,
  ) async {
    final opened = await _tryDecrypt(payload);
    if (opened != null) {
      // No envelope names the sender here, so the key is attributed to
      // the resolved identity when there is one — and remembered
      // against the address either way, so the reply can encrypt.
      _transientKeys[deviceId] = opened.senderKey;
      final identity = _resolveIdentity(deviceId);
      if (identity != null) {
        await _database.storePeerKeyAgreementPublicKey(
          identityId: identity,
          keyAgreementPublicKey:
              IdentityRepository.bytesToHex(opened.senderKey).toLowerCase(),
        );
        _peersKnowingUs.add(identity);
      }
      payload = opened.frame;
    }

    final receipt = ReceiptTag.decodeFrame(payload);
    if (receipt != null) {
      await _applyReceipt(receipt);
      return;
    }

    final announcement = KeyAnnouncement.decodeFrame(payload);
    if (announcement != null) {
      final identity = _resolveIdentity(deviceId);
      if (identity == null) {
        AppLogger.info(
          'MessageTransport: dropping announcement from unknown $deviceId',
        );
        return;
      }
      await _applyAnnouncement(announcement, senderPeerId: identity);
      return;
    }

    final DecodedMessage decoded;
    try {
      decoded = MessageCodec.decode(payload);
    } catch (e) {
      AppLogger.error('MessageTransport: undecodable legacy payload', e);
      return;
    }

    final legacySegment = SegTag.parse(decoded.content);
    if (legacySegment != null) {
      await _handleSegment(
        peerKey: deviceId,
        fallbackDeviceId: deviceId,
        decoded: decoded,
        segment: legacySegment,
        isEncrypted: opened != null,
      );
      return;
    }

    AppLogger.info(
      'MessageTransport: received legacy message from $deviceId, '
      'id=${decoded.externalMessageId}',
    );

    await _persistIncoming(
      peerKey: deviceId,
      fallbackDeviceId: deviceId,
      decoded: decoded,
      isEncrypted: opened != null,
    );
  }

  /// Peel the encryption layer off [payload], or null when there is
  /// none for us to peel — no key loaded, not a frame, not ours.
  Future<({Uint8List senderKey, Uint8List frame})?> _tryDecrypt(
    Uint8List payload,
  ) async {
    final agreement = await _loadKeyAgreement();
    if (agreement == null) return null;
    return E2eeFrame.decrypt(localKeyPair: agreement, payload: payload);
  }

  /// Verify a key announcement and store the key it carries.
  ///
  /// The signature ties the announced key to the sender's Ed25519
  /// identity; anything else — malformed, misattributed, forged — is
  /// dropped without touching the database.
  Future<void> _applyAnnouncement(
    ({String keyHex, Uint8List signature}) announcement, {
    required String senderPeerId,
  }) async {
    if (!RoutingValidators.isValidPeerId(senderPeerId)) {
      AppLogger.warning(
        'MessageTransport: announcement from non-identity $senderPeerId',
      );
      return;
    }

    final content = KeyAnnouncement.encode(
      x25519Hex: announcement.keyHex,
      signature: announcement.signature,
    );
    late final bool genuine;
    try {
      genuine = await KeyAnnouncement.verify(
        content: content,
        senderEdPublicKey: IdentityRepository.hexToBytes(senderPeerId),
      );
    } catch (_) {
      genuine = false;
    }
    if (!genuine) {
      AppLogger.warning(
        'MessageTransport: forged announcement from '
        '${senderPeerId.substring(0, 8)}… — dropped',
      );
      return;
    }

    await _database.storePeerKeyAgreementPublicKey(
      identityId: senderPeerId,
      keyAgreementPublicKey: announcement.keyHex.toLowerCase(),
    );
    AppLogger.info(
      'MessageTransport: learned key-agreement key for '
      '${senderPeerId.substring(0, 8)}…',
    );
  }

  /// Raise our own messages to whatever a peer said about them.
  ///
  /// A receipt never produces one in return — that is what stops the two
  /// ends from handing them to each other forever.
  Future<void> _applyReceipt(
    ({ReceiptKind kind, List<String> messageIds}) receipt,
  ) async {
    var applied = 0;
    for (final wireId in receipt.messageIds) {
      final messageId = _localRowIdFor(wireId);
      if (messageId == null) {
        AppLogger.warning(
          'MessageTransport: receipt names $wireId, which is not one '
          'of ours',
        );
        continue;
      }
      await _database.ackMessage(messageId, receipt.kind.name);
      applied++;
    }
    AppLogger.info(
      'MessageTransport: peer marked $applied message(s) ${receipt.kind.name}',
    );
  }

  /// The local row a wire id was built from, or null when it is not ours.
  ///
  /// We name our messages `m_<row id>` and never store that name here —
  /// the receiving end keeps it as *its* external id, which is exactly
  /// what lets it drop a retry that landed after all. The mapping only
  /// ever runs this way round, so nothing on the way in can collide with
  /// a name a peer chose for a message of its own.
  static int? _localRowIdFor(String wireId) {
    if (!wireId.startsWith('m_')) return null;
    return int.tryParse(wireId.substring(2));
  }

  /// Tell the peer that everything in [messageIds] has been read.
  ///
  /// Sent when the conversation is opened, once, for what was waiting
  /// there — so a chat read three times asks once. One frame carries
  /// [idsPerFrame] ids; a chat with more unread than that sends the rest
  /// in follow-up frames instead of dropping them for want of room.
  Future<void> ackRead({
    required String peerKey,
    String? fallbackDeviceId,
    required List<String> messageIds,
  }) async {
    const idsPerFrame = 200;
    for (var start = 0; start < messageIds.length; start += idsPerFrame) {
      final end = math.min(start + idsPerFrame, messageIds.length);
      await _sendReceipt(
        peerKey: peerKey,
        fallbackDeviceId: fallbackDeviceId,
        kind: ReceiptKind.read,
        messageIds: messageIds.sublist(start, end),
      );
    }
  }

  /// Push a receipt out along the same two roads a message takes.
  ///
  /// Mesh first, because the sender may be several hops away and only
  /// ever told us its identity; straight to the device second. A receipt
  /// has no row of its own, so none of the status bookkeeping that rides
  /// along with a message applies to it.
  Future<void> _sendReceipt({
    required String peerKey,
    String? fallbackDeviceId,
    required ReceiptKind kind,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty || _localPeerId.isEmpty) return;

    final Uint8List frame;
    try {
      frame = ReceiptTag.encodeFrame(
        kind: kind,
        messageIds: messageIds,
        timestampMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    } catch (e) {
      AppLogger.error('MessageTransport: could not encode receipt', e);
      return;
    }

    final peerIdentity = _resolveIdentity(peerKey);
    if (peerIdentity != null &&
        await _sendViaMesh(peerIdentity, frame) != null) {
      return;
    }

    final deviceId = _resolveDevice(peerKey, peerIdentity) ?? fallbackDeviceId;
    if (deviceId == null) {
      AppLogger.info('MessageTransport: no route for a ${kind.name} receipt');
      return;
    }

    await sendInPackets(
      frame,
      type: PacketType.message,
      packetId: _nextPacketId(),
      send: (bytes) => _bleService.sendReliable(deviceId, bytes),
    );
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
    bool isEncrypted = false,
  }) async {
    final conversation = await _conversationForPeer(
      peerKey: peerKey,
      fallbackDeviceId: fallbackDeviceId,
    );

    final convId = conversation.id;
    final msgId = await _database.insertReceivedMessage(
      conversationId: convId,
      content: decoded.content,
      externalMessageId: decoded.externalMessageId,
      isEncrypted: isEncrypted,
    );

    if (msgId != null) {
      AppLogger.info(
        'MessageTransport: persisted message $msgId in conversation $convId',
      );
      // A duplicate never gets here, so the sender hears this exactly
      // once per message it managed to land.
      _sendReceipt(
        peerKey: peerKey,
        fallbackDeviceId: fallbackDeviceId,
        kind: ReceiptKind.delivered,
        messageIds: [decoded.externalMessageId],
      );
    } else {
      AppLogger.info(
        'MessageTransport: duplicate message ${decoded.externalMessageId} '
        'ignored',
      );
    }
  }

  /// The conversation for an inbound frame, creating and re-keying
  /// exactly as a message would — segments share the thread, not a
  /// side channel.
  Future<Conversation> _conversationForPeer({
    required String peerKey,
    String? fallbackDeviceId,
  }) async {
    var conversation = await _database.getConversationByPeerDevice(peerKey);

    // A legacy address whose identity we know belongs to the
    // identity's thread: without this, a conversation re-keyed on
    // send would fork a duplicate the moment a direct-link frame
    // arrived from the same device.
    if (conversation == null) {
      final identity = _resolveIdentity(peerKey);
      if (identity != null && identity != peerKey) {
        conversation = await _database.getConversationByPeerDevice(identity);
      }
    }
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

    return conversation!;
  }

  /// A slice of an attachment: persist silently, and complete the
  /// file the moment its parts are all present.
  ///
  /// Slices earn no delivered receipt — one per slice would flood the
  /// channel for a large file, and the link layer already ACKs every
  /// packet. The manifest's receipt is the arrival signal the sender
  /// watches. Completion reads back from the database, so a restart
  /// resumes where the radio left off instead of nursing half a file
  /// in memory.
  Future<void> _handleSegment({
    required String peerKey,
    String? fallbackDeviceId,
    required DecodedMessage decoded,
    required ({
      String id,
      int index,
      int count,
      String name,
      Uint8List bytes
    }) segment,
    required bool isEncrypted,
  }) async {
    final conversation = await _conversationForPeer(
      peerKey: peerKey,
      fallbackDeviceId: fallbackDeviceId,
    );

    await _database.insertReceivedMessage(
      conversationId: conversation.id,
      content: decoded.content,
      externalMessageId: decoded.externalMessageId,
      isEncrypted: isEncrypted,
      silent: true,
    );

    final parts =
        await _database.segmentsFor(conversation.id, segment.id);
    final byIndex = <int, Uint8List>{};
    for (final row in parts) {
      final parsed = SegTag.parse(row.content);
      if (parsed == null ||
          parsed.count != segment.count ||
          parsed.name != segment.name) {
        continue;
      }
      byIndex.putIfAbsent(parsed.index, () => parsed.bytes);
    }
    if (byIndex.length < segment.count) return;

    var total = 0;
    for (var i = 0; i < segment.count; i++) {
      total += byIndex[i]!.length;
    }
    final file = Uint8List(total);
    var offset = 0;
    for (var i = 0; i < segment.count; i++) {
      final slice = byIndex[i]!;
      file.setAll(offset, slice);
      offset += slice.length;
    }

    try {
      final dir = await (_attachmentDirectory ?? _defaultAttachmentDirectory)();
      await File('${dir.path}/${segment.name}')
          .writeAsBytes(file, flush: true);
      AppLogger.info(
        'MessageTransport: attachment ${segment.name} complete '
        '(${file.length} bytes)',
      );
    } catch (e) {
      AppLogger.error('MessageTransport: could not write attachment', e);
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
