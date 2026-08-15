import 'package:flutter/foundation.dart';

import 'message_metadata.dart';
import 'message_priority.dart';
import 'message_status.dart';
import 'message_type.dart';

/// An immutable message in a channel timeline.
///
/// This is the single domain representation of a conversation entry: it is
/// what senders create, what receivers store, what the ordering engine
/// sorts and what the UI will render. All lifecycle transitions produce a
/// new instance; the data layer persists each transition before the engine
/// returns.
@immutable
final class Message {
  const Message({
    required this.messageId,
    required this.channelId,
    required this.sender,
    required this.timestamp,
    this.receiver,
    this.type = MessageType.text,
    this.status = MessageStatus.created,
    this.priority = MessagePriority.normal,
    this.body = '',
    this.sequence = 0,
    this.packetOrder = 0,
    this.replyTo,
    this.forwarded = false,
    this.edited = false,
    this.deleted = false,
    this.starred = false,
    this.readAt,
    this.version = 1,
    this.ttl,
    this.metadata = const MessageMetadata(),
  });

  /// Globally unique message id (wire-safe).
  final String messageId;

  /// The conversation this message belongs to.
  final String channelId;

  /// Origin node id.
  final String sender;

  /// Destination node id; null for group/broadcast channels.
  final String? receiver;

  /// Content kind (text, markdown, system, ...).
  final MessageType type;

  /// Lifecycle state (persisted on every transition).
  final MessageStatus status;

  /// Delivery priority (mapped to DTN priority on the outbox).
  final MessagePriority priority;

  /// The message content.
  final String body;

  /// Creation instant on the mesh clock.
  final DateTime timestamp;

  /// Per-channel ordering counter assigned by the origin node.
  final int sequence;

  /// First-arrival index at this node (fallback ordering for foreign
  /// envelopes without a sequence, and the stable local tie-break).
  final int packetOrder;

  /// Id of the message this one replies to (or quotes).
  final String? replyTo;

  final bool forwarded;
  final bool edited;
  final bool deleted;
  final bool starred;

  /// When the local user read this message.
  final DateTime? readAt;

  /// Wire schema version of the payload.
  final int version;

  /// Optional message lifetime (beyond which the message expires).
  final Duration? ttl;

  /// Operator metadata (client id, envelope id, retry bookkeeping).
  final MessageMetadata metadata;

  bool get isOutbound => false; // reserved for future device typing

  /// Copy with any subset replaced (status flow helper).
  Message copyWith({
    MessageStatus? status,
    MessagePriority? priority,
    String? body,
    DateTime? timestamp,
    int? sequence,
    int? packetOrder,
    String? replyTo,
    bool? forwarded,
    bool? edited,
    bool? deleted,
    bool? starred,
    DateTime? readAt,
    int? version,
    Duration? ttl,
    MessageMetadata? metadata,
  }) => Message(
    messageId: messageId,
    channelId: channelId,
    sender: sender,
    receiver: receiver,
    type: type,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    body: body ?? this.body,
    timestamp: timestamp ?? this.timestamp,
    sequence: sequence ?? this.sequence,
    packetOrder: packetOrder ?? this.packetOrder,
    replyTo: replyTo ?? this.replyTo,
    forwarded: forwarded ?? this.forwarded,
    edited: edited ?? this.edited,
    deleted: deleted ?? this.deleted,
    starred: starred ?? this.starred,
    readAt: readAt ?? this.readAt,
    version: version ?? this.version,
    ttl: ttl ?? this.ttl,
    metadata: metadata ?? this.metadata,
  );

  @override
  bool operator ==(Object other) =>
      other is Message && other.messageId == messageId;

  @override
  int get hashCode => messageId.hashCode;

  @override
  String toString() =>
      'Message($messageId [$type/$status] '
      '"${body.length > 24 ? '${body.substring(0, 24)}…' : body}")';
}
