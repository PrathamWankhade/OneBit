import 'package:drift/drift.dart';

import 'channel_tables.dart';
import 'converters.dart';
import 'enums.dart';

/// A message in a channel.
///
/// The payload is always app-layer ciphertext (`encryptedPayload`); SQLite
/// never sees plaintext content. Search is metadata-based (sender, channel,
/// type, status, time) until a decrypted index lands in a later phase.
@DataClassName('MessageRow')
@TableIndex(name: 'idx_messages_channel_ts', columns: {#channelId, #timestamp})
@TableIndex(name: 'idx_messages_channel_seq', columns: {#channelId, #sequence})
@TableIndex(name: 'idx_messages_sender', columns: {#sender})
@TableIndex(name: 'idx_messages_status', columns: {#status})
class Messages extends Table {
  TextColumn get messageId => text()();

  TextColumn get channelId =>
      text().references(Channels, #channelId, onDelete: KeyAction.cascade)();

  /// Sender node id (`NODE-XXXX-XXXX`).
  TextColumn get sender => text()();

  /// Receiver node id; null for group/broadcast channels.
  TextColumn get receiver => text().nullable()();

  /// Epoch ms; the mesh clock, not necessarily wall time.
  IntColumn get timestamp => integer().map(dateTimeMsConverter)();

  BlobColumn get encryptedPayload => blob()();

  /// IV/nonce accompanying the payload (can be absent for no-encryption modes).
  BlobColumn get payloadIv => blob().nullable()();

  TextColumn get messageType => textEnum<MessageType>()();

  TextColumn get status =>
      textEnum<MessageStatus>().withDefault(const Constant('pending'))();

  TextColumn get replyTo => text().nullable()();

  BoolColumn get forwarded => boolean().withDefault(const Constant(false))();

  BoolColumn get edited => boolean().withDefault(const Constant(false))();

  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  IntColumn get ttl => integer().nullable()();

  TextColumn get priority =>
      textEnum<PriorityLevel>().withDefault(const Constant('normal'))();

  /// Message schema version for forward-compatible payload parsing.
  IntColumn get version => integer().withDefault(const Constant(1))();

  // ---- Phase 8 messaging columns -----------------------------------------

  /// Per-channel ordering counter assigned by the origin node.
  IntColumn get sequence => integer().withDefault(const Constant(0))();

  /// Generator-chosen idempotency key of the client that produced the message.
  TextColumn get clientId => text().nullable()();

  /// DTN envelope id that carried this message (outbound only).
  TextColumn get packetId => text().nullable()();

  /// Plaintext body kept at rest for local rendering and search. The
  /// authoritative wire representation remains [encryptedPayload]; this
  /// column is the local, device-side content mirror (device-at-rest
  /// encryption belongs to a later phase).
  TextColumn get bodyText => text().nullable()();

  /// When the local user read this message (read receipts).
  IntColumn get readAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  /// Receipt verification completed for this message.
  BoolColumn get verified => boolean().withDefault(const Constant(false))();

  /// When the receipt chain verified this message (crypto verification).
  IntColumn get verifiedAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  /// Local user starred this message.
  BoolColumn get starred => boolean().withDefault(const Constant(false))();

  /// First-arrival index at this node: the local tie-break of the ordering
  /// key (written only on first arrival / compose, never moved).
  IntColumn get packetOrder => integer().withDefault(const Constant(0))();

  /// How many times the outbox tried to store this message's envelope.
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  /// Reason of the last failure / cancel (outbox bookkeeping).
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {messageId};
}

/// Binary payloads attached to a message.
@DataClassName('AttachmentRow')
class Attachments extends Table {
  TextColumn get attachmentId => text()();

  TextColumn get messageId =>
      text().references(Messages, #messageId, onDelete: KeyAction.cascade)();

  TextColumn get kind => textEnum<AttachmentKind>()();

  TextColumn get filename => text().nullable()();

  TextColumn get mimeType => text().nullable()();

  IntColumn get sizeBytes => integer().nullable()();

  /// On-disk location of the (encrypted) file, kept outside the DB file.
  TextColumn get localPath => text().nullable()();

  /// Inline ciphertext for small payloads.
  BlobColumn get encryptedData => blob().nullable()();

  TextColumn get checksum => text().nullable()();

  IntColumn get createdAt => integer().map(dateTimeMsConverter)();

  @override
  Set<Column> get primaryKey => {attachmentId};
}

/// Voice notes (small audio recordings) attached to a message.
@DataClassName('VoiceNoteRow')
class VoiceNotes extends Table {
  TextColumn get voiceNoteId => text()();

  TextColumn get messageId =>
      text().references(Messages, #messageId, onDelete: KeyAction.cascade)();

  IntColumn get durationMs => integer().nullable()();

  BlobColumn get waveform => blob().nullable()();

  TextColumn get localPath => text().nullable()();

  BlobColumn get encryptedData => blob().nullable()();

  TextColumn get mimeType => text().nullable()();

  IntColumn get createdAt => integer().map(dateTimeMsConverter)();

  @override
  Set<Column> get primaryKey => {voiceNoteId};
}

/// Delivery acknowledgements per message and node.
@DataClassName('DeliveryReceiptRow')
class DeliveryReceipts extends Table {
  TextColumn get receiptId => text()();

  TextColumn get messageId =>
      text().references(Messages, #messageId, onDelete: KeyAction.cascade)();

  TextColumn get node => text()();

  IntColumn get deliveredAt => integer().map(dateTimeMsConverter)();

  /// Lifecycle of the receipt envelope as seen by this node
  /// (`queued` → `sent` → `delivered`/`failed`/`duplicate`).
  TextColumn get state =>
      textEnum<ReceiptState>().withDefault(const Constant('sent'))();

  TextColumn get metadata => text().nullable()();

  @override
  Set<Column> get primaryKey => {receiptId};
}

/// Read acknowledgements per message and node.
@DataClassName('ReadReceiptRow')
class ReadReceipts extends Table {
  TextColumn get receiptId => text()();

  TextColumn get messageId =>
      text().references(Messages, #messageId, onDelete: KeyAction.cascade)();

  TextColumn get node => text()();

  IntColumn get readAt => integer().map(dateTimeMsConverter)();

  /// Optional reader device tag (multi-device read receipts).
  TextColumn get device => text().nullable()();

  /// Reader software version.
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {receiptId};
}
