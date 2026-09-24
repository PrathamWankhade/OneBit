
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/protocol/message_codec.dart';
import 'package:onebit/features/protocol/onebit_packet.dart';
import 'package:onebit/features/protocol/packet_codec.dart';

AppDatabase createTestDb() => AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Message round-trip through full stack', () {
    test('Message → MessageCodec → OneBitPacket → PacketCodec → decode', () {
      // 1. Encode a message.
      final messageBytes = MessageCodec.encode(
        externalMessageId: 'm_42',
        content: 'Hello OneBit',
        timestampMs: 1700000000000,
      );

      // 2. Wrap in a OneBit packet.
      final packet = OneBitPacket(
        type: PacketType.message,
        packetId: 1,
        payload: messageBytes,
      );

      // 3. Encode the packet.
      final encoded = PacketCodec.encode(packet);

      // 4. Decode the packet on the other side.
      final decoded = PacketCodec.decode(encoded);
      expect(decoded.type, PacketType.message);

      // 5. Decode the message payload.
      final msg = MessageCodec.decode(Uint8List.fromList(decoded.payload));
      expect(msg.externalMessageId, 'm_42');
      expect(msg.content, 'Hello OneBit');
      expect(msg.timestampMs, 1700000000000);
    });

    test('Unicode message through full stack', () {
      const content = 'नमस्ते OneBit 🌐';
      final messageBytes = MessageCodec.encode(
        externalMessageId: 'm_unicode',
        content: content,
        timestampMs: 999,
      );

      final packet = OneBitPacket(
        type: PacketType.message,
        packetId: 5,
        payload: messageBytes,
      );

      final encoded = PacketCodec.encode(packet);
      final decoded = PacketCodec.decode(encoded);
      final msg = MessageCodec.decode(Uint8List.fromList(decoded.payload));

      expect(msg.content, content);
      expect(msg.externalMessageId, 'm_unicode');
    });

    test('multiple messages through stack maintain identity', () {
      final messages = List.generate(
        5,
        (i) => MessageCodec.encode(
          externalMessageId: 'm_$i',
          content: 'Message $i',
          timestampMs: i * 1000,
        ),
      );

      for (var i = 0; i < messages.length; i++) {
        final packet = OneBitPacket(
          type: PacketType.message,
          packetId: i,
          payload: messages[i],
        );

        final encoded = PacketCodec.encode(packet);
        final decoded = PacketCodec.decode(encoded);
        final msg = MessageCodec.decode(Uint8List.fromList(decoded.payload));

        expect(msg.externalMessageId, 'm_$i');
        expect(msg.content, 'Message $i');
      }
    });

    test('retry sends same encoded bytes (packet ID stable)', () {
      final messageBytes = MessageCodec.encode(
        externalMessageId: 'm_retry',
        content: 'Retry test',
        timestampMs: 5000,
      );

      final packet = OneBitPacket(
        type: PacketType.message,
        packetId: 10,
        payload: messageBytes,
      );

      // Simulate multiple retries.
      final attempt1 = PacketCodec.encode(packet);
      final attempt2 = PacketCodec.encode(packet);
      final attempt3 = PacketCodec.encode(packet);

      expect(attempt1, equals(attempt2));
      expect(attempt2, equals(attempt3));

      // All decode to the same message.
      for (final bytes in [attempt1, attempt2, attempt3]) {
        final decoded = PacketCodec.decode(bytes);
        final msg = MessageCodec.decode(Uint8List.fromList(decoded.payload));
        expect(msg.externalMessageId, 'm_retry');
        expect(msg.content, 'Retry test');
      }
    });
  });

  group('Database receive flow', () {
    late AppDatabase db;

    setUp(() async {
      db = createTestDb();
      await db.customStatement('PRAGMA foreign_keys = ON');
    });

    tearDown(() async {
      await db.close();
    });

    test('insertReceivedMessage persists message', () async {
      final convId = await db.createConversationWithPeer('Peer Chat', 'device_A');

      final msgId = await db.insertReceivedMessage(
        conversationId: convId,
        content: 'Hello from A',
        externalMessageId: 'm_incoming_1',
      );

      expect(msgId, isNotNull);

      final messages = await db.getMessages(convId);
      expect(messages.length, 1);
      expect(messages.first.content, 'Hello from A');
      expect(messages.first.status, 'received');
      expect(messages.first.externalMessageId, 'm_incoming_1');
    });

    test('duplicate externalMessageId is rejected', () async {
      final convId = await db.createConversation('Peer Chat');

      await db.insertReceivedMessage(
        conversationId: convId,
        content: 'First',
        externalMessageId: 'm_dup',
      );

      final secondId = await db.insertReceivedMessage(
        conversationId: convId,
        content: 'Duplicate',
        externalMessageId: 'm_dup',
      );

      expect(secondId, isNull); // Duplicate rejected.

      final messages = await db.getMessages(convId);
      expect(messages.length, 1);
      expect(messages.first.content, 'First');
    });

    test('different externalMessageIds are both inserted', () async {
      final convId = await db.createConversation('Peer Chat');

      await db.insertReceivedMessage(
        conversationId: convId,
        content: 'Msg 1',
        externalMessageId: 'm_1',
      );
      await db.insertReceivedMessage(
        conversationId: convId,
        content: 'Msg 2',
        externalMessageId: 'm_2',
      );

      final messages = await db.getMessages(convId);
      expect(messages.length, 2);
    });

    test('getConversationByPeerDevice finds linked conversation', () async {
      final convId = await db.createConversationWithPeer('Peer Chat', 'device_X');

      final found = await db.getConversationByPeerDevice('device_X');
      expect(found, isNotNull);
      expect(found!.id, convId);

      final notFound = await db.getConversationByPeerDevice('device_Y');
      expect(notFound, isNull);
    });

    test('createConversationWithPeer stores peerDeviceId', () async {
      final convId = await db.createConversationWithPeer('BLE Device', 'device_Z');
      final conv = await db.getConversation(convId);

      expect(conv, isNotNull);
      expect(conv!.peerDeviceId, 'device_Z');
      expect(conv.title, 'BLE Device');
    });

    test('messageExists checks external ID', () async {
      final convId = await db.createConversation('Chat');

      await db.insertReceivedMessage(
        conversationId: convId,
        content: 'Test',
        externalMessageId: 'm_check',
      );

      expect(await db.messageExists('m_check'), isTrue);
      expect(await db.messageExists('m_other'), isFalse);
    });
  });

  group('MessageCodec edge cases', () {
    test('empty externalMessageId round-trips', () {
      final bytes = MessageCodec.encode(
        externalMessageId: '',
        content: 'test',
        timestampMs: 0,
      );
      final decoded = MessageCodec.decode(bytes);
      expect(decoded.externalMessageId, '');
    });

    test('large timestamp round-trips', () {
      final ms = DateTime.utc(2099, 12, 31).millisecondsSinceEpoch;
      final bytes = MessageCodec.encode(
        externalMessageId: 'm_future',
        content: 'future',
        timestampMs: ms,
      );
      final decoded = MessageCodec.decode(bytes);
      expect(decoded.timestampMs, ms);
    });

    test('content with newlines round-trips', () {
      const content = 'Line 1\nLine 2\nLine 3';
      final bytes = MessageCodec.encode(
        externalMessageId: 'm_nl',
        content: content,
        timestampMs: 0,
      );
      final decoded = MessageCodec.decode(bytes);
      expect(decoded.content, content);
    });

    test('content with special characters round-trips', () {
      const content = 'Hello! @#\$%^&*()_+-={}[]|;:\'",.<>?/~`';
      final bytes = MessageCodec.encode(
        externalMessageId: 'm_special',
        content: content,
        timestampMs: 0,
      );
      final decoded = MessageCodec.decode(bytes);
      expect(decoded.content, content);
    });
  });
}
