// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel_dao.dart';

// ignore_for_file: type=lint
mixin _$ChannelDaoMixin on DatabaseAccessor<OneBitDatabase> {
  $ChannelsTable get channels => attachedDatabase.channels;
  $TypingEventsTable get typingEvents => attachedDatabase.typingEvents;
  ChannelDaoManager get managers => ChannelDaoManager(this);
}

class ChannelDaoManager {
  final _$ChannelDaoMixin _db;
  ChannelDaoManager(this._db);
  $$ChannelsTableTableManager get channels =>
      $$ChannelsTableTableManager(_db.attachedDatabase, _db.channels);
  $$TypingEventsTableTableManager get typingEvents =>
      $$TypingEventsTableTableManager(_db.attachedDatabase, _db.typingEvents);
}
