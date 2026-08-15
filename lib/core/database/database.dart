import 'package:drift/drift.dart';

import 'connection/database_pragmas.dart';
import 'migration/messaging_schema.dart';
import 'migration/migration_manager.dart';
import 'migration/migration_registry.dart';
import 'tables/channel_tables.dart';
import 'tables/converters.dart';
import 'tables/dtn_tables.dart';
import 'tables/enums.dart';
import 'tables/identity_tables.dart';
import 'tables/media_tables.dart';
import 'tables/message_tables.dart';
import 'tables/messaging_tables.dart';
import 'tables/metadata_tables.dart';
import 'tables/network_tables.dart';
import 'tables/packet_tables.dart';
import 'tables/queue_tables.dart';
import 'tables/session_tables.dart';
import 'tables/telemetry_tables.dart';

part 'database.g.dart';

/// The OneBit local database — the source of truth for all offline data.
///
/// Wiring: [schemaVersion] comes from [MigrationRegistry], PRAGMAs from
/// [DatabasePragmas], upgrades from [MigrationManager]. The connection
/// (usually a `LazyDatabase`) is injected, so tests swap in memory easily.
@DriftDatabase(
  tables: [
    Identity,
    TrustedNodes,
    NodeProfiles,
    Channels,
    TypingEvents,
    Messages,
    Attachments,
    VoiceNotes,
    DeliveryReceipts,
    ReadReceipts,
    MessageDrafts,
    PinnedMessages,
    MessageReactions,
    MessageMetadata,
    Notifications,
    Packets,
    PacketFragments,
    DtnPackets,
    Routes,
    Neighbors,
    Sessions,
    SessionKeys,
    PendingQueue,
    RetryQueue,
    RelayQueue,
    Settings,
    ApplicationMetadata,
    Logs,
    Diagnostics,
    DeveloperEvents,
    Statistics,
    MediaAttachments,
    TransferSessions,
    TransferChunks,
    MediaThumbnails,
    MediaPreviews,
    VoiceRecordings,
    CacheEntries,
    MediaStatistics,
  ],
)
class OneBitDatabase extends _$OneBitDatabase {
  OneBitDatabase(super.e);

  @override
  int get schemaVersion => MigrationRegistry.currentVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      // Fresh installs always build the newest schema directly.
      await migrator.createAll();
      await MessagingSchema.install(this);
    },
    onUpgrade: (migrator, from, to) async {
      await const MigrationManager(
        steps: MigrationRegistry.steps,
      ).apply(migrator, from: from, to: to, db: this);
    },
    beforeOpen: (details) async {
      await DatabasePragmas.apply(this);
    },
  );
}
