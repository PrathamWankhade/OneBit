import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';

import 'support/messaging_node.dart';

/// Polls until [condition] holds or the deadline passes.
Future<void> pumpUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timeout${reason == null ? '' : ': $reason'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

void main() {
  group('MessagingEngine.send', () {
    late MessagingNode node;

    setUp(() async {
      node = MessagingNode('node-a');
      await node.boot();
    });

    tearDown(() => node.dispose());

    test('composes, persists and enqueues a text message', () async {
      final channelId = await node.openChannel('node-b');

      final result = await node.engine.sendText(channelId, 'hello mesh');
      expect(result.isOk, isTrue, reason: '${result.failure}');
      final message = result.value!;

      expect(message.body, 'hello mesh');
      expect(message.sender, 'node-a');
      expect(message.receiver, 'node-b');
      expect(message.status, MessageStatus.waiting);
      expect(message.sequence, greaterThan(0));
      expect(message.metadata.packetId, isNotNull);

      // One envelope stored on the seam.
      expect(node.dtn.stored, hasLength(1));
      // Envelope encoded and sent to the peer.
      final packet = node.dtn.stored.single;
      expect(packet.source, 'node-a');
      expect(packet.destination, 'node-b');
      expect(packet.payload, isNotEmpty);
    });

    test('rejects an empty body', () async {
      final channelId = await node.openChannel('node-b');
      final result = await node.engine.sendText(channelId, '   ');
      expect(result.isErr, isTrue);
      expect(result.failure!.toString(), contains('blank'));
      expect(node.dtn.stored, isEmpty);
    });

    test('rejects a send to an unknown channel', () async {
      final result = await node.engine.sendText('nope', 'hello');
      expect(result.isErr, isTrue);
      expect(node.dtn.stored, isEmpty);
    });

    test('is idempotent with a stable clientId', () async {
      final channelId = await node.openChannel('node-b');

      final first = await node.engine.send(
        channelId,
        'hello',
        clientId: 'client-key-1',
      );
      expect(first.isOk, isTrue);

      final second = await node.engine.send(
        channelId,
        'hello',
        clientId: 'client-key-1',
      );
      expect(second.isOk, isTrue);
      expect(second.value!.messageId, first.value!.messageId);
      // compose is idempotent; the outbox reuses the waiting packet.
      expect(node.dtn.stored, hasLength(1));
    });

    test('cancels an enqueued message', () async {
      final channelId = await node.openChannel('node-b');
      final sent = await node.engine.sendText(channelId, 'bye');
      final messageId = sent.value!.messageId;

      final cancelled = await node.engine.cancel(messageId);
      expect(cancelled.isOk, isTrue);

      final after = (await node.engine.messages.getMessage(messageId)).value!;
      expect(after.status, MessageStatus.failed);
      expect(node.dtn.cancelled, hasLength(1));
    });
  });
}
