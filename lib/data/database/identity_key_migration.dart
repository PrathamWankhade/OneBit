import 'package:drift/drift.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/crypto/ed25519_keys.dart';

/// Settings key recording that stored identity ids are real Ed25519
/// public keys.
///
/// Builds before schema v13 hex-encoded the Ed25519 *private seed* into
/// `identity_id`/`public_key` (and into anything keyed by them). Once
/// this marker exists, every 64-hex value in those columns is a public
/// key and must never be derived from again — deriving a public key
/// from a public key would quietly replace an identity with one nobody
/// holds.
const String identityKeyShapeSetting = 'identity_key_shape_v13';

/// Rewrite every stored identity id from the leaked seed to the public
/// key it corresponds to.
///
/// This is the one place that treats a stored value as a seed, and it
/// is only sound because the marker above proves the value predates the
/// fix: anything written after the migration is already a public key.
/// Rows that do not look like 64-hex (BLE addresses, nulls) are left
/// alone, and conversations keyed by a peer's old id follow it to the
/// new one so threads survive the rewrite.
Future<void> migrateIdentityIdsToPublicKeys(AppDatabase db) async {
  final marked = await (db.select(db.settings)
        ..where((t) => t.key.equals(identityKeyShapeSetting)))
      .getSingleOrNull();
  if (marked != null) return;

  final localRows = await db
      .customSelect('SELECT id, identity_id, public_key FROM local_identity')
      .get();
  final peerRows = await db
      .customSelect('SELECT id, identity_id, public_key FROM peer_identities')
      .get();
  final conversationRows = await db
      .customSelect(
        'SELECT id, peer_device_id FROM conversations '
        'WHERE peer_device_id IS NOT NULL',
      )
      .get();

  final seeds = <String>{};
  String? readHex(QueryRow row, String column) {
    final value = row.readNullable<String>(column);
    if (value == null || value.length != 64) return null;
    return value;
  }

  for (final row in [...localRows, ...peerRows]) {
    final identityId = readHex(row, 'identity_id');
    final publicKey = readHex(row, 'public_key');
    if (identityId != null) seeds.add(identityId.toLowerCase());
    if (publicKey != null) seeds.add(publicKey.toLowerCase());
  }
  for (final row in conversationRows) {
    final peer = readHex(row, 'peer_device_id');
    if (peer != null) seeds.add(peer.toLowerCase());
  }

  final derived = <String, String>{};
  for (final seed in seeds) {
    final publicKeyHex = await ed25519PublicKeyHex(seed);
    if (publicKeyHex != null) derived[seed] = publicKeyHex;
  }

  Future<void> rewrite(
    String table,
    int id,
    String column,
    String value,
  ) async {
    final next = derived[value.toLowerCase()];
    if (next == null || next.toLowerCase() == value.toLowerCase()) return;
    db.customStatement(
      'UPDATE $table SET $column = ? WHERE id = ?',
      [next, id],
    );
  }

  for (final row in localRows) {
    final id = row.read<int>('id');
    final identityId = row.readNullable<String>('identity_id');
    final publicKey = row.readNullable<String>('public_key');
    if (identityId != null && identityId.length == 64) {
      await rewrite('local_identity', id, 'identity_id', identityId);
    }
    if (publicKey != null && publicKey.length == 64) {
      await rewrite('local_identity', id, 'public_key', publicKey);
    }
  }
  for (final row in peerRows) {
    final id = row.read<int>('id');
    final identityId = row.readNullable<String>('identity_id');
    final publicKey = row.readNullable<String>('public_key');
    if (identityId != null && identityId.length == 64) {
      await rewrite('peer_identities', id, 'identity_id', identityId);
    }
    if (publicKey != null && publicKey.length == 64) {
      await rewrite('peer_identities', id, 'public_key', publicKey);
    }
  }
  for (final row in conversationRows) {
    final id = row.read<int>('id');
    final peer = row.readNullable<String>('peer_device_id');
    if (peer != null && peer.length == 64) {
      final next = derived[peer.toLowerCase()];
      if (next != null && next.toLowerCase() != peer.toLowerCase()) {
        db.customStatement(
          'UPDATE conversations SET peer_device_id = ? WHERE id = ?',
          [next, id],
        );
      }
    }
  }

  await db
      .into(db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: identityKeyShapeSetting,
          value: 'public',
        ),
      );
}
