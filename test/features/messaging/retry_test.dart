import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';

import 'support/messaging_node.dart';

void main() {
  group('retry path', () {
    late MessagingNode node;

    setUp(() async {
      node = MessagingNode('node-a');
      await node.boot();
    });

    tearDown(() => node.dispose());

    test('retry re-queues a failed message with a fresh envelope', () async {
      final channelId = await node.openChannel('node-b');

      // Force the store to fail so the outbox parks the message as failed.
      node.dtn.onStore = (_) => throw const FormatException('offline');
      final failed = await node.engine.send(
        channelId,
        'boom',
        clientId: 'boom-msg',
      );
      expect(failed.isErr, isTrue);

      final afterFailure = (await node.engine.messages.getMessage(
        'boom-msg',
      )).value!;
      expect(afterFailure.status, MessageStatus.failed);

      // Network returns: retry re-stores the message under a fresh envelope.
      node.dtn.onStore = null;
      final retried = await node.engine.retry(afterFailure.messageId);
      expect(retried.isOk, isTrue, reason: '${retried.failure}');
      expect(retried.value!.status, MessageStatus.waiting);
      // The first attempt also recorded its packet before the seam threw, so
      // the store saw exactly two envelopes: the failed attempt + the retry.
      expect(node.dtn.stored, hasLength(2));
      expect(
        node.dtn.stored.last.packetId,
        isNot(node.dtn.stored.first.packetId),
      );
    });

    test('retry of an already-delivered message is rejected', () async {
      final channelId = await node.openChannel('node-b');
      final sent = (await node.engine.sendText(channelId, 'gone')).value!;
      node.deliverReceipt(
        messageId: sent.messageId,
        node: 'node-b',
        isRead: false,
      );
      await pumpUntil(() async {
        final m = (await node.engine.messages.getMessage(
          sent.messageId,
        )).value!;
        return m.status == MessageStatus.delivered;
      });
      final retried = await node.engine.retry(sent.messageId);
      expect(retried.isErr, isTrue);
      expect(retried.failure.toString(), contains('queued/failed'));
    });

    test('retry of an unknown message fails with not-found', () async {
      final retried = await node.engine.retry('ghost-message');
      expect(retried.isErr, isTrue);
    });
  });
}
