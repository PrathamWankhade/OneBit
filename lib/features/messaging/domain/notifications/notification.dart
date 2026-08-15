import 'package:flutter/foundation.dart';

/// Kinds of internal notifications the engine emits.
enum NotificationKind {
  /// An inbound message was stored.
  messageReceived,

  /// An outbound message entered the DTN outbox.
  messageEnqueued,

  /// An outbound message was confirmed delivered.
  messageDelivered,

  /// An outbound message was confirmed read.
  messageRead,

  /// An outbound message failed permanently.
  messageFailed,

  /// An outbound message expired before confirmation.
  messageExpired,

  /// A mention was detected in an inbound message (future group phase).
  mention,

  /// Developer diagnostics event.
  developer,

  /// Generic system event.
  system;

  String get wireName => name;
}

/// Severity level of a notification.
enum NotificationLevel { info, warning, error }

/// An internal notification produced by the notification engine.
///
/// This is a domain event — it does **not** render Android notifications;
/// it is the source of truth the UI layer will consume later.
@immutable
final class NotificationEvent {
  const NotificationEvent({
    required this.kind,
    this.level = NotificationLevel.info,
    this.channelId,
    this.messageId,
    this.node,
    this.title,
    this.body,
    this.payload = const {},
    this.createdAt,
  });

  final NotificationKind kind;
  final NotificationLevel level;
  final String? channelId;
  final String? messageId;
  final String? node;
  final String? title;
  final String? body;

  /// Versioned auxiliary data (e.g. receipt state, attempt counts).
  final Map<String, Object?> payload;

  final DateTime? createdAt;

  NotificationEvent copyWith({DateTime? createdAt}) => NotificationEvent(
    kind: kind,
    level: level,
    channelId: channelId,
    messageId: messageId,
    node: node,
    title: title,
    body: body,
    payload: payload,
    createdAt: createdAt ?? this.createdAt,
  );
}
