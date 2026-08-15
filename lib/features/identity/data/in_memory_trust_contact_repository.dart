import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/trust_contact.dart';
import 'package:onebit/features/identity/domain/trust_contact_repository.dart';
import 'package:onebit/features/identity/domain/trust_level.dart';

/// In-memory [TrustContactRepository].
///
/// Phase 2 deliberately keeps contacts volatile: the persistence phase will
/// back this interface with the storage channel without changing any caller.
final class InMemoryTrustContactRepository implements TrustContactRepository {
  InMemoryTrustContactRepository();

  final Map<String, TrustContact> _contacts = <String, TrustContact>{};

  @override
  Future<Result<List<TrustContact>>> loadContacts() async {
    return Ok(_contacts.values.toList());
  }

  @override
  Future<Result<TrustContact?>> find(String nodeId) async {
    return Ok(_contacts[nodeId]);
  }

  @override
  Future<Result<TrustContact>> upsert(TrustContact contact) async {
    final previous = _contacts[contact.nodeId.value];
    final merged = previous == null
        ? contact.copyWith(firstSeenAt: DateTime.now().toUtc())
        : contact.copyWith(
            firstSeenAt: previous.firstSeenAt,
            lastSeenAt: DateTime.now().toUtc(),
          );
    _contacts[merged.nodeId.value] = merged;
    return Ok(merged);
  }

  @override
  Future<Result<TrustContact>> setTrustLevel({
    required String nodeId,
    required TrustLevel level,
  }) async {
    final existing = _contacts[nodeId];
    if (existing == null) {
      return Err(
        IdentityFailure(
          code: 'contact_not_found',
          message: 'No contact with node id $nodeId',
        ),
      );
    }
    final updated = existing.copyWith(trustLevel: level);
    _contacts[nodeId] = updated;
    return Ok(updated);
  }

  @override
  Future<Result<bool>> remove(String nodeId) async {
    return Ok(_contacts.remove(nodeId) != null);
  }
}
