import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/crypto/identity/node_id.dart';
import 'package:onebit/features/identity/data/in_memory_trust_contact_repository.dart';
import 'package:onebit/features/identity/domain/trust_contact.dart';
import 'package:onebit/features/identity/domain/trust_level.dart';

void main() {
  late InMemoryTrustContactRepository repository;

  setUp(() {
    repository = InMemoryTrustContactRepository();
  });

  TrustContact contact({
    String displayName = 'Bob',
    TrustLevel level = TrustLevel.known,
  }) => TrustContact(
    nodeId: NodeId.parse('NODE-7A3F-91D2'),
    displayName: displayName,
    fingerprintHex: 'a' * 64,
    ed25519PublicKey: Uint8List(32),
    x25519PublicKey: Uint8List(32),
    trustLevel: level,
  );

  group('InMemoryTrustContactRepository', () {
    test('starts empty', () async {
      expect((await repository.loadContacts()).value, isEmpty);
    });

    test('find returns null for an unknown node', () async {
      expect((await repository.find('NODE-0000-0000')).value, isNull);
    });

    test('upsert adds a contact with a first-seen timestamp', () async {
      final result = await repository.upsert(contact());
      expect(result.isOk, isTrue);
      expect(result.value!.firstSeenAt, isNotNull);
      expect(result.value!.lastSeenAt, isNull);
      expect((await repository.loadContacts()).value, hasLength(1));
    });

    test('upsert of an existing node merges without duplication', () async {
      await repository.upsert(contact());
      final updated = await repository.upsert(
        contact(displayName: 'Bobby', level: TrustLevel.verified),
      );
      expect(updated.value!.displayName, 'Bobby');
      expect(updated.value!.trustLevel, TrustLevel.verified);
      expect(updated.value!.firstSeenAt, isNotNull);
      expect(updated.value!.lastSeenAt, isNotNull);
      expect((await repository.loadContacts()).value, hasLength(1));
    });

    test('setTrustLevel updates the posture', () async {
      await repository.upsert(contact());
      final result = await repository.setTrustLevel(
        nodeId: 'NODE-7A3F-91D2',
        level: TrustLevel.verified,
      );
      expect(result.isOk, isTrue);
      expect(result.value!.trustLevel, TrustLevel.verified);
    });

    test('setTrustLevel on a missing contact fails', () async {
      final result = await repository.setTrustLevel(
        nodeId: 'NODE-0000-0000',
        level: TrustLevel.blocked,
      );
      expect(result.isErr, isTrue);
    });

    test('remove deletes the contact', () async {
      await repository.upsert(contact());
      expect((await repository.remove('NODE-7A3F-91D2')).value, isTrue);
      expect((await repository.loadContacts()).value, isEmpty);
      expect((await repository.remove('NODE-7A3F-91D2')).value, isFalse);
    });

    test('contacts round-trip through JSON', () async {
      await repository.upsert(
        contact(displayName: 'Bob', level: TrustLevel.blocked),
      );
      final loaded = (await repository.loadContacts()).value!.single;
      final restored = TrustContact.fromJson(loaded.toJson());
      expect(restored.nodeId, loaded.nodeId);
      expect(restored.displayName, 'Bob');
      expect(restored.trustLevel, TrustLevel.blocked);
      expect(restored.ed25519PublicKey, loaded.ed25519PublicKey);
    });
  });
}
