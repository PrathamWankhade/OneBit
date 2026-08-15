import 'package:drift/drift.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/tables/enums.dart' as core;
import 'package:onebit/features/messaging/domain/delivery/delivery_receipt.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_metadata.dart';
import 'package:onebit/features/messaging/domain/messages/message_priority.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';
import 'package:onebit/features/messaging/domain/messages/message_type.dart';
import 'package:onebit/features/messaging/domain/receipts/read_receipt.dart';

/// Maps `MessageRow` ↔ [Message] and receipt rows ↔ domain receipts.
///
/// The core schema stores enums as name strings (domain vocabulary minus a
/// few aliases: `attachment`/`voiceNote` wire rows map to domain
/// `media`/`voice`, and legacy `pending`/`sent` states normalize to
/// `queued`/`relayed`).
abstract final class MessageMapper {
  const MessageMapper._();

  // ---- Shared conversion helpers --------------------------------------------

  static core.MessageStatus toCoreStatus(MessageStatus status) =>
      core.MessageStatus.values.firstWhere(
        (s) => s.name == status.name,
        orElse: () => core.MessageStatus.pending,
      );

  static MessageStatus statusFromPersisted(core.MessageStatus status) =>
      MessageStatus.fromWireName(status.name) ?? MessageStatus.queued;

  static core.MessageType toCoreType(MessageType type) =>
      core.MessageType.values.firstWhere(
        (t) => t.name == _domainToCoreTypeName(type),
        orElse: () => core.MessageType.text,
      );

  static MessageType typeFromPersisted(core.MessageType type) =>
      MessageType.fromWireName(type.name) ?? MessageType.text;

  static core.PriorityLevel toCorePriority(MessagePriority priority) =>
      core.PriorityLevel.values.firstWhere(
        (p) => p.name == priority.name,
        orElse: () => core.PriorityLevel.normal,
      );

  static MessagePriority priorityFromPersisted(core.PriorityLevel priority) =>
      MessagePriority.values.firstWhere(
        (p) => p.name == priority.name,
        orElse: () => MessagePriority.normal,
      );

  static String _domainToCoreTypeName(MessageType type) => switch (type) {
    MessageType.media => 'attachment',
    MessageType.voice => 'voiceNote',
    MessageType.system => 'system',
    MessageType.text => 'text',
    MessageType.markdown => 'markdown',
    MessageType.notification => 'notification',
    MessageType.identity => 'identity',
    MessageType.handshake => 'handshake',
    MessageType.receipt => 'receipt',
    MessageType.developer => 'developer',
    MessageType.file => 'file',
  };

  // ---- Row <-> domain -------------------------------------------------------

  static MessageRow toRow(Message message) => MessageRow(
    messageId: message.messageId,
    channelId: message.channelId,
    sender: message.sender,
    receiver: message.receiver,
    timestamp: message.timestamp,
    encryptedPayload: Uint8List.fromList(const [0]),
    messageType: toCoreType(message.type),
    status: toCoreStatus(message.status),
    replyTo: message.replyTo,
    forwarded: message.forwarded,
    edited: message.edited,
    deleted: message.deleted,
    ttl: message.ttl?.inSeconds,
    priority: toCorePriority(message.priority),
    version: message.version,
    sequence: message.sequence,
    clientId: message.metadata.clientId,
    packetId: message.metadata.packetId,
    bodyText: message.body.isEmpty ? null : message.body,
    readAt: message.readAt,
    verified: message.metadata.verifiedAt != null,
    verifiedAt: message.metadata.verifiedAt,
    starred: message.starred,
    packetOrder: message.packetOrder,
    attemptCount: message.metadata.attemptCount,
    lastError: message.metadata.lastError,
  );

  static Message toDomain(MessageRow row) => Message(
    messageId: row.messageId,
    channelId: row.channelId,
    sender: row.sender,
    receiver: row.receiver,
    type: typeFromPersisted(row.messageType),
    status: statusFromPersisted(row.status),
    priority: priorityFromPersisted(row.priority),
    body: row.bodyText ?? '',
    timestamp: row.timestamp,
    sequence: row.sequence,
    packetOrder: row.packetOrder,
    replyTo: row.replyTo,
    forwarded: row.forwarded,
    edited: row.edited,
    deleted: row.deleted,
    starred: row.starred,
    readAt: row.readAt,
    version: row.version,
    ttl: row.ttl == null ? null : Duration(seconds: row.ttl!),
    metadata: MessageMetadata(
      clientId: row.clientId,
      packetId: row.packetId,
      attemptCount: row.attemptCount,
      lastError: row.lastError,
      verifiedAt: row.verifiedAt,
    ),
  );

  static MessagesCompanion toCompanion(Message message) => MessagesCompanion(
    messageId: Value(message.messageId),
    channelId: Value(message.channelId),
    sender: Value(message.sender),
    receiver: Value(message.receiver),
    timestamp: Value(message.timestamp),
    encryptedPayload: Value(Uint8List.fromList(const [0])),
    messageType: Value(toCoreType(message.type)),
    status: Value(toCoreStatus(message.status)),
    replyTo: Value(message.replyTo),
    forwarded: Value(message.forwarded),
    edited: Value(message.edited),
    deleted: Value(message.deleted),
    ttl: Value(message.ttl?.inSeconds),
    priority: Value(toCorePriority(message.priority)),
    version: Value(message.version),
    sequence: Value(message.sequence),
    clientId: Value(message.metadata.clientId),
    packetId: Value(message.metadata.packetId),
    bodyText: Value(message.body.isEmpty ? null : message.body),
    readAt: Value(message.readAt),
    verified: Value(message.metadata.verifiedAt != null),
    verifiedAt: Value(message.metadata.verifiedAt),
    starred: Value(message.starred),
    packetOrder: Value(message.packetOrder),
    attemptCount: Value(message.metadata.attemptCount),
    lastError: Value(message.metadata.lastError),
  );

  // ---- Receipt rows -----------------------------------------------------------

  static DeliveryReceipt deliveryToDomain(DeliveryReceiptRow row) =>
      DeliveryReceipt(
        receiptId: row.receiptId,
        messageId: row.messageId,
        node: row.node,
        deliveredAt: row.deliveredAt,
        state: receiptStateFromPersisted(row.state),
        metadata: row.metadata,
      );

  static ReadReceipt readToDomain(ReadReceiptRow row) => ReadReceipt(
    receiptId: row.receiptId,
    messageId: row.messageId,
    node: row.node,
    device: row.device,
    version: row.version,
    readAt: row.readAt,
  );

  // ---- Delivery receipt states -------------------------------------------------

  static core.ReceiptState toCoreReceiptState(DeliveryReceiptState state) =>
      core.ReceiptState.values.firstWhere(
        (s) => s.name == state.name,
        orElse: () => core.ReceiptState.sent,
      );

  static DeliveryReceiptState receiptStateFromPersisted(
    core.ReceiptState state,
  ) => DeliveryReceiptState.values.firstWhere(
    (s) => s.name == state.name,
    orElse: () => DeliveryReceiptState.sent,
  );
}
