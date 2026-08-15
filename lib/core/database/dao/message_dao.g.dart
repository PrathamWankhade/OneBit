// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_dao.dart';

// ignore_for_file: type=lint
mixin _$MessageDaoMixin on DatabaseAccessor<OneBitDatabase> {
  $ChannelsTable get channels => attachedDatabase.channels;
  $MessagesTable get messages => attachedDatabase.messages;
  $AttachmentsTable get attachments => attachedDatabase.attachments;
  $VoiceNotesTable get voiceNotes => attachedDatabase.voiceNotes;
  $DeliveryReceiptsTable get deliveryReceipts =>
      attachedDatabase.deliveryReceipts;
  $ReadReceiptsTable get readReceipts => attachedDatabase.readReceipts;
  MessageDaoManager get managers => MessageDaoManager(this);
}

class MessageDaoManager {
  final _$MessageDaoMixin _db;
  MessageDaoManager(this._db);
  $$ChannelsTableTableManager get channels =>
      $$ChannelsTableTableManager(_db.attachedDatabase, _db.channels);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db.attachedDatabase, _db.messages);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db.attachedDatabase, _db.attachments);
  $$VoiceNotesTableTableManager get voiceNotes =>
      $$VoiceNotesTableTableManager(_db.attachedDatabase, _db.voiceNotes);
  $$DeliveryReceiptsTableTableManager get deliveryReceipts =>
      $$DeliveryReceiptsTableTableManager(
        _db.attachedDatabase,
        _db.deliveryReceipts,
      );
  $$ReadReceiptsTableTableManager get readReceipts =>
      $$ReadReceiptsTableTableManager(_db.attachedDatabase, _db.readReceipts);
}
