import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';

import 'support/messaging_node.dart';

void main() {
  /// Full loop, node A -> node B:
  /// send -> wire -> store -> auto delivery receipt -> A marks delivered,
  /// A marks read -> read receipt back -> B marks read.
  test('two nodes: send, receive, delivery + read receipts', () async {
    final a = MessagingNode('node-a');
    final b = MessagingNode('node-b');
    await a.boot();
    await b.boot();

    // Wire the seams together: everything A stores lands on B's inbound seam.
    a.dtn.onStore = b.dtn.deliver;
    b.dtn.onStore = a.dtn.deliver;

    String? channelIdA;
    String? channelIdB;
    await pumpUntil(() async {
      final ca = a.openChannel('node-b');
      final cb = b.openChannel('node-a');
      final [ra, rb] = await Future.wait([ca, cb]);
      channelIdA = ra;
      channelIdB = rb;
      return true;
    });

    // --- A sends ---------------------------------------------------------
    final sent = (await a.engine.sendText(
      channelIdA!,
      'crossing the seam',
    )).value!;
    expect(sent.status, MessageStatus.waiting);

    // --- B receives and auto-answers with a delivery receipt -------------
    await pumpUntil(() async {
      final m = (await b.engine.messages.getMessage(sent.messageId)).value;
      return m != null;
    }, reason: 'B never stored the message');

    // --- A applies the delivery receipt ---------------------------------
    await pumpUntil(
      () async =>
          (await a.engine.messages.getMessage(sent.messageId)).value!.status ==
          MessageStatus.delivered,
      reason: 'A never reached "delivered"',
    );

    // --- A reads, which mints read receipts back to B -------------------
    await a.engine.markChannelRead(channelIdA!);
    await pumpUntil(
      () async =>
          (await b.engine.messages.getMessage(sent.messageId)).value!.status ==
          MessageStatus.read,
      reason: 'B never saw "read"',
    );

    // B's delivery receipt is persisted on A for the message.
    final deliveriesForA =
        (await a.engine.receipts.deliveriesFor(sent.messageId)).value ?? [];
    expect(deliveriesForA, hasLength(1));
    expect(deliveriesForA.single.node, 'node-b');

    // B's unread stays at 1 because B has not locally marked the channel as
    // read — only the local read action resets it.
    final summariesB = (await b.channels.listSummaries()).value!;
    final channelBSummary = summariesB.firstWhere(
      (s) => s.channelId == channelIdB,
    );
    expect(channelBSummary.unreadCount, 1);

    await a.dispose();
    await b.dispose();
  });
}
