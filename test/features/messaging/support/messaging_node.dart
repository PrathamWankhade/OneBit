import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';
import 'package:onebit/features/dtn/domain/dtn_priority.dart';
import 'package:onebit/features/messaging/data/adapters/dtn_transport.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_channel_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_draft_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_message_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_notification_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_receipt_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_search_repository.dart';
import 'package:onebit/features/messaging/data/wire/message_wire_codec.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_type.dart';
import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/features/messaging/domain/messages/message_priority.dart';
import 'package:onebit/features/messaging/domain/messages/message_type.dart';

import 'messaging_support.dart'
    show FakeDtnRepository, openInMemoryDb, silentLogger;

/// Polls until [condition] holds or the deadline passes.
Future<void> pumpUntil(
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!(await condition())) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timeout${reason == null ? '' : ': $reason'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

/// One messaging node: real drift-backed repositories + the real engine
/// over a [FakeDtnRepository] seam.
final class MessagingNode {
  MessagingNode(this.nodeId) : dtn = FakeDtnRepository();

  final String nodeId;
  final FakeDtnRepository dtn;

  late final OneBitDatabase db;
  late final ChannelRepository channels;
  late final MessagingEngine engine;
  late final AppLogger logger;
  final MessageWireCodec codec = const MessageWireCodec();

  /// Builds the whole stack on a fresh in-memory database and starts the
  /// inbound pump.
  Future<void> boot() async {
    logger = silentLogger;
    db = await openInMemoryDb();
    channels = SqliteChannelRepository(
      db: db,
      localNodeId: nodeId,
      logger: logger,
    );
    engine = MessagingEngine(
      localNodeId: nodeId,
      dtn: dtn,
      channels: channels,
      messages: SqliteMessageRepository(db: db, logger: logger),
      drafts: SqliteDraftRepository(db: db, logger: logger),
      receipts: SqliteReceiptRepository(db: db, logger: logger),
      search: SqliteSearchRepository(db: db, logger: logger),
      notifications: SqliteNotificationRepository(db: db, logger: logger),
      logger: logger,
    );
    engine.start();
    dtn.onWaiting = () {}; // pump is listening
  }

  /// Stops the pump, releases the waiter and closes the database.
  Future<void> dispose() async {
    // Release the pending observeDelivered() first, or stop() hangs on it.
    dtn.close();
    await engine.stop();
    await db.close();
  }

  /// Opens or reuses the private channel with [peerId]; returns its id.
  Future<String> openChannel(String peerId) async {
    final result = await channels.create(
      CreateChannelParams(type: ChannelType.private, peer: peerId),
    );
    return result.value!.channelId;
  }

  /// Builds the wire envelope for [message] (outbound direction).
  List<int> encodeOutbound(MessageLike message) => codec.encode(
    WireMessageEnvelope(
      messageId: message.messageId,
      channelId: message.channelId,
      sender: message.sender,
      receiver: message.receiver,
      type: message.type,
      body: message.body,
      sequence: message.sequence,
      timestamp: message.timestamp,
      priority: message.priority,
    ),
  );

  /// Delivers an inbound message payload to the engine.
  void deliverMessagePayload(List<int> payload, {String? packetId}) {
    dtn.deliver(
      DtnPacket(
        packetId: packetId ?? 'in:${payload.length}',
        source: 'peer',
        destination: nodeId,
        payload: payload,
        priority: DtnPriority.normal,
        direction: DtnDirection.inbound,
        ttlSeconds: MessengerEnvelopeDefaults.messageTtlSeconds,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(
          const Duration(seconds: MessengerEnvelopeDefaults.messageTtlSeconds),
        ),
      ),
    );
  }

  /// Delivers a receipt envelope (delivery=false / read=true) inbound.
  void deliverReceipt({
    required String messageId,
    required String node,
    required bool isRead,
    DateTime? at,
  }) {
    final payload = codec.encodeReceipt(
      messageId: messageId,
      node: node,
      at: at ?? DateTime.now(),
      isRead: isRead,
    );
    dtn.deliver(
      DtnPacket(
        packetId: 'receipt:$messageId:${isRead ? 'read' : 'delivery'}',
        source: node,
        destination: nodeId,
        payload: payload,
        priority: DtnPriority.low,
        direction: DtnDirection.inbound,
        ttlSeconds: MessengerEnvelopeDefaults.receiptTtlSeconds,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(
          const Duration(seconds: MessengerEnvelopeDefaults.receiptTtlSeconds),
        ),
      ),
    );
  }

  /// Delivers a typing beacon inbound.
  void deliverTyping({
    required String channelId,
    required String node,
    required String state,
  }) {
    final payload = codec.encodeTyping(
      channelId: channelId,
      node: node,
      state: state,
      ts: DateTime.now(),
    );
    dtn.deliver(
      DtnPacket(
        packetId: 'typing:$node:$channelId',
        source: node,
        destination: nodeId,
        payload: payload,
        priority: DtnPriority.low,
        direction: DtnDirection.inbound,
        ttlSeconds: MessengerEnvelopeDefaults.typingTtlSeconds,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(
          const Duration(seconds: MessengerEnvelopeDefaults.typingTtlSeconds),
        ),
      ),
    );
  }
}

/// Minimal shape of the fields the harness needs from a message.
final class MessageLike {
  const MessageLike({
    required this.messageId,
    required this.channelId,
    required this.timestamp,
    required this.sender,
    this.receiver,
    this.type = MessageType.text,
    this.body = '',
    this.sequence = 1,
    this.priority = MessagePriority.normal,
  });

  final String messageId;
  final String channelId;
  final String sender;
  final String? receiver;
  final MessageType type;
  final String body;
  final int sequence;
  final MessagePriority priority;
  final DateTime timestamp;
}
