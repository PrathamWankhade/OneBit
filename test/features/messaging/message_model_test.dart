import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_metadata.dart';
import 'package:onebit/features/messaging/domain/messages/message_priority.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';
import 'package:onebit/features/messaging/domain/messages/message_type.dart';

Message message({String id = 'm-1'}) => Message(
  messageId: id,
  channelId: 'channel-1',
  sender: 'node-a',
  receiver: 'node-b',
  timestamp: DateTime(2026, 1, 1),
);

void main() {
  group('Message', () {
    test('is immutable via copyWith', () {
      final a = message();
      final b = a.copyWith(body: 'edited', status: MessageStatus.read);
      expect(b.body, 'edited');
      expect(b.status, MessageStatus.read);
      expect(a.body, '');
      expect(a.status, MessageStatus.created);
    });

    test('copyWith keeps unset fields', () {
      final a = message()..toString();
      final b = a.copyWith(starred: true);
      expect(b.messageId, a.messageId);
      expect(b.channelId, a.channelId);
      expect(b.sender, a.sender);
      expect(b.receiver, a.receiver);
      expect(b.type, MessageType.text);
      expect(b.sequence, 0);
      expect(b.forwarded, false);
      expect(b.edited, false);
    });

    test('equality is by messageId', () {
      final a = message();
      expect(a, message());
      expect(a == message(id: 'other'), isFalse);
      expect(a.hashCode, message().hashCode);
    });

    test('defaults are lean (created/text/normal/version 1)', () {
      final m = message();
      expect(m.status, MessageStatus.created);
      expect(m.type, MessageType.text);
      expect(m.priority, MessagePriority.normal);
      expect(m.version, 1);
      expect(m.metadata, const MessageMetadata());
    });

    test('all message types are declared (future media/voice/file)', () {
      expect(
        MessageType.values,
        containsAll([
          MessageType.text,
          MessageType.markdown,
          MessageType.system,
          MessageType.notification,
          MessageType.identity,
          MessageType.handshake,
          MessageType.receipt,
          MessageType.developer,
          MessageType.media,
          MessageType.voice,
          MessageType.file,
        ]),
      );
    });

    test('status wire names round-trip through the persisted vocabulary', () {
      for (final status in MessageStatus.values) {
        expect(MessageStatus.fromWireName(status.wireName), status);
      }
      expect(MessageStatus.fromWireName('pending'), MessageStatus.queued);
      expect(MessageStatus.fromWireName('sent'), MessageStatus.relayed);
    });

    test('terminal/live classification', () {
      expect(MessageStatus.expired.isTerminal, isTrue);
      expect(MessageStatus.failed.isTerminal, isTrue);
      expect(MessageStatus.deleted.isTerminal, isTrue);
      expect(MessageStatus.delivered.isTerminal, isFalse);
      expect(MessageStatus.queued.isLive, isTrue);
      expect(MessageStatus.read.isLive, isTrue);
      expect(MessageStatus.failed.isLive, isFalse);
    });

    test('status ranks are forward monotonic', () {
      final ranks = MessageStatus.values.map((s) => s.rank).toList();
      expect(
        ranks,
        orderedEquals(
          List<int>.generate(MessageStatus.values.length, (i) => i),
        ),
      );
    });
  });
}
