import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/dao/channel_dao.dart';
import 'package:onebit/core/database/dao/identity_dao.dart';
import 'package:onebit/core/database/dao/message_dao.dart';
import 'package:onebit/core/database/dao/neighbor_dao.dart';
import 'package:onebit/core/database/dao/packet_dao.dart';
import 'package:onebit/core/database/dao/queue_dao.dart';
import 'package:onebit/core/database/dao/route_dao.dart';
import 'package:onebit/core/database/dao/session_dao.dart';
import 'package:onebit/core/database/dao/settings_dao.dart';
import 'package:onebit/core/database/dao/statistics_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/query/message_query.dart';
import 'package:onebit/core/database/query/page_request.dart';
import 'package:onebit/core/database/tables/enums.dart';

import 'support/database_support.dart';

void main() {
  late OneBitDatabase db;
  late IdentityDao identity;
  late ChannelDao channel;
  late MessageDao message;
  late NeighborDao neighbor;
  late PacketDao packet;
  late QueueDao queue;
  late RouteDao route;
  late SessionDao session;
  late SettingsDao settings;
  late StatisticsDao statistics;

  final now = DateTime.now();

  ChannelRow channelRow(String id) => ChannelRow(
    channelId: id,
    type: ChannelType.direct,
    createdAt: now,
    updatedAt: now,
    unreadCount: 0,
    archived: false,
    pinned: false,
    muted: false,
    lastSequence: 0,
    notificationPreference: 'all',
  );

  MessageRow messageRow(
    String id, {
    DateTime? at,
    MessageStatus status = MessageStatus.queued,
  }) => MessageRow(
    messageId: id,
    channelId: 'ch-1',
    sender: 'node-a',
    timestamp: at ?? now,
    encryptedPayload: Uint8List.fromList([1]),
    messageType: MessageType.text,
    status: status,
    forwarded: false,
    edited: false,
    deleted: false,
    priority: PriorityLevel.normal,
    version: 1,
    sequence: 0,
    packetOrder: 0,
    attemptCount: 0,
    verified: false,
    starred: false,
  );

  Future<void> initDaos() async {
    identity = IdentityDao(db);
    channel = ChannelDao(db);
    message = MessageDao(db);
    neighbor = NeighborDao(db);
    packet = PacketDao(db);
    queue = QueueDao(db);
    route = RouteDao(db);
    session = SessionDao(db);
    settings = SettingsDao(db);
    statistics = StatisticsDao(db);
    await channel.upsertChannel(channelRow('ch-1'));
  }

  setUp(() async {
    db = await openInMemoryDb();
    await initDaos();
  });

  tearDown(() async {
    await db.close();
  });

  group('identity DAO', () {
    test('upserts, reads, deletes and flags trust', () async {
      await identity.upsertIdentity(
        IdentityRow(
          nodeId: 'node-a',
          uuid: 'uuid-a',
          displayName: 'Alice',
          publicKey: Uint8List.fromList([1, 2, 3]),
          fingerprint: 'fp',
          createdAt: now,
          updatedAt: now,
          version: 1,
        ),
      );
      expect((await identity.getIdentity())?.nodeId, 'node-a');

      await identity.upsertTrustedNode(
        TrustedNodeRow(
          nodeId: 'node-a',
          trustStatus: TrustStatus.pending,
          verificationMethod: VerificationMethod.none,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await identity.setTrustStatus('node-a', TrustStatus.verified);
      await identity.setTrustedNickname('node-a', 'Al');
      final trusted = (await identity.getTrustedNode('node-a'))!;
      expect(trusted.trustStatus, TrustStatus.verified);
      expect(trusted.nickname, 'Al');

      await identity.upsertNodeProfile(
        NodeProfileRow(nodeId: 'node-a', firstSeen: now, lastSeen: now),
      );
      expect((await identity.listNodeProfiles()).single.nodeId, 'node-a');

      expect(await identity.deleteIdentity('node-a'), 1);
      expect(await identity.getIdentity(), isNull);
    });
  });

  group('channel DAO', () {
    test('lists channels, unread deltas via touchChannel', () async {
      await channel.upsertChannel(channelRow('ch-2'));
      await channel.touchChannel(
        'ch-2',
        lastMessageId: 'm-9',
        lastMessageAt: now,
        unreadDelta: 2,
      );
      final read = (await channel.getChannel('ch-2'))!;
      expect(read.unreadCount, 2);
      expect(read.lastMessageId, 'm-9');

      await channel.setUnreadCount('ch-2', 0);
      await channel.setPinned('ch-2', true);
      expect((await channel.getChannel('ch-2'))!.pinned, isTrue);

      await channel.setArchived('ch-2', true);
      expect(await channel.listChannels(), hasLength(1));
      expect(await channel.listChannels(includeArchived: true), hasLength(2));
    });

    test('typing events lifecycle', () async {
      await channel.insertTypingEvent(
        TypingEventsCompanion.insert(
          channelId: 'ch-1',
          node: 'node-b',
          kind: TypingKind.started,
          startedAt: now,
        ),
      );
      await channel.insertTypingEvent(
        TypingEventsCompanion.insert(
          channelId: 'ch-1',
          node: 'node-c',
          kind: TypingKind.started,
          startedAt: now,
        ),
      );
      expect(await channel.activeTyping(), hasLength(2));
      await channel.endTypingEvents('ch-1', 'node-b');
      expect((await channel.activeTyping()).single.node, 'node-c');
    });
  });

  group('message DAO', () {
    test('insert / get / status and paging with hasMore', () async {
      for (var i = 0; i < 5; i++) {
        await message.insertMessage(
          messageRow('m-$i', at: now.add(Duration(minutes: i))),
        );
      }

      final page = await message.pageChannelMessages(
        'ch-1',
        request: const PageRequest(limit: 3),
      );
      expect(page.items, hasLength(3));
      expect(page.hasMore, isTrue);
      expect(page.items.first.messageId, 'm-4');

      final next = await message.pageChannelMessages(
        'ch-1',
        request: const PageRequest(offset: 3, limit: 3),
      );
      expect(next.items, hasLength(2));
      expect(next.hasMore, isFalse);
      expect(next.nextOffset, 5);
    });

    test('before-cutoff paging', () async {
      await message.insertMessage(
        messageRow('old', at: now.subtract(const Duration(hours: 2))),
      );
      await message.insertMessage(messageRow('new', at: now));

      final page = await message.pageChannelMessages(
        'ch-1',
        before: now.subtract(const Duration(hours: 1)),
      );
      expect(page.items.map((m) => m.messageId), ['old']);
    });

    test('mark deleted and purge', () async {
      await message.insertMessage(messageRow('m-1'));
      await message.markDeleted('m-1');
      expect((await message.getMessage('m-1'))!.deleted, isTrue);
      await message.purgeDeleted(now.add(const Duration(days: 1)));
      expect(await message.getMessage('m-1'), isNull);
      expect(await message.countMessages(channelId: 'ch-1'), 0);
    });

    test('attachments, voice notes, receipts', () async {
      await message.insertMessage(messageRow('m-1'));
      await message.insertAttachment(
        AttachmentRow(
          attachmentId: 'a-1',
          messageId: 'm-1',
          kind: AttachmentKind.image,
          createdAt: now,
        ),
      );
      await message.insertVoiceNote(
        VoiceNoteRow(voiceNoteId: 'v-1', messageId: 'm-1', createdAt: now),
      );
      await message.insertDeliveryReceipt(
        DeliveryReceiptRow(
          receiptId: 'r-1',
          messageId: 'm-1',
          node: 'node-b',
          deliveredAt: now,
          state: ReceiptState.sent,
        ),
      );
      await message.insertReadReceipt(
        ReadReceiptRow(
          receiptId: 'rr-1',
          messageId: 'm-1',
          node: 'node-b',
          readAt: now,
          version: 1,
        ),
      );
      expect((await message.listAttachments('m-1')).single.attachmentId, 'a-1');
      expect((await message.getVoiceNote('v-1'))!.messageId, 'm-1');
      expect((await message.deliveryReceiptsFor('m-1')).single.node, 'node-b');
      expect((await message.readReceiptsFor('m-1')).single.node, 'node-b');
    });

    test('text search matches sender and message id only', () async {
      await message.insertMessage(
        MessageRow(
          messageId: 'm-1',
          channelId: 'ch-1',
          sender: 'node-alpha',
          timestamp: now,
          encryptedPayload: Uint8List.fromList([9]),
          messageType: MessageType.text,
          status: MessageStatus.queued,
          deleted: false,
          forwarded: false,
          edited: false,
          priority: PriorityLevel.normal,
          version: 1,
          sequence: 0,
          packetOrder: 0,
          attemptCount: 0,
          verified: false,
          starred: false,
        ),
      );
      await message.insertMessage(
        MessageRow(
          messageId: 'm-2',
          channelId: 'ch-1',
          sender: 'node-beta',
          timestamp: now,
          encryptedPayload: Uint8List.fromList([9]),
          messageType: MessageType.text,
          status: MessageStatus.queued,
          deleted: false,
          forwarded: false,
          edited: false,
          priority: PriorityLevel.normal,
          version: 1,
          sequence: 0,
          packetOrder: 0,
          attemptCount: 0,
          verified: false,
          starred: false,
        ),
      );

      expect(
        (await message.queryMessages(const MessageQuery(text: 'alph'))).items,
        hasLength(1),
      );
      expect(
        (await message.queryMessages(
          const MessageQuery(text: 'm-2'),
        )).items.single.messageId,
        'm-2',
      );
    });

    test('text search matches LIKE wildcards literally', () async {
      await message.insertMessage(messageRow('m-100%'));

      final wildcard = await message.queryMessages(
        const MessageQuery(text: '0%'),
      );
      expect(wildcard.items, hasLength(1));
      final underscore = await message.queryMessages(
        const MessageQuery(text: '_'),
      );
      expect(underscore.items, isEmpty);
      expect(
        (await message.queryMessages(const MessageQuery(text: '%'))).items,
        hasLength(1),
      );
    });
  });

  group('packet DAO', () {
    PacketRow packetRow(String id, {DateTime? expiresAt}) => PacketRow(
      packetId: id,
      packetType: PacketType.data,
      source: 'node-a',
      destination: 'node-x',
      ttl: 10,
      hopCount: 0,
      fragmentCount: 1,
      priority: PriorityLevel.normal,
      createdAt: now,
      encryptedPayload: Uint8List.fromList([1]),
      status: PacketStatus.pending,
      expiresAt: expiresAt,
    );

    test('inserts packet with fragments and tracks fragments', () async {
      await packet.insertPacketWithFragments(packetRow('p-1'), [
        PacketFragmentRow(
          fragmentId: 1,
          packetId: 'p-1',
          sequence: 0,
          payload: Uint8List.fromList([1, 2]),
          received: false,
        ),
        PacketFragmentRow(
          fragmentId: 2,
          packetId: 'p-1',
          sequence: 1,
          payload: Uint8List.fromList([3]),
          received: false,
        ),
      ]);
      expect(await packet.countMissingFragments('p-1'), 2);
      final fragments = await packet.fragmentsFor('p-1');
      await packet.markFragmentReceived(fragments.first.fragmentId);
      expect(await packet.countMissingFragments('p-1'), 1);
    });

    test('pendingPackets filters expired', () async {
      await packet.insertPacket(
        packetRow('p-live', expiresAt: now.add(const Duration(minutes: 5))),
      );
      await packet.insertPacket(
        packetRow(
          'p-dead',
          expiresAt: now.subtract(const Duration(minutes: 5)),
        ),
      );
      final pending = await packet.pendingPackets(now: now);
      expect(pending.map((p) => p.packetId), ['p-live']);
    });

    test('expirePackets finds overdue packets', () async {
      await packet.insertPacket(
        packetRow('p-1', expiresAt: now.subtract(const Duration(minutes: 1))),
      );
      final expired = await packet.expirePackets(now: now);
      expect(expired.map((p) => p.packetId), ['p-1']);
    });
  });

  group('queue DAO', () {
    test('pending → retry → relay lifecycle', () async {
      await queue.enqueuePending(
        PendingQueueRow(
          queueId: 1,
          entityType: 'message',
          entityId: 'm-1',
          priority: 0,
          enqueuedAt: now,
          attempts: 0,
        ),
      );
      await queue.enqueuePending(
        PendingQueueRow(
          queueId: 2,
          entityType: 'message',
          entityId: 'm-2',
          priority: 0,
          enqueuedAt: now,
          attempts: 0,
        ),
      );
      final drained = await queue.drainPending(
        now: now.add(const Duration(minutes: 1)),
      );
      expect(drained, hasLength(2));
      await queue.removePending(drained.first.queueId);

      await queue.enqueueRetry(
        RetryQueueRow(
          retryId: 0,
          entityType: 'message',
          entityId: 'm-1',
          attempts: 0,
          maxAttempts: 5,
          backoffMs: 1000,
          state: QueueState.queued,
          lastAttemptAt: now,
          nextAttemptAt: now.subtract(const Duration(seconds: 5)),
        ),
      );
      final due = await queue.dueRetries(now: now);
      expect(due, hasLength(1));
      await queue.updateRetryAttempts(
        due.first.retryId,
        attempts: 2,
        nextAttemptAt: now.add(const Duration(minutes: 1)),
        lastError: 'timeout',
      );
      await queue.markRetryFailed(due.first.retryId);

      await packet.insertPacket(
        PacketRow(
          packetId: 'p-1',
          packetType: PacketType.data,
          source: 'a',
          destination: 'b',
          ttl: 5,
          hopCount: 0,
          fragmentCount: 1,
          priority: PriorityLevel.normal,
          createdAt: now,
          encryptedPayload: Uint8List.fromList([1]),
          status: PacketStatus.pending,
        ),
      );
      await queue.enqueueRelay(
        'p-1',
        source: 'a',
        destination: 'b',
        hopsRemaining: 2,
      );
      final relay = (await queue.pendingRelays()).first;
      expect(relay.packetId, 'p-1');
      await queue.markRelayState(relay.relayId, RelayState.relayed);

      final snap = await queue.snapshot();
      expect(snap.pending, 1);
      expect(snap.retrying, 1);
      expect(snap.relaying, 1);
      expect(snap.total, 3);
    });
  });

  group('route DAO', () {
    test('upsert, bestRouteTo, pruneExpired', () async {
      await route.upsertRoute(
        RouteRow(
          destination: 'node-z',
          nextHop: 'node-m',
          hopCount: 2,
          quality: 0.8,
          lastUpdated: now,
          expiration: null,
        ),
      );
      await route.upsertRoute(
        RouteRow(
          destination: 'node-z',
          nextHop: 'node-n',
          hopCount: 1,
          quality: 0.5,
          lastUpdated: now,
          expiration: now.add(const Duration(minutes: 5)),
        ),
      );
      expect((await route.bestRouteTo('node-z'))!.nextHop, 'node-n');
      expect(await route.routesViaNextHop('node-n'), hasLength(1));

      await route.upsertRoute(
        RouteRow(
          destination: 'node-q',
          nextHop: 'node-n',
          hopCount: 3,
          quality: 0.2,
          lastUpdated: now,
          expiration: now.subtract(const Duration(minutes: 1)),
        ),
      );
      final pruned = await route.pruneExpired(now: now);
      expect(pruned.single.destination, 'node-q');
    });
  });

  group('session DAO', () {
    test('latest, keys, expiration', () async {
      for (var i = 0; i < 3; i++) {
        await session.upsertSession(
          SessionRow(
            sessionId: 's-$i',
            node: 'node-b',
            createdAt: now,
            updatedAt: now.add(Duration(minutes: i * 5)),
            state: SessionState.active,
            expiration: now.add(const Duration(hours: 1)),
          ),
        );
      }
      expect((await session.latestSessionForNode('node-b'))!.sessionId, 's-2');

      await session.insertSessionKey(
        SessionKeyRow(
          sessionKeyId: 'k-1',
          sessionId: 's-0',
          ratchetStep: 0,
          direction: SessionKeyDirection.outbound,
          keyMaterial: Uint8List.fromList([1]),
          createdAt: now,
          expiresAt: now.add(const Duration(days: 1)),
        ),
      );
      expect((await session.keyAtStep('s-0', 0))!.sessionKeyId, 'k-1');
      expect(
        (await session.keysForSession('s-0')).single.direction,
        SessionKeyDirection.outbound,
      );

      final expired = await session.expireSessions(
        now: now.add(const Duration(hours: 2)),
      );
      expect(expired, hasLength(3));
      expect((await session.getSession('s-0'))!.state, SessionState.expired);
    });
  });

  group('neighbor DAO', () {
    test('presence and stale pruning', () async {
      await neighbor.upsertNeighbor(
        NeighborRow(
          node: 'node-z',
          lastSeen: now.subtract(const Duration(minutes: 30)),
          status: NeighborStatus.connected,
          rssi: -70,
        ),
      );
      await neighbor.upsertNeighbor(
        NeighborRow(
          node: 'node-fresh',
          lastSeen: now,
          status: NeighborStatus.discovered,
        ),
      );
      await neighbor.updateNeighborStatus('node-z', NeighborStatus.stale);
      expect(
        (await neighbor.getNeighbor('node-z'))!.status,
        NeighborStatus.stale,
      );

      final pruned = await neighbor.pruneStale(
        now.subtract(const Duration(minutes: 5)),
      );
      expect(pruned.single.node, 'node-z');
      expect(await neighbor.countNeighbors(), 1);
    });
  });

  group('settings DAO', () {
    test('settings and metadata round-trip', () async {
      await settings.setSetting('theme', 'dark');
      await settings.setSetting('theme', 'light');
      expect(await settings.getSettingValue('theme'), 'light');
      expect((await settings.getSetting('theme'))!.value, 'light');
      expect(await settings.getAllSettings(), hasLength(1));

      await settings.setMetadata('schema_version', '1');
      expect(await settings.getMetadataValue('schema_version'), '1');
      await settings.deleteSetting('theme');
      expect(await settings.getSettingValue('theme'), isNull);
    });
  });

  group('statistics DAO', () {
    test('counters, gauges, logs, diagnostics, events, snapshot', () async {
      await statistics.increment('messages_total');
      await statistics.increment('messages_total');
      await statistics.increment('messages_total', delta: 3);
      expect((await statistics.getStatistic('messages_total'))!.value, 5);
      expect(await statistics.allStatistics(), hasLength(1));

      await statistics.setGauge('rssi', -65.5);
      expect((await statistics.getStatistic('rssi'))!.value, -65.5);

      await statistics.setStringStatistic('bio', 'offline-mesh');
      expect(
        (await statistics.getStatistic('bio'))!.stringValue,
        'offline-mesh',
      );

      await statistics.insertLog(
        LogsCompanion.insert(
          timestamp: now,
          level: 1,
          tag: 'storage',
          message: 'boom',
        ),
      );
      expect(
        (await statistics.recentLogs(tag: 'storage')).single.message,
        'boom',
      );
      await statistics.purgeLogs(now.add(const Duration(seconds: 1)));
      expect(await statistics.recentLogs(), isEmpty);

      await statistics.insertDiagnostic('network', 'quality', '0.9');
      expect((await statistics.diagnosticsFor('network')).single.value, '0.9');

      await statistics.insertDeveloperEvent(
        'battery_dropped',
        payload: '{"pct":10}',
      );
      expect(
        (await statistics.recentDeveloperEvents()).single.name,
        'battery_dropped',
      );

      final snap = await statistics.snapshot();
      expect(snap.stats, 3);
      expect(snap.logs, 0);
    });
  });
}
