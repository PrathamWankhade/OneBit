import 'dart:async';
import 'dart:convert';

import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';
import 'package:onebit/features/dtn/domain/dtn_failure.dart';
import 'package:onebit/features/dtn/domain/dtn_priority.dart';
import 'package:onebit/features/dtn/domain/dtn_repository.dart';
import 'package:onebit/features/messaging/data/adapters/dtn_transport.dart';
import 'package:onebit/features/messaging/data/id/message_id_generator.dart';
import 'package:onebit/features/messaging/data/wire/message_wire_codec.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart';
import 'package:onebit/features/messaging/domain/channels/conversation_summary.dart';
import 'package:onebit/features/messaging/domain/channels/pinned_message.dart';
import 'package:onebit/features/messaging/domain/delivery/delivery_receipt.dart';
import 'package:onebit/features/messaging/domain/drafts/draft.dart';
import 'package:onebit/features/messaging/domain/drafts/draft_repository.dart';
import 'package:onebit/features/messaging/domain/engine/composer_service.dart';
import 'package:onebit/features/messaging/domain/engine/inbound_pump.dart';
import 'package:onebit/features/messaging/domain/engine/notification_engine.dart';
import 'package:onebit/features/messaging/domain/engine/outbox.dart';
import 'package:onebit/features/messaging/domain/engine/search_indexer.dart';
import 'package:onebit/features/messaging/domain/engine/typing_engine.dart';
import 'package:onebit/features/messaging/domain/engine/unread_tracker.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_metadata.dart';
import 'package:onebit/features/messaging/domain/messages/message_ordering.dart';
import 'package:onebit/features/messaging/domain/messages/message_priority.dart';
import 'package:onebit/features/messaging/domain/messages/message_repository.dart';
import 'package:onebit/features/messaging/domain/messages/message_search_result.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';
import 'package:onebit/features/messaging/domain/messages/message_type.dart';
import 'package:onebit/features/messaging/domain/messages/typing_state.dart';
import 'package:onebit/features/messaging/domain/notifications/notification.dart';
import 'package:onebit/features/messaging/domain/notifications/notification_repository.dart';
import 'package:onebit/features/messaging/domain/receipts/read_receipt.dart';
import 'package:onebit/features/messaging/domain/receipts/receipt_repository.dart';
import 'package:onebit/features/messaging/domain/search/search_repository.dart';

/// The messaging façade: composes sends, drains the inbound seam, applies
/// receipts, tracks typing and keeps search + notifications in sync.
///
/// This is the object the app layer holds for the messaging feature. All
/// public operations are `Result`-typed — nothing throws across this
/// boundary. The engine never touches Bluetooth / mesh / packet APIs: the
/// DTN repository is its only seam to the network.
final class MessagingEngine {
  MessagingEngine({
    required this.localNodeId,
    required this.dtn,
    required this.channels,
    required this.messages,
    required this.drafts,
    required this.receipts,
    required this.search,
    required this.notifications,
    required this.logger,
    this.codec = const MessageWireCodec(),
    this.progressInterval = const Duration(seconds: 30),
    this.retention = const Duration(days: 30),
  });

  /// This node's stable id, stamped on every outbound message.
  final String localNodeId;

  final DTNRepository dtn;
  final ChannelRepository channels;
  final MessageRepository messages;
  final DraftRepository drafts;
  final ReceiptRepository receipts;
  final SearchRepository search;
  final NotificationRepository notifications;
  final MessageWireCodec codec;
  final AppLogger logger;

  /// How often the engine probes in-flight envelopes and sweeps expiry.
  final Duration progressInterval;

  /// How old a soft-deleted tombstone must be before it is purged.
  final Duration retention;

  static const _tag = LogTags.messaging;

  late final ComposerService _composer = ComposerService(
    localNodeId: localNodeId,
    channels: channels,
    messages: messages,
    logger: logger,
  );

  late final Outbox _outbox = Outbox(
    localNodeId: localNodeId,
    dtn: dtn,
    messages: messages,
    notifications: notifications,
    logger: logger,
  );

  late final UnreadTracker _unread = UnreadTracker(
    channels: channels,
    logger: logger,
  );

  late final NotificationEngine _notifier = NotificationEngine(
    repository: notifications,
    logger: logger,
  );

  late final SearchIndexer _indexer = SearchIndexer(
    repository: search,
    logger: logger,
  );

  /// Observable typing presence (UI contract). Wired to diagnostics from
  /// birth; [stop] disposes it and [start] rebuilds it via [_ensureTyping].
  late TypingEngine typing = TypingEngine(
    onDiagnostics: _recordTypingDiagnostics,
  );

  late final InboundPump _pump = InboundPump(dtn: dtn, logger: logger);

  bool _started = false;
  Timer? _progressTimer;

  /// Starts the inbound drain, reconciles the outbox and sweeps expiry.
  /// Idempotent; safe to call again after [stop].
  void start() {
    if (_started) return;
    _ensureTyping();
    _started = true;
    _pump.start(_onEnvelope);
    unawaited(_startupReconcile());
    _progressTimer = Timer.periodic(
      progressInterval,
      (_) => unawaited(_sweep()),
    );
    logger.debug('messaging engine started', tag: _tag);
  }

  /// Stops the inbound drain (tests and app teardown).
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _progressTimer?.cancel();
    _progressTimer = null;
    await _pump.stop();
    typing.dispose();
  }

  void _ensureTyping() {
    if (typing.isDisposed) {
      typing = TypingEngine(onDiagnostics: _recordTypingDiagnostics);
    }
  }

  // ---------------------------------------------------------------------
  // Sending
  // ---------------------------------------------------------------------

  /// Sends a text message. Returns the persisted message in `queued` /
  /// `waiting` state.
  Future<Result<Message>> sendText(String channelId, String body) =>
      _composeAndEnqueue(channelId: channelId, body: body);

  /// Sends any composable message kind. Passing [clientId] makes the whole
  /// send idempotent (the id becomes the message id).
  Future<Result<Message>> send(
    String channelId,
    String body, {
    MessageType type = MessageType.text,
    MessagePriority priority = MessagePriority.normal,
    String? replyTo,
    bool forwarded = false,
    String? clientId,
    Duration? ttl,
  }) => _composeAndEnqueue(
    channelId: channelId,
    body: body,
    type: type,
    priority: priority,
    replyTo: replyTo,
    forwarded: forwarded,
    clientId: clientId,
    ttl: ttl,
  );

  /// Replies to [replyTo] inside [channelId].
  Future<Result<Message>> reply(
    String channelId,
    String body,
    String replyTo,
  ) => send(channelId, body, replyTo: replyTo);

  /// Re-queues a `failed` message.
  Future<Result<Message>> retry(String messageId) async {
    final found = await messages.getMessage(messageId);
    if (found.failure != null) return Err(found.failure!);
    final message = found.value;
    if (message == null) {
      return Err(
        MessageNotFoundFailure(packetId: messageId, message: 'no such message'),
      );
    }
    if (message.status == MessageStatus.queued ||
        message.status == MessageStatus.failed) {
      return _outbox.enqueue(message);
    }
    if (message.status == MessageStatus.waiting ||
        message.status == MessageStatus.routing ||
        message.status == MessageStatus.relayed) {
      return Ok(message);
    }
    return Err(
      MessageTransitionFailure(
        from: message.status.name,
        to: 'queued',
        message: 'only queued/failed messages can be retried',
      ),
    );
  }

  /// Cancels an undelivered message.
  Future<Result<void>> cancel(String messageId) async {
    final found = await messages.getMessage(messageId);
    if (found.failure != null) return Err(found.failure!);
    final message = found.value;
    if (message == null) {
      return Err(
        MessageNotFoundFailure(packetId: messageId, message: 'no such message'),
      );
    }
    return _outbox.cancel(message);
  }

  /// Edits a message body. Optionally re-broadcasts the update over the
  /// wire so peers see the edit.
  Future<Result<Message>> edit(
    String messageId,
    String body, {
    bool rebroadcast = true,
  }) async {
    final found = await messages.getMessage(messageId);
    if (found.failure != null) return Err(found.failure!);
    final message = found.value;
    if (message == null) {
      return Err(
        MessageNotFoundFailure(packetId: messageId, message: 'no such message'),
      );
    }
    final updated = message.copyWith(
      body: body,
      edited: true,
      version: message.version + 1,
    );
    final stored = await messages.update(updated);
    if (stored is Ok<Message>) {
      final current = stored.value!;
      await _indexer.indexMessage(current);
      if (rebroadcast &&
          current.status != MessageStatus.failed &&
          current.status != MessageStatus.deleted) {
        return _outbox.resend(current);
      }
    }
    return stored;
  }

  /// Forwards [messageId] into [channelId] as a forwarded message.
  Future<Result<Message>> forward(String messageId, String toChannelId) async {
    final found = await messages.getMessage(messageId);
    if (found.failure != null) return Err(found.failure!);
    final message = found.value;
    if (message == null) {
      return Err(
        MessageNotFoundFailure(packetId: messageId, message: 'no such message'),
      );
    }
    return send(toChannelId, message.body, forwarded: true);
  }

  /// Soft-deletes a message locally and evicts it from search. If a draft
  /// is mid-edit of that message, the draft is cleared too.
  Future<Result<void>> delete(String messageId) async {
    await messages.delete(messageId);
    await _indexer.remove(messageId);
    final allDrafts = (await drafts.listAll()).value ?? const <Draft>[];
    final editing = allDrafts
        .where((d) => d.editingMessageId == messageId)
        .map((d) => d.channelId)
        .toList();
    for (final channelId in editing) {
      await drafts.delete(channelId);
    }
    return const Ok(null);
  }

  /// Stars / un-stars a message.
  Future<Result<Message?>> star(
    String messageId, {
    required bool starred,
  }) async {
    final result = await messages.star(messageId, starred: starred);
    if (result is Err<void>) return Err(result.failure!);
    return messages.getMessage(messageId);
  }

  /// Pins a message to its channel heading.
  Future<Result<void>> pinMessage(String channelId, String messageId) async {
    final channel = (await channels.getChannel(channelId)).value;
    if (channel == null) {
      return Err(
        MessageValidationFailure(
          reason: 'unknownChannel',
          message: 'no channel $channelId',
        ),
      );
    }
    final found = (await messages.getMessage(messageId)).value;
    if (found == null || found.channelId != channelId) {
      return Err(
        MessageValidationFailure(
          reason: 'unknownMessage',
          message: 'no message $messageId in $channelId',
        ),
      );
    }
    return channels.pinMessage(channelId, messageId);
  }

  /// Removes a pinned message.
  Future<Result<void>> unpinMessage(String channelId, String messageId) =>
      channels.unpinMessage(channelId, messageId);

  Future<Result<List<PinnedMessage>>> pinnedMessages(String channelId) =>
      channels.pinnedMessages(channelId);

  Future<Result<Message>> _composeAndEnqueue({
    required String channelId,
    required String body,
    MessageType type = MessageType.text,
    MessagePriority priority = MessagePriority.normal,
    String? replyTo,
    bool forwarded = false,
    String? clientId,
    Duration? ttl,
  }) async {
    final composed = await _composer.prepareSend(
      channelId: channelId,
      body: body,
      type: type,
      priority: priority,
      replyTo: replyTo,
      forwarded: forwarded,
      clientId: clientId,
      ttl: ttl,
    );
    if (composed.failure != null) return composed;
    final message = composed.value!;
    await _indexer.indexMessage(message);
    final stored = await _outbox.enqueue(message);
    if (stored is Ok<Message>) {
      await _unread.onOutbound(stored.value!);
      // The send consumed the draft (docs: "deleted when the message is
      // sent").
      await clearDraft(channelId);
    }
    return stored;
  }

  // ---------------------------------------------------------------------
  // Drafts
  // ---------------------------------------------------------------------

  /// Upserts the draft of [channelId]. [editingMessageId] makes the draft
  /// target an in-place edit. Drafts are validated against the same budget
  /// as a real send so a half-typed draft never outgrows the wire.
  Future<Result<void>> saveDraft(
    String channelId,
    String body, {
    String? editingMessageId,
  }) async {
    if (body.length > MessageWireCodec.maxPayloadBytes - 8 * 1024) {
      return const Err(
        MessageValidationFailure(
          reason: 'tooLong',
          message: 'draft body exceeds the wire payload budget',
        ),
      );
    }
    final now = DateTime.now();
    final existing = (await drafts.load(channelId)).value;
    return drafts.save(
      Draft(
        channelId: channelId,
        body: body,
        editingMessageId: editingMessageId,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  Future<Result<Draft?>> loadDraft(String channelId) => drafts.load(channelId);

  Future<Result<void>> clearDraft(String channelId) => drafts.delete(channelId);

  Stream<Result<Draft?>> watchDraft(String channelId) =>
      drafts.watch(channelId);

  // ---------------------------------------------------------------------
  // Read tracking (batched read receipts)
  // ---------------------------------------------------------------------

  /// Marks the channel read through the newest message and emits ONE
  /// read-cursor envelope back to the peer (a 500-message thread never
  /// produces 500 packets). Returns the number of messages marked read.
  Future<Result<int>> markChannelRead(String channelId) async {
    var marked = 0;
    final newest = await messages.pageChannel(channelId, limit: 1);
    if (newest.failure != null) return Err(newest.failure!);
    final page = newest.value;
    if (page != null && page.items.isNotEmpty) {
      final last = page.items.last;
      final result = await messages.markReadThrough(
        channelId,
        MessageOrderKey.of(last),
      );
      if (result is Err<int>) return Err(result.failure!);
      marked = result.value ?? 0;
      await _emitReadCursor(channelId, MessageOrderKey.of(last));
    }
    await _unread.markChannelRead(channelId);
    return Ok(marked);
  }

  /// One cursor envelope per mark-read batch: the peer applies it to every
  /// message read through the cursor key.
  Future<void> _emitReadCursor(
    String channelId,
    MessageOrderKey through,
  ) async {
    final channelResult = await channels.getChannel(channelId);
    final peer = channelResult.value?.peer;
    if (peer == null) return;
    final now = DateTime.now();
    final payload = codec.encodeReadCursor(
      channelId: channelId,
      node: localNodeId,
      throughMessageId: through.messageId,
      throughSequence: through.sequence,
      throughTimestamp: through.timestamp,
      at: now,
    );
    await _fireAndSend(
      MessengerEnvelopeDefaults.receiptPacket(
        packetId: MessengerEnvelopeDefaults.packetId(localNodeId, now),
        source: localNodeId,
        destination: peer,
        payload: payload,
        now: now,
      ),
      'read cursor $channelId',
    );
  }

  // ---------------------------------------------------------------------
  // Typing beacons
  // ---------------------------------------------------------------------

  /// Broadcasts a typing beacon, throttled to one envelope per channel per
  /// [TypingEngine.minBeaconInterval]. Fire-and-forget.
  Future<Result<void>> typingBeacon(String channelId, {required bool started}) {
    _ensureTyping();
    final changed = started
        ? typing.startTyping(channelId, localNodeId)
        : (() {
            typing.stopTyping(channelId, localNodeId);
            return true;
          })();
    if (started && !changed) {
      // Bus already says "typing"; only a throttled beacon could be sent.
      if (!typing.shouldSendBeacon(channelId, started: true)) {
        return Future.value(const Ok<void>(null));
      }
    }
    final state = started ? 'started' : 'stopped';
    return _fireAndSend(
      MessengerEnvelopeDefaults.receiptPacket(
        packetId: MessengerEnvelopeDefaults.packetId(
          localNodeId,
          DateTime.now(),
        ),
        source: localNodeId,
        destination: channelId,
        payload: codec.encodeTyping(
          channelId: channelId,
          node: localNodeId,
          state: state,
          ts: DateTime.now(),
        ),
        now: DateTime.now(),
      ),
      'typing beacon $channelId',
    ).then((result) {
      if (result.isOk) typing.markBeaconSent(channelId);
      return result;
    });
  }

  // ---------------------------------------------------------------------
  // Inbound
  // ---------------------------------------------------------------------

  /// Decodes and dispatches one inbound payload (the ReceiveMessage use
  /// case surface; also the pump's handler).
  Future<Result<ReceiveResult>> handleInboundPayload(
    List<int> payload, {
    String? packetId,
    String? source,
  }) async {
    final decoded = codec.decode(payload);
    switch (decoded) {
      case Ok(:final value) when value != null:
        final packet = DtnPacket(
          packetId: packetId ?? 'in:${payload.length}',
          source: source ?? '',
          destination: localNodeId,
          payload: payload,
          priority: DtnPriority.normal,
          direction: DtnDirection.inbound,
          ttlSeconds: MessengerEnvelopeDefaults.messageTtlSeconds,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(
            const Duration(
              seconds: MessengerEnvelopeDefaults.messageTtlSeconds,
            ),
          ),
        );
        return _dispatch(value, packet);
      case Err(:final failure):
        logger.warning('inbound decode failed: $failure', tag: _tag);
        return Err(failure ?? const UnexpectedFailure());
      case Ok():
        return const Err(
          SerializationFailure(
            source: 'wireCodec',
            message: 'empty inbound payload',
          ),
        );
    }
  }

  Future<void> _onEnvelope(DtnPacket packet) async {
    final decoded = codec.decode(packet.payload);
    switch (decoded) {
      case Ok(:final value) when value != null:
        await _dispatch(value, packet);
      case Err(:final failure):
        logger.warning('inbound decode failed: $failure', tag: _tag);
      case Ok():
        break;
    }
  }

  Future<Result<ReceiveResult>> _dispatch(
    WireEnvelope envelope,
    DtnPacket packet,
  ) async {
    switch (envelope) {
      case WireMessageResult():
        return _handleInboundMessage(envelope.payload, packet);
      case WireReceiptEnvelope():
        await _applyReceipt(envelope);
        return const Ok(ReceiveResult(message: null, duplicate: false));
      case WireTypingEnvelope():
        _ensureTyping();
        if (envelope.state == 'started') {
          typing.startTyping(envelope.channelId, envelope.node);
        } else {
          typing.stopTyping(envelope.channelId, envelope.node);
        }
        _recordTypingDiagnostics(
          channelId: envelope.channelId,
          node: envelope.node,
          phase: envelope.state == 'started'
              ? TypingPhase.started
              : TypingPhase.stopped,
        );
        return const Ok(ReceiveResult(message: null, duplicate: false));
      case WireUnknownEnvelope():
        logger.debug('unknown envelope dropped: ${envelope.reason}', tag: _tag);
        return const Ok(ReceiveResult(message: null, duplicate: false));
    }
  }

  /// Stores a foreign message: idempotent store + unread + search index +
  /// notification + delivery receipt back to the sender.
  Future<Result<ReceiveResult>> _handleInboundMessage(
    WireMessageEnvelope m,
    DtnPacket packet,
  ) async {
    if (m.sender == localNodeId) {
      logger.trace('echo of own ${m.messageId} dropped', tag: _tag);
      return const Ok(ReceiveResult(message: null, duplicate: true));
    }
    final existing = (await messages.getMessage(m.messageId)).value;
    if (existing != null) {
      logger.trace('duplicate ${m.messageId} dropped', tag: _tag);
      return Ok(ReceiveResult(message: existing, duplicate: true));
    }

    final now = DateTime.now();
    final message = Message(
      messageId: m.messageId,
      channelId: m.channelId,
      sender: m.sender,
      receiver: m.receiver,
      type: m.type,
      status: MessageStatus.queued,
      priority: m.priority,
      body: m.body,
      timestamp: m.timestamp,
      sequence: m.sequence,
      packetOrder: now.microsecondsSinceEpoch,
      replyTo: m.replyTo,
      forwarded: m.forwarded,
      edited: m.edited,
      version: m.version,
      ttl: m.ttlSeconds == null ? null : Duration(seconds: m.ttlSeconds!),
      metadata: MessageMetadata(
        packetId: packet.packetId,
        payloadJson: utf8.decode(packet.payload, allowMalformed: true),
      ),
    );

    final stored = await messages.insert(message);
    final inserted = stored.value;
    if (inserted == null) {
      logger.warning('inbound store failed: ${stored.failure}', tag: _tag);
      return Err(stored.failure ?? const UnexpectedFailure());
    }

    await _indexer.indexMessage(inserted);
    await _unread.onInbound(inserted);
    await _notifyInbound(inserted);
    if (m.receiver == localNodeId) {
      await _generateDeliveryReceipt(m.sender, m.messageId);
    }
    return Ok(ReceiveResult(message: inserted, duplicate: false));
  }

  Future<void> _notifyInbound(Message message) async {
    final channelResult = await channels.getChannel(message.channelId);
    final channel = channelResult.value;
    if (channel?.settings.isEffectivelyMuted ?? false) return;
    await _notifier.emit(
      NotificationEvent(
        kind: NotificationKind.messageReceived,
        channelId: message.channelId,
        messageId: message.messageId,
        node: message.sender,
        title: message.sender,
        body: message.body,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Generates a delivery receipt row (queued → sent) and envelopes it back
  /// to the sender. The row lets the receiver track the receipt lifecycle.
  Future<void> _generateDeliveryReceipt(String toNode, String messageId) async {
    final receipt = DeliveryReceipt(
      receiptId: MessageIdGenerator.deliveryReceiptId(messageId, localNodeId),
      messageId: messageId,
      node: localNodeId,
      deliveredAt: DateTime.now(),
      state: DeliveryReceiptState.queued,
    );
    await receipts.saveDelivery(receipt);
    final result = await _fireAndSend(
      MessengerEnvelopeDefaults.receiptPacket(
        packetId: MessengerEnvelopeDefaults.packetId(
          localNodeId,
          DateTime.now(),
        ),
        source: localNodeId,
        destination: toNode,
        payload: codec.encodeReceipt(
          messageId: messageId,
          node: localNodeId,
          at: DateTime.now(),
          isRead: false,
        ),
        now: DateTime.now(),
      ),
      'delivery receipt $messageId',
    );
    await receipts.setDeliveryState(
      receipt.receiptId,
      state: result.isOk
          ? DeliveryReceiptState.sent
          : DeliveryReceiptState.failed,
    );
  }

  /// Public receipt-generation surface (GenerateReceipt use case):
  /// mints the delivery receipt for [messageId] to its sender — used when
  /// the automatic inbound path could not persist it, or after a crash
  /// recovery.
  Future<Result<GenerateReceiptResult>> generateReceipt(
    String messageId,
  ) async {
    final found = await messages.getMessage(messageId);
    if (found.failure != null) return Err(found.failure!);
    final message = found.value;
    if (message == null) {
      return Err(
        MessageNotFoundFailure(packetId: messageId, message: 'no such message'),
      );
    }
    final sender = message.sender;
    if (sender.isEmpty || sender == localNodeId) {
      return const Err(
        MessageValidationFailure(
          reason: 'noSender',
          message: 'cannot acknowledge a message without a foreign sender',
        ),
      );
    }
    await _generateDeliveryReceipt(sender, messageId);
    return Ok(
      GenerateReceiptResult(
        messageId: messageId,
        node: localNodeId,
        state: DeliveryReceiptState.sent,
      ),
    );
  }

  /// Applies an inbound receipt (delivery, read, or batched read cursor) to
  /// local messages.
  Future<void> _applyReceipt(WireReceiptEnvelope receipt) async {
    if (receipt.isCursor) {
      await _applyReadCursor(receipt);
      return;
    }
    final found = await messages.getMessage(receipt.messageId);
    final message = found.value;
    if (message == null) {
      logger.trace(
        'receipt for unknown ${receipt.messageId} dropped',
        tag: _tag,
      );
      return;
    }
    if (receipt.isRead) {
      await messages.setStatus(receipt.messageId, MessageStatus.read);
      await receipts.saveRead(
        ReadReceipt(
          receiptId: MessageIdGenerator.readReceiptId(
            receipt.messageId,
            receipt.node,
            receipt.device,
          ),
          messageId: receipt.messageId,
          node: receipt.node,
          device: receipt.device,
          readAt: receipt.at,
        ),
      );
      await _notifier.emit(
        NotificationEvent(
          kind: NotificationKind.messageRead,
          channelId: message.channelId,
          messageId: message.messageId,
          node: receipt.node,
          createdAt: DateTime.now(),
        ),
      );
    } else {
      await messages.setStatus(receipt.messageId, MessageStatus.delivered);
      final stored = await receipts.saveDelivery(
        DeliveryReceipt(
          receiptId: MessageIdGenerator.deliveryReceiptId(
            receipt.messageId,
            receipt.node,
          ),
          messageId: receipt.messageId,
          node: receipt.node,
          deliveredAt: receipt.at,
          state: DeliveryReceiptState.delivered,
        ),
      );
      final state = stored.value?.state ?? DeliveryReceiptState.delivered;
      if (state == DeliveryReceiptState.duplicate) {
        logger.trace(
          'duplicate delivery receipt for ${receipt.messageId}',
          tag: _tag,
        );
      }
      await _notifier.emit(
        NotificationEvent(
          kind: NotificationKind.messageDelivered,
          channelId: message.channelId,
          messageId: message.messageId,
          node: receipt.node,
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  /// Applies a batched read cursor: every local outbound message read
  /// through the cursor is marked read and gets a receipt row — one wire
  /// envelope covered the whole thread.
  Future<void> _applyReadCursor(WireReceiptEnvelope receipt) async {
    final key = MessageOrderKey(
      timestamp: receipt.cursorTimestamp ?? receipt.at,
      sequence: receipt.cursorSequence ?? 0,
      packetOrder: 0,
      messageId: receipt.cursorMessageId ?? receipt.messageId,
    );
    final applied = await receipts.applyReadCursor(
      channelId: receipt.channelId!,
      readerNode: receipt.node,
      through: key,
      readAt: receipt.at,
      device: receipt.device,
      version: receipt.version,
    );
    await _notifier.emit(
      NotificationEvent(
        kind: NotificationKind.messageRead,
        channelId: receipt.channelId,
        node: receipt.node,
        body: '${applied.value ?? 0} messages read',
        payload: {'count': applied.value ?? 0, 'through': key.messageId},
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<Result<void>> _fireAndSend(DtnPacket packet, String what) async {
    try {
      await dtn.store(packet);
      return const Ok(null);
    } on DtnFailure catch (failure) {
      logger.warning('$what failed: $failure', tag: _tag);
      return Err(UnexpectedFailure(message: what, cause: failure));
    }
  }

  // ---------------------------------------------------------------------
  // Pipeline maintenance (startup + periodic)
  // ---------------------------------------------------------------------

  /// Startup: re-store envelopes that never made it (crash recovery) and
  /// sweep expired messages / tombstones.
  Future<void> _startupReconcile() async {
    final pending = (await messages.outboxPending(localNodeId)).value ?? [];
    for (final message in pending) {
      final result = await _outbox.enqueue(message);
      if (result is Err<Message>) {
        logger.warning(
          'reconcile: ${message.messageId} could not be stored: '
          '${result.failure}',
          tag: _tag,
        );
      }
    }
    await _sweep();
  }

  /// Periodic maintenance: probe in-flight envelopes (routing/relayed/
  /// expired), expire overdue TTL messages, purge old tombstones.
  Future<void> _sweep() async {
    final now = DateTime.now();
    final expired = (await messages.expireOverdue(now)).value ?? [];
    for (final message in expired) {
      await _indexer.remove(message.messageId);
      await _notifier.emit(
        NotificationEvent(
          kind: NotificationKind.messageExpired,
          channelId: message.channelId,
          messageId: message.messageId,
          node: message.receiver,
          level: NotificationLevel.warning,
          createdAt: now,
        ),
      );
    }
    await messages.purgeDeleted(now.subtract(retention), limit: 500);
    final live =
        (await messages.liveOutbound(localNodeId, limit: 200)).value ??
        const <Message>[];
    for (final message in live) {
      await advanceMessage(message.messageId);
    }
  }

  /// Probes one in-flight message against the DTN layer and advances its
  /// status: `waiting → routing → relayed` from envelope state, `expired` /
  /// `failed` from terminal envelope states, and `verified` once the DTN
  /// ack chain closed AND a delivery receipt is on file.
  Future<Result<Message?>> advanceMessage(String messageId) async {
    final found = await messages.getMessage(messageId);
    if (found.failure != null) return Err(found.failure!);
    final message = found.value;
    if (message == null) return const Ok(null);

    final status = message.status;
    if (status != MessageStatus.waiting &&
        status != MessageStatus.routing &&
        status != MessageStatus.relayed) {
      return Ok(message);
    }
    final packetId = message.metadata.packetId;
    if (packetId == null) return Ok(message);

    DtnPacket? envelope;
    try {
      envelope = await dtn.statusOf(packetId);
    } on DtnFailure catch (failure) {
      logger.warning('advance($messageId) probe failed: $failure', tag: _tag);
      return Ok(message);
    }

    if (envelope == null) {
      logger.trace('advance($messageId): envelope $packetId gone', tag: _tag);
      final failed = await messages.update(
        message.copyWith(
          status: MessageStatus.failed,
          metadata: message.metadata.copyWith(
            lastError: 'envelope vanished from DTN',
            attemptCount: message.metadata.attemptCount + 1,
          ),
        ),
      );
      return failed;
    }

    switch (envelope.state) {
      case DtnPacketState.queued || DtnPacketState.pendingDelivery:
        return messages.setStatus(messageId, MessageStatus.routing);
      case DtnPacketState.relaying ||
          DtnPacketState.retrying ||
          DtnPacketState.awaitingAck ||
          // Paused, but not lost: the envelope resumes when the network
          // returns, so the message stays in flight rather than failing.
          DtnPacketState.deferred:
        return messages.setStatus(messageId, MessageStatus.relayed);
      case DtnPacketState.expired:
        return messages.setStatus(messageId, MessageStatus.expired);
      case DtnPacketState.failed:
        final failed = await messages.update(
          message.copyWith(
            status: MessageStatus.failed,
            metadata: message.metadata.copyWith(lastError: envelope.lastError),
          ),
        );
        return failed;
      case DtnPacketState.delivered ||
          DtnPacketState.deliveredLocally ||
          DtnPacketState.consumed:
        if (status == MessageStatus.delivered) {
          // DTN ack + delivery receipt = verified receipt chain.
          final confirmed = message.receiver == null
              ? null
              : (await receipts.deliveryFor(
                  messageId,
                  message.receiver!,
                )).value;
          if (confirmed != null && message.metadata.verifiedAt == null) {
            final updated = await messages.update(
              message.copyWith(
                status: MessageStatus.verified,
                metadata: message.metadata.copyWith(verifiedAt: DateTime.now()),
              ),
            );
            return updated;
          }
        }
        return Ok(message);
    }
  }

  // ---------------------------------------------------------------------
  // Diagnostics + developer events
  // ---------------------------------------------------------------------

  void _recordTypingDiagnostics({
    required String channelId,
    required String node,
    required TypingPhase phase,
    DateTime? since,
  }) {
    unawaited(
      channels.recordTypingEvent(
        channelId: channelId,
        node: node,
        kind: switch (phase) {
          TypingPhase.started => TypingDiagnosticsKind.started,
          TypingPhase.stopped || TypingPhase.idle => TypingDiagnosticsKind.idle,
          TypingPhase.timeout => TypingDiagnosticsKind.timeout,
        },
        startedAt: since ?? DateTime.now(),
        endedAt: phase == TypingPhase.stopped ? DateTime.now() : null,
      ),
    );
  }

  /// Emits a developer diagnostic event into the internal log.
  Future<Result<NotificationEvent>> emitDeveloper(
    String message, {
    NotificationLevel level = NotificationLevel.info,
    Map<String, Object?> payload = const {},
  }) => _notifier.emit(
    NotificationEvent(
      kind: NotificationKind.developer,
      level: level,
      body: message,
      payload: payload,
      createdAt: DateTime.now(),
    ),
  );

  /// Emits a generic system event into the internal log.
  Future<Result<NotificationEvent>> emitSystem(
    String message, {
    NotificationLevel level = NotificationLevel.info,
    Map<String, Object?> payload = const {},
  }) => _notifier.emit(
    NotificationEvent(
      kind: NotificationKind.system,
      level: level,
      body: message,
      payload: payload,
      createdAt: DateTime.now(),
    ),
  );

  // ---------------------------------------------------------------------
  // Read accessors (UI-facing contracts)
  // ---------------------------------------------------------------------

  Stream<Result<List<Message>>> watchChannel(
    String channelId, {
    int limit = 150,
  }) => messages.watchChannel(channelId, limit: limit);

  Future<Result<MessagePage>> pageChannel(
    String channelId, {
    TimelineCursor? cursor,
    int limit = 50,
  }) => messages.pageChannel(channelId, cursor: cursor, limit: limit);

  Stream<Result<List<ConversationSummary>>> watchSummaries({
    bool includeArchived = false,
  }) => channels.watchSummaries(includeArchived: includeArchived);

  Future<Result<List<ConversationSummary>>> searchChannels(
    String terms, {
    int limit = 25,
  }) => search.searchChannels(terms, limit: limit);

  Future<Result<List<ConversationSummary>>> searchChannelsByNodeName(
    String terms, {
    int limit = 25,
  }) => search.searchChannelsByNodeName(terms, limit: limit);

  Stream<Result<NotificationEvent>> watchNotifications() =>
      notifications.watch();

  Future<Result<SearchPage<MessageSearchResult>>> searchMessages(
    MessageSearchQuery query, {
    int offset = 0,
    int limit = 50,
  }) => search.searchMessages(query, offset: offset, limit: limit);

  Future<Result<int>> rebuildSearchIndex() => _indexer.rebuild();
}

/// Typed outcome of the inbound receive path.
final class ReceiveResult {
  const ReceiveResult({required this.message, required this.duplicate});

  /// The stored message, or null for non-message envelopes / duplicates of
  /// the local node's own messages.
  final Message? message;

  /// True when the envelope was a duplicate (or an echo of a local send).
  final bool duplicate;
}

/// Typed outcome of [MessagingEngine.generateReceipt].
final class GenerateReceiptResult {
  const GenerateReceiptResult({
    required this.messageId,
    required this.node,
    required this.state,
  });

  final String messageId;

  /// This node, the acknowledged party.
  final String node;

  final DeliveryReceiptState state;
}
