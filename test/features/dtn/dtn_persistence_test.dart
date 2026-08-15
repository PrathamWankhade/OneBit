import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/dao/dtn_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/features/dtn/data/dtn_row_mapper.dart';
import 'package:onebit/features/dtn/data/sqlite_dtn_persistence.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';
import 'package:onebit/features/dtn/domain/dtn_priority.dart';

import '../../core/database/support/database_support.dart';

void main() {
  late OneBitDatabase db;
  late SqliteDtnPersistence persistence;

  setUp(() async {
    db = await openInMemoryDb();
    persistence = SqliteDtnPersistence(DtnDao(db));
  });

  tearDown(() => db.close());

  DtnPacket sample(String id, {DtnPacketState state = DtnPacketState.queued}) {
    final now = DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);
    return DtnPacket(
      packetId: id,
      source: 'node-a',
      destination: 'node-b',
      payload: 'packet body'.codeUnits,
      priority: DtnPriority.high,
      direction: DtnDirection.outbound,
      ttlSeconds: 600,
      createdAt: now,
      expiresAt: now.add(const Duration(seconds: 600)),
      state: state,
      attemptCount: state == DtnPacketState.retrying ? 2 : 0,
    );
  }

  test('upsert + loadAll round-trips every field including payload', () async {
    await persistence.upsert(sample('p1'));
    final loaded = await persistence.loadAll();
    expect(loaded, hasLength(1));
    final row = loaded.single;
    expect(row.packetId, 'p1');
    expect(row.priority, DtnPriority.high);
    expect(row.payload, 'packet body'.codeUnits);
    expect(row.state, DtnPacketState.queued);
  });

  test('upsert overwrites (idempotent per packet id)', () async {
    await persistence.upsert(sample('p1', state: DtnPacketState.queued));
    await persistence.upsert(sample('p1', state: DtnPacketState.delivered));
    final loaded = await persistence.loadAll();
    expect(loaded, hasLength(1));
    expect(loaded.single.state, DtnPacketState.delivered);
  });

  test('delete removes the row', () async {
    await persistence.upsert(sample('p1'));
    await persistence.upsert(sample('p2'));
    await persistence.deletePacket('p1');
    final loaded = await persistence.loadAll();
    expect(loaded.map((p) => p.packetId), ['p2']);
  });

  test('row mapper is symmetric (toRow → toPacket preserves data)', () {
    final packet = sample('p1', state: DtnPacketState.retrying);
    final back = DtnRowMapper.toPacket(DtnRowMapper.toRow(packet));
    expect(back.packetId, packet.packetId);
    expect(back.priority, packet.priority);
    expect(back.direction, packet.direction);
    expect(back.state, packet.state);
    expect(back.attemptCount, packet.attemptCount);
    expect(back.expiresAt, packet.expiresAt);
    expect(back.payload, packet.payload);
  });

  test(
    'an expired envelope is loadable (pruning is a recovery concern)',
    () async {
      final now = DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);
      final expired = DtnPacket(
        packetId: 'p-old',
        source: 'a',
        destination: 'b',
        payload: const [],
        priority: DtnPriority.normal,
        direction: DtnDirection.outbound,
        ttlSeconds: 60,
        createdAt: now.subtract(const Duration(hours: 2)),
        expiresAt: now.subtract(const Duration(hours: 1)),
      );
      await persistence.upsert(expired);
      expect((await persistence.loadAll()).single.packetId, 'p-old');
    },
  );
}
