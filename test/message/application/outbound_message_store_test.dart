import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/message/application/outbound_message_store.dart';
import 'package:onebit/features/message/models/message_id.dart';
import 'package:onebit/features/message/models/onebit_message.dart';

void main() {
  OutboundMessageStore createStore() => OutboundMessageStore();

  OutboundMessage makeMessage({
    String? destinationPeerId,
    String? text,
  }) {
    final now = DateTime.now().toUtc();
    return OutboundMessage(
      message: OneBitMessage(
        id: MessageId(),
        sourcePeerId: 'aa' * 32,
        destinationPeerId: destinationPeerId ?? ('bb' * 32),
        createdAt: now,
        payloadSizeBytes: (text ?? 'hi').length,
      ),
      text: text ?? 'hi',
      createdAt: now,
    );
  }

  group('OutboundMessageStore', () {
    test('starts empty', () {
      final store = createStore();
      expect(store.isEmpty, isTrue);
      expect(store.length, equals(0));
      expect(store.all, isEmpty);
    });

    test('add and getById', () {
      final store = createStore();
      final msg = makeMessage();
      store.add(msg);

      expect(store.length, equals(1));
      expect(store.getById(msg.id), equals(msg));
    });

    test('getByDestination returns messages for that peer', () {
      final store = createStore();
      final peerA = 'aa' * 32;
      final peerB = 'bb' * 32;

      final msg1 = makeMessage(destinationPeerId: peerA);
      final msg2 = makeMessage(destinationPeerId: peerA);
      final msg3 = makeMessage(destinationPeerId: peerB);
      store.add(msg1);
      store.add(msg2);
      store.add(msg3);

      expect(store.getByDestination(peerA).length, equals(2));
      expect(store.getByDestination(peerB).length, equals(1));
      expect(store.getByDestination('cc' * 32), isEmpty);
    });

    test('all returns all messages', () {
      final store = createStore();
      final msg1 = makeMessage();
      final msg2 = makeMessage();
      store.add(msg1);
      store.add(msg2);

      expect(store.all.length, equals(2));
    });

    test('contains returns true for existing message', () {
      final store = createStore();
      final msg = makeMessage();
      store.add(msg);

      expect(store.contains(msg.id), isTrue);
    });

    test('contains returns false for missing message', () {
      final store = createStore();
      final msg = makeMessage();

      expect(store.contains(msg.id), isFalse);
    });

    test('getById returns null for missing message', () {
      final store = createStore();
      expect(store.getById(MessageId()), isNull);
    });

    test('clear removes all messages', () {
      final store = createStore();
      store.add(makeMessage());
      store.add(makeMessage());
      store.clear();

      expect(store.isEmpty, isTrue);
      expect(store.length, equals(0));
    });

    test('getById returns correct message', () {
      final store = createStore();
      final msg = makeMessage(text: 'hello');
      store.add(msg);

      final retrieved = store.getById(msg.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.text, equals('hello'));
    });

    test('multiple destinations', () {
      final store = createStore();
      final peerA = 'aa' * 32;
      final peerB = 'bb' * 32;

      store.add(makeMessage(destinationPeerId: peerA));
      store.add(makeMessage(destinationPeerId: peerB));
      store.add(makeMessage(destinationPeerId: peerA));

      expect(store.all.length, equals(3));
      expect(store.getByDestination(peerA).length, equals(2));
      expect(store.getByDestination(peerB).length, equals(1));
    });
  });

  group('OutboundMessage', () {
    test('exposes message fields', () {
      final now = DateTime.now().toUtc();
      final message = OneBitMessage(
        id: MessageId(),
        sourcePeerId: 'aa' * 32,
        destinationPeerId: 'bb' * 32,
        createdAt: now,
      );
      final outbound = OutboundMessage(
        message: message,
        text: 'hello',
        createdAt: now,
      );

      expect(outbound.id, equals(message.id));
      expect(outbound.sourcePeerId, equals('aa' * 32));
      expect(outbound.destinationPeerId, equals('bb' * 32));
      expect(outbound.text, equals('hello'));
      expect(outbound.createdAt, equals(now));
    });
  });
}
