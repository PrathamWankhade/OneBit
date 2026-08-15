import 'package:drift/drift.dart';

import '../database.dart';
import 'messaging_schema.dart';
import 'migration_step.dart';

/// Registry of migrations, oldest first.
///
/// `currentVersion` MUST equal `database.schemaVersion`. Add a step for every
/// future schema bump and regenerate the committed schema snapshot
/// (`dart run tool/generate_schema_snapshot.dart`) so `schema_snapshot_test`
/// can verify the live schema against it.
abstract final class MigrationRegistry {
  const MigrationRegistry._();

  /// Current schema version.
  ///
  /// v1: initial 25-table schema; v2: `DtnPackets`; v3: messaging domain
  /// (drafts, pins, reactions, metadata, notifications, message ordering
  /// columns and the FTS search index); v4: messaging hardening
  /// (packet_order, exit bookkeeping, receipt states, reaction/metadata FK
  /// cascades); v5: media engine (catalog, transfers, chunks, thumbnails,
  /// previews, voice recordings, cache entries, statistics).
  static const int currentVersion = 5;

  /// All migration steps, oldest first.
  static const List<MigrationStep> steps = <MigrationStep>[
    MigrationStep(
      targetVersion: 2,
      description: 'Add DtnPackets table for the store-and-forward layer',
      up: _createDtnTable,
    ),
    MigrationStep(
      targetVersion: 3,
      description:
          'Messaging domain: drafts, pins, reactions, metadata, '
          'notifications, message sequence/client/body columns, FTS index',
      up: _createMessagingSchema,
    ),
    MigrationStep(
      targetVersion: 4,
      description:
          'Messaging hardening: packet_order, verified_at, attempt '
          'bookkeeping, delivery-receipt states, FK cascades for reactions '
          'and metadata',
      up: _createMessagingHardening,
    ),
    MigrationStep(
      targetVersion: 5,
      description:
          'Media engine: catalog, transfer sessions, chunk ledger, '
          'thumbnails, previews, voice recordings, cache entries, media '
          'statistics',
      up: _createMediaSchema,
    ),
  ];

  static Future<void> _createDtnTable(
    Migrator migrator,
    OneBitDatabase db,
  ) async {
    await migrator.createTable(
      db.dtnPackets,
      // No foreign keys: an envelope may address nodes unknown to
      // `Neighbors`, and relays of third-party packets must survive a
      // neighbor re-registration.
    );
  }

  static Future<void> _createMessagingSchema(
    Migrator migrator,
    OneBitDatabase db,
  ) async {
    // ---- additive columns on existing tables -------------------------------
    await migrator.addColumn(db.messages, db.messages.sequence);
    await migrator.addColumn(db.messages, db.messages.clientId);
    await migrator.addColumn(db.messages, db.messages.packetId);
    await migrator.addColumn(db.messages, db.messages.bodyText);
    await migrator.addColumn(db.messages, db.messages.readAt);
    await migrator.addColumn(db.messages, db.messages.verified);
    await migrator.addColumn(db.messages, db.messages.starred);
    await migrator.addColumn(db.channels, db.channels.lastSequence);
    await migrator.addColumn(db.channels, db.channels.notificationPreference);
    await migrator.addColumn(db.channels, db.channels.autoDeleteAfter);

    // Read receipts gain device/version tracking.
    await migrator.addColumn(db.readReceipts, db.readReceipts.device);
    await migrator.addColumn(db.readReceipts, db.readReceipts.version);

    // ---- new tables --------------------------------------------------------
    await migrator.createTable(db.messageDrafts);
    await migrator.createTable(db.pinnedMessages);
    await migrator.createTable(db.messageReactions);
    await migrator.createTable(db.messageMetadata);
    await migrator.createTable(db.notifications);

    // ---- index on the pre-existing messages table ---------------------------
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_messages_channel_seq '
      'ON messages (channel_id, sequence)',
    );

    // ---- raw schema (FTS index) --------------------------------------------
    await MessagingSchema.install(db);
  }

  static Future<void> _createMessagingHardening(
    Migrator migrator,
    OneBitDatabase db,
  ) async {
    // ---- additive columns on existing tables -------------------------------
    await migrator.addColumn(db.messages, db.messages.packetOrder);
    await migrator.addColumn(db.messages, db.messages.verifiedAt);
    await migrator.addColumn(db.messages, db.messages.attemptCount);
    await migrator.addColumn(db.messages, db.messages.lastError);
    await migrator.addColumn(db.deliveryReceipts, db.deliveryReceipts.state);

    // Reactions and metadata gain FK cascades onto Messages; the tables are
    // rebuilt in place (12-step sqlite procedure) so existing rows survive
    // the upgrade.
    await migrator.alterTable(TableMigration(db.messageReactions));
    await migrator.alterTable(TableMigration(db.messageMetadata));
  }

  static Future<void> _createMediaSchema(
    Migrator migrator,
    OneBitDatabase db,
  ) async {
    await migrator.createTable(db.mediaAttachments);
    await migrator.createTable(db.transferSessions);
    await migrator.createTable(db.transferChunks);
    await migrator.createTable(db.mediaThumbnails);
    await migrator.createTable(db.mediaPreviews);
    await migrator.createTable(db.voiceRecordings);
    await migrator.createTable(db.cacheEntries);
    await migrator.createTable(db.mediaStatistics);
  }
}
