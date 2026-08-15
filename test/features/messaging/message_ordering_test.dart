import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_ordering.dart';

Message msg(
  String id, {
  required DateTime timestamp,
  int sequence = 0,
  int packetOrder = 0,
}) => Message(
  messageId: id,
  channelId: 'c',
  sender: 'node-a',
  timestamp: timestamp,
  sequence: sequence,
  packetOrder: packetOrder,
);

void main() {
  group('MessageOrderKey', () {
    test('orders by timestamp first', () {
      final old = MessageOrderKey.of(
        msg('old', timestamp: DateTime(2026, 1, 1)),
      );
      final fresh = MessageOrderKey.of(
        msg('new', timestamp: DateTime(2026, 1, 2)),
      );
      expect(old.isOlderThan(fresh), isTrue);
      expect(fresh.isOlderThan(old), isFalse);
    });

    test('breaks timestamp ties by sequence', () {
      final a = MessageOrderKey.of(
        msg('a', timestamp: DateTime(2026, 1, 1), sequence: 1),
      );
      final b = MessageOrderKey.of(
        msg('b', timestamp: DateTime(2026, 1, 1), sequence: 2),
      );
      expect(a.compareTo(b) < 0, isTrue);
    });

    test('breaks sequence ties by packetOrder', () {
      final a = MessageOrderKey.of(
        msg('a', timestamp: DateTime(2026, 1, 1), sequence: 1, packetOrder: 5),
      );
      final b = MessageOrderKey.of(
        msg('b', timestamp: DateTime(2026, 1, 1), sequence: 1, packetOrder: 9),
      );
      expect(a.compareTo(b) < 0, isTrue);
    });

    test('falls back to bytewise message id for a strict total order', () {
      final a = MessageOrderKey.of(msg('aaa', timestamp: DateTime(2026, 1, 1)));
      final b = MessageOrderKey.of(msg('bbb', timestamp: DateTime(2026, 1, 1)));
      expect(a.compareTo(b) != 0, isTrue);
    });

    test('equality mirrors compareTo', () {
      final a = MessageOrderKey.of(
        msg('m', timestamp: DateTime(2026, 1, 1), sequence: 2),
      );
      final b = MessageOrderKey.of(
        msg('m', timestamp: DateTime(2026, 1, 1), sequence: 2),
      );
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('OrderingEngine', () {
    test('sorts a delayed batch into stable timeline order', () {
      final base = DateTime(2026, 1, 1, 10);
      final delayed = List.generate(
        50,
        (i) => msg('late-$i', timestamp: base.add(Duration(hours: i))),
      )..shuffle();
      final sorted = OrderingEngine.sortTimeline(delayed);
      for (var i = 1; i < sorted.length; i++) {
        expect(
          OrderingEngine.compareMessages(sorted[i - 1], sorted[i]) <= 0,
          isTrue,
          reason: 'timeline out of order at $i',
        );
      }
    });

    test('conflict resolution prefers origin-assigned sequence', () {
      final origin = msg(
        'origin',
        timestamp: DateTime(2026, 1, 1),
        sequence: 7,
      );
      final foreign = msg(
        'foreign',
        timestamp: DateTime(2026, 1, 1),
        sequence: 0,
        packetOrder: 999,
      );
      final resolved = OrderingEngine.resolveConflict(foreign, origin);
      expect(resolved.messageId, 'origin');
    });

    test('resolveConflict is deterministic both ways', () {
      final a = msg('a', timestamp: DateTime(2026, 1, 1), sequence: 3);
      final b = msg('b', timestamp: DateTime(2026, 1, 1), sequence: 3);
      final forward = OrderingEngine.resolveConflict(a, b);
      final backward = OrderingEngine.resolveConflict(b, a);
      expect(forward.messageId, backward.messageId);
    });
  });

  group('TimelineCursor / MessagePage', () {
    test('page carries ascending items and a cursor to page older', () {
      final base = DateTime(2026, 1, 1);
      final items = List.generate(
        25,
        (i) => msg('m-$i', timestamp: base.add(Duration(minutes: i))),
      );
      final cursor = TimelineCursor.after(items.first);
      expect(cursor.key.messageId, 'm-0');
      final page = MessagePage(items: items, cursor: cursor, hasMore: true);
      expect(page.itemCount, 25);
    });

    test('end page is empty and terminal', () {
      expect(MessagePage.end.items, isEmpty);
      expect(MessagePage.end.hasMore, isFalse);
    });
  });
}
