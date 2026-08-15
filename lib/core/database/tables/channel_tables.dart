import 'package:drift/drift.dart';

import 'converters.dart';
import 'enums.dart';

/// A logical channel grouping messages by topic across the mesh.
@DataClassName('ChannelRow')
@TableIndex(name: 'idx_channels_listing', columns: {#pinned, #updatedAt})
class Channels extends Table {
  TextColumn get channelId => text()();

  TextColumn get type => textEnum<ChannelType>()();

  TextColumn get title => text().nullable()();

  IntColumn get createdAt => integer().map(dateTimeMsConverter)();

  IntColumn get updatedAt => integer().map(dateTimeMsConverter)();

  IntColumn get unreadCount => integer().withDefault(const Constant(0))();

  TextColumn get lastMessageId => text().nullable()();

  IntColumn get lastMessageAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  BoolColumn get muted => boolean().withDefault(const Constant(false))();

  IntColumn get mutedUntil =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  /// Monotonic per-channel sequence counter (Phase 8 messaging ordering).
  IntColumn get lastSequence => integer().withDefault(const Constant(0))();

  /// Notification policy (`all` | `mentionsOnly` | `none`).
  TextColumn get notificationPreference =>
      text().withDefault(const Constant('all'))();

  /// Local retention: auto-deletion window in seconds, null = keep forever.
  IntColumn get autoDeleteAfter => integer().nullable()();

  @override
  Set<Column> get primaryKey => {channelId};
}

/// Typing indicator lifecycle events per channel.
@DataClassName('TypingEventRow')
class TypingEvents extends Table {
  IntColumn get eventId => integer().autoIncrement()();

  TextColumn get channelId =>
      text().references(Channels, #channelId, onDelete: KeyAction.cascade)();

  TextColumn get node => text()();

  TextColumn get kind => textEnum<TypingKind>()();

  IntColumn get startedAt => integer().map(dateTimeMsConverter)();

  IntColumn get endedAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();
}
