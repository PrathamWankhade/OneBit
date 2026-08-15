import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_channel_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_message_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_receipt_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_type.dart';
import 'package:onebit/features/messaging/domain/delivery/delivery_receipt.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_ordering.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';
import 'package:onebit/features/messaging/domain/receipts/read_receipt.dart';

import 'support/messaging_node.dart' show pumpUntil;
import 'support/messaging_support.dart';

Message msg(
  String id, {
  required String channel,
  required DateTime timestamp,
}) => Message(
  messageId: id,
  channelId: channel,
  sender: 'node-a',
  receiver: 'node-b',
  timestamp: timestamp,
  status: MessageStatus.waiting,
);

void main() {
  group('SqliteReceiptRepository - delivery', () {
    late OneBitDatabase db;
    late SqliteReceiptRepository repo;
    late SqliteChannelRepository channels;
    late SqliteMessageRepository messages;
    late String channelId;

    setUp(() async {
      db = await openInMemoryDb();
      repo = SqliteReceiptRepository(db: db, logger: silentLogger);
      channels = SqliteChannelRepository(
        db: db,
        localNodeId: 'node-a',
        logger: silentLogger,
      );
      messages = SqliteMessageRepository(db: db, logger: silentLogger);
      channelId = (await channels.create(
        const CreateChannelParams(type: ChannelType.private, peer: 'node-b'),
      )).value!.channelId;
    });

    tearDown(() => db.close());

    test(
      'stores a delivery receipt and finds it by (messageId, node)',
      () async {
        await messages.insert(
          msg('m-1', channel: channelId, timestamp: DateTime(2026, 1, 1)),
        );
        final stored = (await repo.saveDelivery(
          DeliveryReceipt(
            receiptId: 'delivery:m-1:node-b',
            messageId: 'm-1',
            node: 'node-b',
            deliveredAt: DateTime(2026, 1, 2),
            state: DeliveryReceiptState.queued,
          ),
        )).value!;
        expect(stored.state, DeliveryReceiptState.queued);

        final found = (await repo.deliveryFor('m-1', 'node-b')).value!;
        expect(found.node, 'node-b');
        expect(found.messageId, 'm-1');
      },
    );

    test(
      'duplicate receipts for the same (messageId, node) are dropped',
      () async {
        await messages.insert(
          msg('m-1', channel: channelId, timestamp: DateTime(2026, 1, 1)),
        );
        await repo.saveDelivery(
          DeliveryReceipt(
            receiptId: 'delivery:m-1:node-b',
            messageId: 'm-1',
            node: 'node-b',
            deliveredAt: DateTime(2026, 1, 2),
          ),
        );
        final duplicate = (await repo.saveDelivery(
          DeliveryReceipt(
            receiptId: 'delivery:m-1:node-b',
            messageId: 'm-1',
            node: 'node-b',
            deliveredAt: DateTime(2026, 1, 3),
          ),
        )).value!;
        expect(duplicate.state, DeliveryReceiptState.duplicate);
        expect((await repo.deliveriesFor('m-1')).value, hasLength(1));
      },
    );

    test('advances the receipt lifecycle', () async {
      await messages.insert(
        msg('m-1', channel: channelId, timestamp: DateTime(2026, 1, 1)),
      );
      final receipt = (await repo.saveDelivery(
        DeliveryReceipt(
          receiptId: 'delivery:m-1:node-b',
          messageId: 'm-1',
          node: 'node-b',
          deliveredAt: DateTime(2026, 1, 2),
          state: DeliveryReceiptState.queued,
        ),
      )).value!;
      await repo.setDeliveryState(
        receipt.receiptId,
        state: DeliveryReceiptState.sent,
      );
      expect(
        (await repo.deliveryFor('m-1', 'node-b')).value!.state,
        DeliveryReceiptState.sent,
      );
    });
  });

  group('SqliteReceiptRepository - read', () {
    late OneBitDatabase db;
    late SqliteReceiptRepository repo;
    late SqliteChannelRepository channels;
    late SqliteMessageRepository messages;
    late String channelId;

    setUp(() async {
      db = await openInMemoryDb();
      repo = SqliteReceiptRepository(db: db, logger: silentLogger);
      channels = SqliteChannelRepository(
        db: db,
        localNodeId: 'node-a',
        logger: silentLogger,
      );
      messages = SqliteMessageRepository(db: db, logger: silentLogger);
      channelId = (await channels.create(
        const CreateChannelParams(type: ChannelType.private, peer: 'node-b'),
      )).value!.channelId;
    });

    tearDown(() => db.close());

    Future<void> storeOutbound(int count, {String sender = 'node-b'}) async {
      for (var i = 0; i < count; i++) {
        final stored = await messages.insert(
          Message(
            messageId: 'out-$i',
            channelId: channelId,
            sender: sender,
            receiver: sender == 'node-b' ? 'node-a' : 'node-b',
            timestamp: DateTime(2026, 1, 1, i + 9),
            status: MessageStatus.waiting,
          ),
        );
        // The cursor only advances `delivered`/`verified`/`sent` statuses.
        await messages.setStatus(
          stored.value!.messageId,
          MessageStatus.delivered,
        );
      }
    }

    test('records read receipts per (messageId, node, device)', () async {
      await messages.insert(
        msg('m-1', channel: channelId, timestamp: DateTime(2026, 1, 1)),
      );
      await repo.saveRead(
        ReadReceipt(
          receiptId: 'read:m-1:node-b:phone',
          messageId: 'm-1',
          node: 'node-b',
          device: 'phone',
          readAt: DateTime(2026, 1, 2),
        ),
      );
      final read = (await repo.readFor('m-1')).value!;
      expect(read, hasLength(1));
      expect(read.single.device, 'phone');

      final latest = (await repo.latestReadFor('m-1', 'node-b')).value;
      expect(latest, isNotNull);
    });

    test(
      'applyReadCursor generates one receipt per outbound message',
      () async {
        await storeOutbound(4);
        final target = (await messages.getMessage('out-3')).value!;
        final marked = (await repo.applyReadCursor(
          channelId: channelId,
          readerNode: 'node-b',
          through: MessageOrderKey.of(target),
          readAt: DateTime(2026, 1, 3),
          device: 'phone',
        )).value!;
        // Receipts are inserted for every message sent by the reader node;
        // the returned count is the number of statuses advanced.
        expect((await repo.readFor('out-0')).value, hasLength(1));
        expect((await repo.readFor('out-3')).value, hasLength(1));
        expect((await repo.readFor('out-3')).value!.single.node, 'node-b');
        expect(marked, 4);
      },
    );

    test('applyReadCursor ignores messages from other senders', () async {
      await storeOutbound(2);
      // one message from a third party stays untouched
      await messages.insert(
        msg(
          'foreign-1',
          channel: channelId,
          timestamp: DateTime(2026, 1, 1, 20),
        ),
      );
      final target = (await messages.getMessage('out-1')).value!;
      await repo.applyReadCursor(
        channelId: channelId,
        readerNode: 'node-b',
        through: MessageOrderKey.of(target),
      );
      expect((await repo.readFor('foreign-1')).value, isEmpty);
    });

    test('applyReadCursor is idempotent', () async {
      await storeOutbound(2);
      final target = (await messages.getMessage('out-1')).value!;
      final key = MessageOrderKey.of(target);
      await repo.applyReadCursor(
        channelId: channelId,
        readerNode: 'node-b',
        through: key,
      );
      await repo.applyReadCursor(
        channelId: channelId,
        readerNode: 'node-b',
        through: key,
      );
      expect((await repo.readFor('out-0')).value, hasLength(1));
      expect(await messages.countMessages(channelId: channelId), isNotNull);
    });

    test('readCursorForChannel returns the newest receipt per node', () async {
      await storeOutbound(3);
      final newest = (await messages.getMessage('out-2')).value!;
      await repo.applyReadCursor(
        channelId: channelId,
        readerNode: 'node-b',
        through: MessageOrderKey.of(newest),
      );
      final cursors = (await repo.readCursorForChannel(channelId)).value!;
      expect(cursors, hasLength(1));
      expect(cursors.single.messageId, 'out-2');
    });

    test('watchReadFor streams per-message read state', () async {
      await messages.insert(
        msg('m-1', channel: channelId, timestamp: DateTime(2026, 1, 1)),
      );
      final stream = repo.watchReadFor('m-1');
      final seen = <Result<List<ReadReceipt>>>[];
      final sub = stream.listen(seen.add);
      await repo.saveRead(
        ReadReceipt(
          receiptId: 'read:m-1:node-b',
          messageId: 'm-1',
          node: 'node-b',
          readAt: DateTime(2026, 1, 2),
        ),
      );
      // drift's watch() delivers its initial snapshot asynchronously, so we
      // wait until a snapshot carrying the receipt arrives.
      await pumpUntil(
        () => seen.isNotEmpty && seen.any((r) => (r.value ?? []).isNotEmpty),
      );
      await sub.cancel();
      expect(seen.any((r) => (r.value ?? []).length == 1), isTrue);
      expect(
        seen.any(
          (r) => (r.value ?? []).isNotEmpty && r.value!.single.node == 'node-b',
        ),
        isTrue,
      );
    });
  });
}
