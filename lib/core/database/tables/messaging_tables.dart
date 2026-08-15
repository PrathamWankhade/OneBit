import 'package:drift/drift.dart';

import 'channel_tables.dart';
import 'converters.dart';
import 'message_tables.dart';

/// One editable draft per channel (Phase 8 messaging composer).
///
/// Drafts are the offline-first composing surface: body + an optional
/// pointer to the message being edited (edit resumes where the user left
/// off). Keyed by channel id — there is never more than one draft per
/// conversation.
@TableIndex(name: 'idx_message_drafts_channel', columns: {#channelId})
@DataClassName('MessageDraftRow')
class MessageDrafts extends Table {
  TextColumn get channelId =>
      text().references(Channels, #channelId, onDelete: KeyAction.cascade)();

  TextColumn get body => text()();

  /// When non-null, this draft edits an existing message in place.
  TextColumn get editingMessageId => text().nullable()();

  IntColumn get createdAt => integer().map(dateTimeMsConverter)();

  IntColumn get updatedAt => integer().map(dateTimeMsConverter)();

  @override
  Set<Column> get primaryKey => {channelId};
}

/// Messages pinned to a channel heading.
@DataClassName('PinnedMessageRow')
class PinnedMessages extends Table {
  TextColumn get channelId =>
      text().references(Channels, #channelId, onDelete: KeyAction.cascade)();

  TextColumn get messageId => text()();

  TextColumn get pinnedBy => text()();

  IntColumn get pinnedAt => integer().map(dateTimeMsConverter)();

  @override
  Set<Column> get primaryKey => {channelId, messageId};
}

/// Emoji reactions per message and node.
@DataClassName('MessageReactionRow')
class MessageReactions extends Table {
  TextColumn get messageId =>
      text().references(Messages, #messageId, onDelete: KeyAction.cascade)();

  TextColumn get node => text()();

  TextColumn get reaction => text()();

  IntColumn get createdAt => integer().map(dateTimeMsConverter)();

  @override
  Set<Column> get primaryKey => {messageId, node, reaction};
}

/// Machine metadata of a message that does not belong in the Messages row:
/// idempotency keys, DTN envelope wiring and retry bookkeeping.
@DataClassName('MessageMetadataRow')
class MessageMetadata extends Table {
  TextColumn get messageId =>
      text().references(Messages, #messageId, onDelete: KeyAction.cascade)();

  TextColumn get clientId => text().nullable()();

  TextColumn get packetId => text().nullable()();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  TextColumn get payloadJson => text().nullable()();

  IntColumn get verifiedAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  @override
  Set<Column> get primaryKey => {messageId};
}

/// Internal notification log produced by the notification engine.
///
/// This is not an Android notification stream — it is the durable event log
/// the UI layer will consume in a later phase.
@TableIndex(name: 'idx_notifications_created', columns: {#createdAt})
@DataClassName('NotificationRow')
class Notifications extends Table {
  IntColumn get notificationId => integer().autoIncrement()();

  /// Stable event-kind string (e.g. `message.received`).
  TextColumn get kind => text()();

  TextColumn get level => text()();

  TextColumn get channelId => text().nullable()();

  TextColumn get messageId => text().nullable()();

  TextColumn get node => text().nullable()();

  TextColumn get title => text().nullable()();

  TextColumn get body => text().nullable()();

  /// Versioned JSON payload of the event.
  TextColumn get payloadJson => text().nullable()();

  IntColumn get createdAt => integer().map(dateTimeMsConverter)();

  IntColumn get readAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();
}
