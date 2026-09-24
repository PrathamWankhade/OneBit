import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:onebit/core/logging/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class Conversations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get peerDeviceId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get conversationId => integer().references(Conversations, #id)();
  TextColumn get content => text()();
  TextColumn get status => text().withDefault(const Constant('local'))();
  TextColumn get externalMessageId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Peer identities discovered via BLE or QR.
class PeerIdentities extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get identityId => text().nullable().unique()();
  TextColumn get publicKey => text().nullable()();
  TextColumn get displayName => text()();
  TextColumn get about => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();
  TextColumn get keyAgreementPublicKey => text().nullable()();

  // ── Trust persistence (I6.8) ──

  /// Persisted trust state: unknown, verified, trusted, revoked.
  TextColumn get trustState => text().withDefault(const Constant('unknown'))();

  /// When the peer's identity was verified.
  DateTimeColumn get verifiedAt => dateTime().nullable()();

  /// How the peer's identity was verified (qrScan, fingerprintComparison, pairingProtocol).
  TextColumn get verificationMethod => text().nullable()();

  /// When the peer was explicitly trusted.
  DateTimeColumn get trustedAt => dateTime().nullable()();

  // ── Identity change detection (I6.10) ──

  /// Last BLE address (MAC) seen for this peer identity.
  ///
  /// Used to detect when a known BLE device presents a different
  /// cryptographic identity (identity change detection).
  TextColumn get lastSeenBleAddress => text().nullable()();
}

/// Local metadata about our own identity (single row, always id=1).
class LocalIdentity extends Table {
  IntColumn get id => integer()();
  TextColumn get identityId => text().nullable()();
  TextColumn get displayName => text()();
  TextColumn get about => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get publicKey => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Settings, Conversations, Messages, PeerIdentities, LocalIdentity],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.test(DatabaseConnection super.e);

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          AppLogger.info('Creating database schema v$schemaVersion');
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          AppLogger.info('Upgrading database from v$from to v$to');
          if (from < 2) {
            await m.createTable(conversations);
            await m.createTable(messages);
          }
          if (from < 3) {
            await m.addColumn(conversations, conversations.peerDeviceId);
            await m.addColumn(messages, messages.externalMessageId);
          }
          if (from < 4) {
            // Previous identity tables (will be dropped in v5)
            // This migration path is for existing v3 databases
          }
          if (from < 5) {
            // Drop old identity tables if they exist
            await m.deleteTable('identities');
            await m.deleteTable('ownIdentityMetadata');
            // Create new identity tables
            await m.createTable(peerIdentities);
            await m.createTable(localIdentity);
          }
          if (from < 6) {
            // Add publicKey column to localIdentity (may already exist
            // if the table was created in v5 with the current schema)
            final hasCol = await customSelect(
              "SELECT 1 FROM pragma_table_info('local_identity') WHERE name='public_key'",
            ).getSingleOrNull();
            if (hasCol == null) {
              await m.addColumn(localIdentity, localIdentity.publicKey);
            }
          }
          if (from < 7) {
            // Add publicKey column to peerIdentities (may already exist
            // if the table was created in v5 with the current schema)
            final hasCol = await customSelect(
              "SELECT 1 FROM pragma_table_info('peer_identities') WHERE name='public_key'",
            ).getSingleOrNull();
            if (hasCol == null) {
              await m.addColumn(peerIdentities, peerIdentities.publicKey);
            }
          }
          if (from < 8) {
            // Add keyAgreementPublicKey column to peerIdentities
            final hasCol = await customSelect(
              "SELECT 1 FROM pragma_table_info('peer_identities') WHERE name='key_agreement_public_key'",
            ).getSingleOrNull();
            if (hasCol == null) {
              await m.addColumn(
                peerIdentities,
                peerIdentities.keyAgreementPublicKey,
              );
            }
          }
          if (from < 9) {
            // Add trust persistence columns to peerIdentities
            for (final col in [
              ('trust_state', "TEXT DEFAULT 'unknown'"),
              ('verified_at', 'DATETIME'),
              ('verification_method', 'TEXT'),
              ('trusted_at', 'DATETIME'),
            ]) {
              final hasCol = await customSelect(
                "SELECT 1 FROM pragma_table_info('peer_identities') WHERE name='${col.$1}'",
              ).getSingleOrNull();
              if (hasCol == null) {
                await customStatement(
                  'ALTER TABLE peer_identities ADD COLUMN ${col.$1} ${col.$2}',
                );
              }
            }
          }
          if (from < 10) {
            // Add lastSeenBleAddress column for identity change detection
            final hasCol = await customSelect(
              "SELECT 1 FROM pragma_table_info('peer_identities') WHERE name='last_seen_ble_address'",
            ).getSingleOrNull();
            if (hasCol == null) {
              await customStatement(
                'ALTER TABLE peer_identities ADD COLUMN last_seen_ble_address TEXT',
              );
            }
          }
          if (from < 11) {
            // Add about/bio column to both identity tables
            for (final table in ['local_identity', 'peer_identities']) {
              final hasCol = await customSelect(
                "SELECT 1 FROM pragma_table_info('$table') WHERE name='about'",
              ).getSingleOrNull();
              if (hasCol == null) {
                await customStatement(
                  'ALTER TABLE $table ADD COLUMN about TEXT',
                );
              }
            }
          }
        },
        beforeOpen: (details) async {
          AppLogger.info(
            'Database opened, created=${details.wasCreated}',
          );
        },
      );

  // ── Conversation operations ──

  Stream<List<Conversation>> watchConversations() {
    final query = select(conversations)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch();
  }

  Future<Conversation?> getConversation(int id) {
    return (select(conversations)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> createConversation(String title) {
    final now = DateTime.now();
    return into(conversations).insert(
      ConversationsCompanion.insert(
        title: title,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<bool> updateConversation(ConversationsCompanion entry) {
    return update(conversations).replace(entry);
  }

  Future<int> deleteConversation(int id) async {
    // Delete messages first to avoid foreign key constraint violations.
    await (delete(messages)..where((t) => t.conversationId.equals(id))).go();
    return (delete(conversations)..where((t) => t.id.equals(id))).go();
  }

  // ── Message operations ──

  Stream<List<Message>> watchMessages(int conversationId) {
    final query = select(messages)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch();
  }

  Future<List<Message>> getMessages(int conversationId) {
    return (select(messages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<int> insertMessage({
    required int conversationId,
    required String content,
  }) async {
    final id = await into(messages).insert(
      MessagesCompanion.insert(
        conversationId: conversationId,
        content: content,
        createdAt: DateTime.now(),
      ),
    );
    await (update(conversations)..where((t) => t.id.equals(conversationId)))
        .write(ConversationsCompanion(
      updatedAt: Value(DateTime.now()),
    ));
    return id;
  }

  Future<int> deleteMessages(int conversationId) {
    return (delete(messages)
          ..where((t) => t.conversationId.equals(conversationId)))
        .go();
  }

  Future<int> deleteMessage(int id) {
    return (delete(messages)..where((t) => t.id.equals(id))).go();
  }

  // ── BLE Transport helpers ──

  /// Find a conversation linked to a specific peer device.
  Future<Conversation?> getConversationByPeerDevice(String peerDeviceId) {
    return (select(conversations)
          ..where((t) => t.peerDeviceId.equals(peerDeviceId))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Create a conversation linked to a peer device.
  Future<int> createConversationWithPeer(String title, String peerDeviceId) {
    final now = DateTime.now();
    return into(conversations).insert(
      ConversationsCompanion.insert(
        title: title,
        peerDeviceId: Value(peerDeviceId),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Insert a message received from a peer, with deduplication.
  ///
  /// Returns the message ID, or null if a message with the same
  /// [externalMessageId] already exists (duplicate).
  Future<int?> insertReceivedMessage({
    required int conversationId,
    required String content,
    required String externalMessageId,
  }) async {
    // Deduplication: check if this external message ID already exists.
    final existing = await (select(messages)
          ..where((t) => t.externalMessageId.equals(externalMessageId))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return null;

    final id = await into(messages).insert(
      MessagesCompanion.insert(
        conversationId: conversationId,
        content: content,
        status: const Value('received'),
        externalMessageId: Value(externalMessageId),
        createdAt: DateTime.now(),
      ),
    );
    await (update(conversations)..where((t) => t.id.equals(conversationId)))
        .write(ConversationsCompanion(
      updatedAt: Value(DateTime.now()),
    ));
    return id;
  }

  /// Check whether a message with the given external ID exists.
  Future<bool> messageExists(String externalMessageId) async {
    final existing = await (select(messages)
          ..where((t) => t.externalMessageId.equals(externalMessageId))
          ..limit(1))
        .getSingleOrNull();
    return existing != null;
  }

  // ── Local Identity operations ──

  /// Get the local identity (returns null if not created yet).
  Future<LocalIdentityData?> getLocalIdentity() {
    return (select(localIdentity)..limit(1)).getSingleOrNull();
  }

  /// Create a new local identity.
  ///
  /// Enforces single-row invariant: if a local identity already exists,
  /// returns the existing one instead of creating a duplicate.
  Future<LocalIdentityData> createLocalIdentity({
    required String displayName,
    String? publicKey,
  }) async {
    // Enforce single-row invariant
    final existing = await getLocalIdentity();
    if (existing != null) {
      return existing;
    }

    final now = DateTime.now();
    final id = await into(localIdentity).insert(
      LocalIdentityCompanion.insert(
        id: const Value(1),
        displayName: displayName,
        createdAt: now,
        publicKey: Value(publicKey),
      ),
    );
    return (select(localIdentity)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  /// Update the local identity's public key and identity ID.
  Future<void> updateLocalIdentityCrypto({
    required int id,
    required String identityId,
    required String publicKey,
  }) async {
    await (update(localIdentity)..where((t) => t.id.equals(id))).write(
      LocalIdentityCompanion(
        identityId: Value(identityId),
        publicKey: Value(publicKey),
      ),
    );
  }

  /// Update the local identity's profile (display name and about).
  Future<void> updateLocalIdentityProfile({
    required int id,
    required String displayName,
    String? about,
  }) async {
    await (update(localIdentity)..where((t) => t.id.equals(id))).write(
      LocalIdentityCompanion(
        displayName: Value(displayName),
        about: Value(about),
      ),
    );
  }

  // ── Peer Identity operations ──

  /// Get a peer identity by ID.
  Future<PeerIdentity?> getPeerIdentity(int id) {
    return (select(peerIdentities)
          ..where((t) => t.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get a peer identity by identityId (nullable).
  Future<PeerIdentity?> getPeerIdentityByIdentityId(String identityId) {
    return (select(peerIdentities)
          ..where((t) => t.identityId.equals(identityId))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get all known peer identities.
  Future<List<PeerIdentity>> getAllPeerIdentities() {
    return select(peerIdentities).get();
  }

  /// Watch all known peer identities.
  Stream<List<PeerIdentity>> watchPeerIdentities() {
    return select(peerIdentities).watch();
  }

  /// Insert or update a peer identity.
  Future<void> upsertPeerIdentity({
    required String displayName,
    required DateTime createdAt,
    String? identityId,
    String? publicKey,
    DateTime? lastSeenAt,
    String? keyAgreementPublicKey,
  }) async {
    // If identityId is provided, check for existing peer
    if (identityId != null) {
      final existing = await getPeerIdentityByIdentityId(identityId);
      if (existing != null) {
        await (update(peerIdentities)
              ..where((t) => t.id.equals(existing.id)))
            .write(PeerIdentitiesCompanion(
          displayName: Value(displayName),
          lastSeenAt: Value(lastSeenAt),
          keyAgreementPublicKey: Value(keyAgreementPublicKey),
        ));
        return;
      }
    }

    // Insert new peer
    await into(peerIdentities).insert(
      PeerIdentitiesCompanion.insert(
        identityId: Value(identityId),
        publicKey: Value(publicKey),
        displayName: displayName,
        createdAt: createdAt,
        lastSeenAt: Value(lastSeenAt),
        keyAgreementPublicKey: Value(keyAgreementPublicKey),
      ),
    );
  }

  /// Delete a peer identity.
  Future<int> deletePeerIdentity(int id) {
    return (delete(peerIdentities)..where((t) => t.id.equals(id))).go();
  }

  /// Update a peer's display name.
  Future<void> updatePeerDisplayName({
    required int id,
    required String displayName,
  }) async {
    await (update(peerIdentities)..where((t) => t.id.equals(id))).write(
      PeerIdentitiesCompanion(displayName: Value(displayName)),
    );
  }

  /// Update a peer's key-agreement public key.
  Future<void> updatePeerKeyAgreementPublicKey({
    required int id,
    required String keyAgreementPublicKey,
  }) async {
    await (update(peerIdentities)..where((t) => t.id.equals(id))).write(
      PeerIdentitiesCompanion(
        keyAgreementPublicKey: Value(keyAgreementPublicKey),
      ),
    );
  }

  /// Update a peer's last seen BLE address.
  ///
  /// Used for identity change detection (I6.10).
  Future<void> updatePeerLastSeenBleAddress({
    required int id,
    required String? lastSeenBleAddress,
  }) async {
    await (update(peerIdentities)..where((t) => t.id.equals(id))).write(
      PeerIdentitiesCompanion(
        lastSeenBleAddress: Value(lastSeenBleAddress),
      ),
    );
  }

  // ── Trust persistence operations (I6.8) ──

  /// Load all persisted trust records from the database.
  Future<List<PeerTrustRecord>> loadAllTrust() async {
    final rows = await customSelect(
      'SELECT identity_id, trust_state, verified_at, verification_method, trusted_at '
      'FROM peer_identities '
      "WHERE trust_state != 'unknown' AND identity_id IS NOT NULL",
    ).get();
    return rows.map((row) {
      return PeerTrustRecord(
        peerIdentityId: row.read<String>('identity_id'),
        trustState: row.read<String>('trust_state'),
        verifiedAt: row.read<DateTime?>('verified_at'),
        verificationMethod: row.read<String?>('verification_method'),
        trustedAt: row.read<DateTime?>('trusted_at'),
      );
    }).toList();
  }

  /// Persist trust state for a peer.
  ///
  /// Uses the peer's [identityId] (cryptographic identity) as the key.
  /// If no peer record exists with that identityId, this is a no-op.
  Future<void> savePeerTrust({
    required String peerIdentityId,
    required String trustState,
    DateTime? verifiedAt,
    String? verificationMethod,
    DateTime? trustedAt,
  }) async {
    await (update(peerIdentities)
          ..where((t) => t.identityId.equals(peerIdentityId)))
        .write(PeerIdentitiesCompanion(
      trustState: Value(trustState),
      verifiedAt: Value(verifiedAt),
      verificationMethod: Value(verificationMethod),
      trustedAt: Value(trustedAt),
    ));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'onebit.sqlite'));
    AppLogger.info('Database path: ${file.path}');
    return NativeDatabase.createInBackground(file);
  });
}

/// Lightweight data class for persisted trust records.
class PeerTrustRecord {
  const PeerTrustRecord({
    required this.peerIdentityId,
    required this.trustState,
    this.verifiedAt,
    this.verificationMethod,
    this.trustedAt,
  });

  final String peerIdentityId;
  final String trustState;
  final DateTime? verifiedAt;
  final String? verificationMethod;
  final DateTime? trustedAt;
}
