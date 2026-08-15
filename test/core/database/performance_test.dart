import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/dao/message_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/query/page_request.dart';
import 'package:onebit/core/database/tables/enums.dart';

import 'support/database_support.dart';

void main() {
  late OneBitDatabase db;
  late MessageDao message;

  final start = DateTime(2026, 1, 1);

  setUp(() async {
    db = await openInMemoryDb();
    message = MessageDao(db);
    await db
        .into(db.channels)
        .insert(
          ChannelsCompanion.insert(
            channelId: 'ch-1',
            type: ChannelType.direct,
            createdAt: start,
            updatedAt: start,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  MessageRow row(int i) => MessageRow(
    messageId: 'm-$i',
    channelId: 'ch-1',
    sender: 'node-${i % 10}',
    timestamp: start.add(Duration(seconds: i)),
    encryptedPayload: Uint8List.fromList(List.generate(256, (b) => b % 251)),
    messageType: MessageType.text,
    status: MessageStatus.sent,
    forwarded: false,
    edited: false,
    deleted: false,
    priority: PriorityLevel.normal,
    version: 1,
    sequence: i,
    packetOrder: 0,
    attemptCount: 0,
    verified: false,
    starred: false,
  );

  test('bulk insert 10k messages stays under 30s', () async {
    final sw = Stopwatch()..start();
    await message.insertAllMessages(List.generate(10000, row));
    sw.stop();

    expect(await message.countMessages(channelId: 'ch-1'), 10000);
    expect(sw.elapsed, lessThan(const Duration(seconds: 30)));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('paging 10k messages traverses all pages', () async {
    await message.insertAllMessages(List.generate(10000, row));

    var seen = 0;
    var request = const PageRequest(limit: 500);
    var guard = 0;
    while (guard++ < 100) {
      final page = await message.pageChannelMessages('ch-1', request: request);
      seen += page.items.length;
      if (!page.hasMore) {
        break;
      }
      request = request.next();
    }

    expect(seen, 10000);
    expect(await message.countMessages(), 10000);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('watch stream stays responsive with 10k rows', () async {
    await message.insertAllMessages(List.generate(10000, row));
    final first = await message
        .watchChannelMessages('ch-1', limit: 10)
        .first
        .timeout(const Duration(seconds: 5));
    expect(first, hasLength(10));
  });
}
