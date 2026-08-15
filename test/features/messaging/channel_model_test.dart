import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/messaging/domain/channels/channel.dart';
import 'package:onebit/features/messaging/domain/channels/channel_settings.dart';
import 'package:onebit/features/messaging/domain/channels/channel_sort.dart';
import 'package:onebit/features/messaging/domain/channels/channel_type.dart';
import 'package:onebit/features/messaging/domain/channels/conversation_summary.dart';
import 'package:onebit/features/messaging/domain/channels/pinned_message.dart';

ConversationSummary summary(
  String id, {
  String title = 't',
  bool pinned = false,
  int unread = 0,
  DateTime? at,
}) => ConversationSummary(
  channelId: id,
  type: ChannelType.private,
  title: title,
  pinned: pinned,
  unreadCount: unread,
  lastActivityAt: at,
);

void main() {
  group('Channel', () {
    test('is immutable and identifies by id', () {
      final a = Channel(
        channelId: 'c1',
        type: ChannelType.private,
        title: 'Alice',
        peer: 'node-a',
        settings: const ChannelSettings(),
        summary: summary('c1'),
      );
      final b = a.copyWith(title: 'Renamed');
      expect(b.title, 'Renamed');
      expect(a.title, 'Alice');
      expect(
        a ==
            Channel(
              channelId: 'c1',
              type: ChannelType.private,
              title: 'X',
              settings: const ChannelSettings(),
              summary: summary('c1'),
            ),
        isTrue,
      );
    });

    test('channel types are declared for future phases', () {
      expect(
        ChannelType.values,
        containsAll([
          ChannelType.private,
          ChannelType.group,
          ChannelType.broadcast,
          ChannelType.emergency,
          ChannelType.developer,
        ]),
      );
    });
  });

  group('ChannelSettings', () {
    test('mute without window is effective forever', () {
      const settings = ChannelSettings(muted: true);
      expect(settings.isEffectivelyMuted, isTrue);
    });

    test('mute until in the past is ineffective now', () {
      final settings = ChannelSettings(
        muted: true,
        mutedUntil: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(settings.isEffectivelyMuted, isFalse);
    });

    test('copyWith keeps unset fields', () {
      const a = ChannelSettings(muted: true);
      final b = a.copyWith(
        notificationPreference: ChannelNotificationPreference.none,
      );
      expect(b.muted, isTrue);
      expect(b.notificationPreference, ChannelNotificationPreference.none);
    });
  });

  group('ConversationSorter', () {
    test('pins always float first', () {
      final list = [
        summary('active', at: DateTime(2026, 1, 2)),
        summary('pinned', pinned: true, at: DateTime(2026, 1, 1)),
      ];
      final sorted = ConversationSorter.sort(list);
      expect(sorted.first.channelId, 'pinned');
    });

    test('sorts by last activity within a group', () {
      final list = [
        summary('old', at: DateTime(2026, 1, 1)),
        summary('new', at: DateTime(2026, 1, 3)),
        summary('mid', at: DateTime(2026, 1, 2)),
      ];
      final sorted = ConversationSorter.sort(list);
      expect(sorted.map((s) => s.channelId), ['new', 'mid', 'old']);
    });

    test('sorts by title alphabetically', () {
      final list = [
        summary('a', title: 'Zebra'),
        summary('b', title: 'apple'),
        summary('c', title: 'Mango'),
      ];
      final sorted = ConversationSorter.sort(list, by: ConversationSort.title);
      expect(sorted.map((s) => s.title), ['apple', 'Mango', 'Zebra']);
    });

    test('sorts by unread count descending', () {
      final list = [
        summary('a', unread: 1),
        summary('b', unread: 9),
        summary('c', unread: 4),
      ];
      final sorted = ConversationSorter.sort(list, by: ConversationSort.unread);
      expect(sorted.map((s) => s.unreadCount), [9, 4, 1]);
    });
  });

  group('PinnedMessage', () {
    test('carries position metadata', () {
      final at = DateTime(2026, 1, 1);
      final pinned = PinnedMessage(
        channelId: 'c',
        messageId: 'm',
        pinnedBy: 'n',
        pinnedAt: at,
      );
      expect(pinned.messageId, 'm');
      expect(pinned.pinnedAt, at);
    });
  });
}
