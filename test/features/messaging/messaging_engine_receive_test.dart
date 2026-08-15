import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';
import 'package:onebit/features/messaging/domain/notifications/notification.dart';

import 'support/messaging_node.dart';

void main() {
  group('MessagingEngine inbound', () {
    late MessagingNode node;

    setUp(() async {
      node = MessagingNode('node-b');
      await node.boot();
    });

    tearDown(() => node.dispose());

    test('stores a foreign message, bumps unread and notifies', () async {
      final channelId = await node.openChannel('node-a');

      node.deliverMessagePayload(
        node.encodeOutbound(
          MessageLike(
            messageId: 'm-1',
            channelId: channelId,
            sender: 'node-a',
            receiver: 'node-b',
            body: 'hello from a',
            timestamp: DateTime.now(),
          ),
        ),
      );

      await pumpUntil(() async {
        final m = (await node.engine.messages.getMessage('m-1')).value;
        return m != null;
      });

      final stored = (await node.engine.messages.getMessage('m-1')).value!;
      expect(stored.body, 'hello from a');
      expect(stored.sender, 'node-a');

      // Unread bumped once.
      final summaries = (await node.channels.listSummaries()).value!;
      final summary = summaries.firstWhere((s) => s.channelId == channelId);
      expect(summary.unreadCount, 1);

      // Notification emitted.
      await pumpUntil(() async {
        final page = (await node.engine.notifications.page(limit: 5)).value;
        return page != null && page.items.isNotEmpty;
      });
      final page = (await node.engine.notifications.page(limit: 5)).value!;
      expect(page.items.first.kind, NotificationKind.messageReceived);
    });

    test('delivery receipt is sent back to the sender', () async {
      final channelId = await node.openChannel('node-a');

      node.deliverMessagePayload(
        node.encodeOutbound(
          MessageLike(
            messageId: 'm-2',
            channelId: channelId,
            sender: 'node-a',
            receiver: 'node-b',
            body: 'ping',
            timestamp: DateTime.now(),
          ),
        ),
      );

      await pumpUntil(
        () => node.dtn.stored.any(
          (p) =>
              p.direction == DtnDirection.outbound && p.destination == 'node-a',
        ),
        reason: 'no receipt stored',
      );
      final receipt = node.dtn.stored.firstWhere(
        (p) => p.direction == DtnDirection.outbound,
      );
      expect(receipt.source, 'node-b');
    });

    test('duplicate messages are dropped', () async {
      final channelId = await node.openChannel('node-a');
      final payload = node.encodeOutbound(
        MessageLike(
          messageId: 'm-3',
          channelId: channelId,
          sender: 'node-a',
          receiver: 'node-b',
          body: 'double',
          timestamp: DateTime.now(),
        ),
      );

      node.deliverMessagePayload(payload);
      await pumpUntil(() async {
        return (await node.engine.messages.getMessage('m-3')).value != null;
      });

      // Second copy arrives again.
      node.deliverMessagePayload(payload);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final count = (await node.engine.messages.pageChannel(
        channelId,
        limit: 10,
      )).value!.items.length;
      expect(count, 1);
    });

    test('delivery + read receipts update the outbound status', () async {
      final channelId = await node.openChannel('peer-a');
      final sent = (await node.engine.sendText(
        channelId,
        'status check',
      )).value!;

      node.deliverReceipt(
        messageId: sent.messageId,
        node: 'peer-a',
        isRead: false,
      );
      await pumpUntil(
        () async =>
            (await node.engine.messages.getMessage(
              sent.messageId,
            )).value!.status ==
            MessageStatus.delivered,
      );

      node.deliverReceipt(
        messageId: sent.messageId,
        node: 'peer-a',
        isRead: true,
      );
      await pumpUntil(
        () async =>
            (await node.engine.messages.getMessage(
              sent.messageId,
            )).value!.status ==
            MessageStatus.read,
      );
      final readReceipts =
          (await node.engine.receipts.readFor(sent.messageId)).value ?? [];
      expect(readReceipts, hasLength(1));
      expect(readReceipts.single.node, 'peer-a');
    });

    test('typing beacons drive the presence engine', () async {
      final channelId = await node.openChannel('node-a');
      node.deliverTyping(
        channelId: channelId,
        node: 'node-a',
        state: 'started',
      );
      await pumpUntil(() => node.engine.typing.isTyping(channelId, 'node-a'));

      node.deliverTyping(
        channelId: channelId,
        node: 'node-a',
        state: 'stopped',
      );
      await pumpUntil(() => !node.engine.typing.isTyping(channelId, 'node-a'));
    });
  });
}
