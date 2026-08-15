import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/trust_contact.dart';
import 'package:onebit/features/identity/domain/trust_level.dart';

/// Repository contract for known peer nodes (trusted contacts).
///
/// Phase 2 keeps contacts in memory (the persistence phase later backs this
/// interface with the storage channel); the interface is stable regardless of
/// backing store.
abstract interface class TrustContactRepository {
  /// Loads the current set of contacts (empty when none exist).
  Future<Result<List<TrustContact>>> loadContacts();

  /// Returns the contact with [nodeId], or `null` when unknown.
  Future<Result<TrustContact?>> find(String nodeId);

  /// Adds or replaces a contact. Trust level changes are applied here.
  Future<Result<TrustContact>> upsert(TrustContact contact);

  /// Updates the trust posture of a known contact.
  Future<Result<TrustContact>> setTrustLevel({
    required String nodeId,
    required TrustLevel level,
  });

  /// Removes a contact; returns `false` when it did not exist.
  Future<Result<bool>> remove(String nodeId);
}
